if _G._INIT_SKIP_STARTUP then
  return
end

term.clear()
term.setCursorPos(1, 1)

local function requestShutdown(reason)
  if reason then
    print(reason)
  end

  print("Provide any input to power down.")

  while true do
    local event = os.pullEvent()
    if event == "char" or event == "key" then
      break
    elseif event == "terminate" then
      error("Terminated", 0)
    end
  end

  os.shutdown()
end

local DEFAULTS = {
  runLevel = 3,
  serviceDir = "/etc/init/services",
  enableFileLogging = true,
  logFilePath = "/var/log/init.log",
  logLevel = "info",
}

local LEVEL_ORDER = {
  debug = 0,
  info = 1,
  warn = 2,
  error = 3,
}

-- Logging utility -----------------------------------------------------------
local Logger = {}
Logger.__index = Logger

local LOG_LABELS = {
  debug = "[DBG]",
  info = "[INF]",
  warn = "[WRN]",
  error = "[ERR]",
}

local LOG_ORDER = {
  debug = 0,
  info = 1,
  warn = 2,
  error = 3,
}

local function ensureLogFile(path)
  if not path then
    return
  end

  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function timestamp()
  local ok, formatted = pcall(function()
    return textutils.formatTime(os.time(), true)
  end)

  if ok and formatted then
    return formatted
  end

  return string.format("%.0f", os.epoch("utc"))
end

function Logger.new(opts)
  opts = opts or {}

  local self = setmetatable({}, Logger)
  self.level = LOG_ORDER[opts.level or "info"] and opts.level or "info"
  self.logFilePath = opts.logFilePath
  self.enableFile = opts.enableFile ~= false and opts.logFilePath ~= nil

  if self.enableFile then
    ensureLogFile(self.logFilePath)
  end

  return self
end

function Logger:shouldLog(level)
  local target = LOG_ORDER[level] or math.huge
  return target >= LOG_ORDER[self.level]
end

function Logger:writeLine(level, message)
  local label = LOG_LABELS[level] or "[LOG]"
  local line = string.format("%s %s %s", label, timestamp(), message)
  print(line)

  if self.enableFile and self.logFilePath then
    local handle = fs.open(self.logFilePath, "a")
    if handle then
      handle.writeLine(line)
      handle.close()
    end
  end
end

function Logger:log(level, message)
  if not self:shouldLog(level) then
    return
  end

  self:writeLine(level, message)
end

function Logger:debug(message)
  self:log("debug", message)
end

function Logger:info(message)
  self:log("info", message)
end

function Logger:warn(message)
  self:log("warn", message)
end

function Logger:error(message)
  self:log("error", message)
end

-- Service loader -----------------------------------------------------------
local function validateService(service, path)
  if type(service) ~= "table" then
    return nil, "service definition must return a table"
  end

  if type(service.name) ~= "string" or service.name == "" then
    service.name = (path and fs.getName(path)) or "unnamed"
    service.name = service.name:gsub("%.lua$", "")
  end

  if service.runLevel ~= nil then
    if type(service.runLevel) ~= "number" then
      return nil, "runLevel must be a number"
    end
  else
    service.runLevel = 3
  end

  return service
end

local function loadServiceFile(path)
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, err
  end

  local ok, result = pcall(chunk)
  if not ok then
    return nil, result
  end

  local service, validationErr = validateService(result, path)
  if not service then
    return nil, validationErr
  end

  service.source = path
  return service
end

local function loadServices(directory)
  local services, warnings = {}, {}

  if not directory or directory == "" then
    return services, { "service directory is not configured" }
  end

  if not fs.exists(directory) then
    return services, { string.format("service directory %s does not exist", directory) }
  end

  if not fs.isDir(directory) then
    return services, { string.format("service path %s is not a directory", directory) }
  end

  for _, file in ipairs(fs.list(directory)) do
    local full = fs.combine(directory, file)
    if fs.isDir(full) then
      -- nested directories are ignored for simplicity
    elseif file:match("%.lua$") then
      local service, err = loadServiceFile(full)
      if service then
        table.insert(services, service)
      else
        table.insert(warnings, string.format("failed to load %s: %s", full, tostring(err)))
      end
    end
  end

  return services, warnings
end

-- Init core ----------------------------------------------------------------
local function resolveConfig(overrideLevel)
  local cfg = {
    runLevel = overrideLevel or settings.get("init.run-level") or DEFAULTS.runLevel,
    serviceDir = settings.get("init.service-dir") or DEFAULTS.serviceDir,
    enableFileLogging = settings.get("init.enable-file-logging"),
  }

  if cfg.enableFileLogging == nil then
    cfg.enableFileLogging = DEFAULTS.enableFileLogging
  end

  cfg.logFilePath = settings.get("init.log-file") or DEFAULTS.logFilePath
  cfg.logLevel = settings.get("init.log-level") or DEFAULTS.logLevel

  if not LEVEL_ORDER[cfg.logLevel] then
    cfg.logLevel = DEFAULTS.logLevel
  end

  return cfg
end

local function makeContext(config, log)
  local ctx = {
    runLevel = config.runLevel,
    logger = log,
    config = config,
    shutdown = false,
  }

  function ctx:shouldStop()
    return self.shutdown
  end

  function ctx:requestShutdown(reason)
    if reason then
      self.logger:warn("Shutdown requested: " .. tostring(reason))
    end
    self.shutdown = true
    os.queueEvent("terminate")
  end

  return ctx
