return {
  name = "status-led",
  description = "Blink the top redstone output every second to show the system is alive.",
  runLevel = 3,
  autostart = true,
  kind = "daemon",
  restartPolicy = "always",
  restartDelay = 1,

  start = function(ctx)
    ctx.logger:info("status-led setup complete")
  end,

  loop = function(ctx)
    local side = "top"
    local state = false

    while not ctx:shouldStop() do
      state = not state
      redstone.setOutput(side, state)
      os.sleep(1)
    end

    redstone.setOutput(side, false)
  end,
}
