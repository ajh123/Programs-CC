local DEFAULT_PROGRAM = "/rom/programs/shell.lua"

local function pickShellProgram()
  local configured = settings.get("shell.path")
  local candidate = configured or DEFAULT_PROGRAM
  if fs.exists(candidate) then
    return candidate
  end

  if configured and configured ~= DEFAULT_PROGRAM and fs.exists(DEFAULT_PROGRAM) then
    return DEFAULT_PROGRAM
  end

  return nil, string.format("no shell program found (tried %s)", candidate)
end

local function makeShellEnv()
  local env = setmetatable({}, { __index = _ENV })
  env._G = env
  env._INIT_SKIP_STARTUP = true
  return env
end

return {
  name = "shell",
  description = "Interactive user shell",
  runLevel = 1,
  kind = "daemon",
  autostart = true,
  restartPolicy = "on-failure",

  loop = function(ctx)
    local program, err = pickShellProgram()
    if not program then
      ctx.logger:error("Shell unavailable: " .. tostring(err))
      os.sleep(1)
      return
    end

    ctx.logger:info("Launching interactive shell: " .. program)
    local env = makeShellEnv()
    local ok, runErr = os.run(env, program)

    if ok then
      ctx.logger:warn("Shell exited; requesting shutdown")
      ctx:requestShutdown("shell exit")
      return
    end

    ctx.logger:error("Shell crashed: " .. tostring(runErr))
    os.sleep(1)
  end,
}