end

local function describeService(service)
  local kind = service.kind or (service.loop and "daemon" or "oneshot")
  return string.format("%s (run-level %d)", service.name, service.runLevel or 0), kind
end

local function runOneshot(service, ctx)
  local log = ctx.logger
  local descriptor, kind = describeService(service)
  log:info(string.format("Starting %s [%s]", descriptor, kind))

  if not service.start then
    log:warn(string.format("Service %s has no start handler; skipping", service.name))
    return
  end

  local ok, err = pcall(service.start, ctx)
  if not ok then
    log:error(string.format("Service %s failed: %s", service.name, tostring(err)))
    return
  end

  log:info(string.format("Service %s completed", service.name))
end

local function daemonRunnerFactory(service, ctx)
  local log = ctx.logger
  local restartPolicy = service.restartPolicy or "on-failure"
  local restartDelay = tonumber(service.restartDelay) or 0.5

  return function()
    while not ctx.shutdown do
      local ok, err = pcall(service.loop, ctx)
      service._lastResult = { ok = ok, err = err }

      if ctx.shutdown then
        return
      end

      if ok then
        log:info(string.format("Daemon %s exited cleanly", service.name))
      else
        log:error(string.format("Daemon %s crashed: %s", service.name, tostring(err)))
      end

      local shouldRestart = false
      if restartPolicy == "always" then
        shouldRestart = true
      elseif restartPolicy == "on-failure" and not ok then
        shouldRestart = true
      end

      if not shouldRestart then
        return
      end

      if restartDelay > 0 then
        log:warn(string.format("Restarting daemon %s in %.1fs", service.name, restartDelay))
        os.sleep(restartDelay)
      end
    end
  end
end

local function superviseDaemons(daemons, ctx)
  if #daemons == 0 then
    ctx.logger:info("No daemons scheduled; waiting for terminate (Ctrl+T)")
    os.pullEvent("terminate")
    ctx.shutdown = true
    return
  end

  local runners = {}
  local indexToService = {}
  for i, service in ipairs(daemons) do
    runners[i] = daemonRunnerFactory(service, ctx)
    indexToService[i] = service
    ctx.logger:info(string.format("Daemon %s registered", service.name))
  end

  local terminatorIndex = #runners + 1
  runners[terminatorIndex] = function()
    os.pullEvent("terminate")
    ctx.logger:info("Terminate signal received")
    ctx.shutdown = true
  end

  local winner = parallel.waitForAny(table.unpack(runners))

  ctx.shutdown = true

  if winner ~= terminatorIndex then
    local service = indexToService[winner]
    if service and service._lastResult then
      local status = service._lastResult
      if status.ok then
        ctx.logger:warn(string.format("Daemon %s exited; init stopping", service.name))
      else
        ctx.logger:error(string.format("Daemon %s aborted: %s", service.name, tostring(status.err)))
      end
    else
      ctx.logger:warn("A daemon exited unexpectedly; init stopping")
    end
  else
    ctx.logger:info("Termination requested; tearing down daemons")
  end
end

local function startServices(services, ctx)
  local daemons = {}

  table.sort(services, function(a, b)
    local ra, rb = a.runLevel or 0, b.runLevel or 0
    if ra == rb then
      return a.name < b.name
    end
    return ra < rb
  end)

  for _, service in ipairs(services) do
    service.runLevel = service.runLevel or 0
    service.autostart = service.autostart ~= false
    service.kind = service.kind or (service.loop and "daemon" or "oneshot")
    service.restartPolicy = service.restartPolicy or (service.loop and "on-failure" or "never")

    if not service.autostart then
      ctx.logger:info(string.format("Service %s autostart disabled; skipping", service.name))
    elseif service.runLevel > ctx.runLevel then
      ctx.logger:info(string.format("Service %s run-level %d above target %d; skipping", service.name, service.runLevel, ctx.runLevel))
    elseif service.kind == "daemon" then
      table.insert(daemons, service)
    else
      runOneshot(service, ctx)
    end
  end

  return daemons
end

local function runInit(targetRunLevel)
  local config = resolveConfig(targetRunLevel)
  local log = Logger.new {
    logFilePath = config.logFilePath,
    enableFile = config.enableFileLogging,
    level = config.logLevel,
  }

  log:info(string.format("Init starting (run-level %d)", config.runLevel))

  local ctx = makeContext(config, log)

  local services, warnings = loadServices(config.serviceDir)
  for _, warning in ipairs(warnings) do
    log:warn(warning)
  end

  if #services == 0 then
    log:warn("No services found; waiting for terminate")
    superviseDaemons({}, ctx)
    log:info("Init exiting (no services)")
    return
  end

  local daemons = startServices(services, ctx)
  superviseDaemons(daemons, ctx)
  log:info("Init shutdown complete")

  os.shutdown()
end

local ok, err = pcall(runInit)
if not ok then
  printError("init: crash: " .. tostring(err))
  if debug and debug.traceback then
    printError(debug.traceback(err))
  end
  requestShutdown("Init crashed; system will power down.")
end
