local event = require("event")
local driver = {}

local function getModem(addr)
  return component.get(addr, "modem")
end

function driver.send(...)
  event.push("loopback_message", ...)
end

function driver.broadcast(...)
  event.push("loopback_message", ...)
end

function driver.listen(handler)
  local listenerId = event.listen("local_message", function (_, ...)
    handler(...)
  end)

  return function() event.ignore(listenerId) end
end


return driver