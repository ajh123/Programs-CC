# lcinit

`lcinit` is a daemon program written in Lua for ComputerCraft / CC: Tweaked that initialises and manages startup scripts on computers and turtles. It provides a flexible and configurable way to run scripts automatically when the system boots up. Essentially, it acts like systemd or init.d for ComputerCraft.

## Installation

To install `lcinit`, follow these steps in your ComputerCraft or CC: Tweaked environment:
1. `wget https://github.com/ajh123/Programs-CC/raw/refs/heads/main/programs/lcinit/init.lua` to your computer or turtle.
2. Edit your `startup.lua` file to run `lcinit` on boot. Just add the line `shell.run("init.lua")` to the bottom of your `startup.lua`.
3. It is recommended to install the shell service as not doing so will prevent you from using the shell while `lcinit` is running. To do this, run `wget https://github.com/ajh123/Programs-CC/raw/refs/heads/main/programs/lcinit/services/shell.lua etc/init/services/shell.lua` 
4. Restart your computer or turtle to see `lcinit` in action.

## Configuration

`lcinit` can be configured using files located in the `etc/init` directory. You can create services, targets, and other configurations to control how and when scripts are executed.

## Building a Service

To create a new service, you need to create a Lua script in the `etc/init/services` directory. Here is a simple example of a service script:

```lua
-- myservice.lua
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
```

Here is a breakdown of the fields used in the service definition:
- `name`: The name of the service.
- `description`: A brief description of what the service does.
- `runLevel`: The run level at which the service should start.
- `autostart`: A boolean indicating whether the service should start automatically.
- `kind`: The type of service (e.g., "daemon", "oneshot").
- `restartPolicy`: The policy for restarting the service (e.g., "always", "on-failure", "never").
- `restartDelay`: The delay in seconds before restarting the service after it stops.
- `start`: A function that is called when the service starts.
- `loop`: A function that runs in a loop until the service is stopped.
