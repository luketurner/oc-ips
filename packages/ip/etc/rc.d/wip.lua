-- /etc/rc.d/wip.lua
local wip = require("wip")
local event = require("event")

-- local function loadConfig()
--   local env = {}
--   local result, reason = loadfile('/etc/wip.cfg', 't', env)
--   if result then
--     result, reason = xpcall(result, debug.traceback)
--     if result then
--       return env
--     end
--   end
--   return nil, reason
-- end

local function handleWimpMessage(...)
  event.push("wimp_message", ...)
end

function stop()
  wip.ignore(".", 101)
end

function start()
  wip.configure(args)
  wip.listen(".", 101, handleWimpMessage)
end

