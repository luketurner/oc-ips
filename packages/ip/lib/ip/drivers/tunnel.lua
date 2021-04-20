local event = require("event")
local driver = {}

local function getTunnel(addr)
  return component.get(addr, "tunnel")
end

-- TODO -- improve handling for ports

function driver.send(srcLinkAddr, _, _, ...)
  local tunnel = getTunnel(srcLinkAddr)
  tunnel.send(...)
end

function driver.broadcast(srcLinkAddr, _, ...)
  local tunnel = getTunnel(srcLinkAddr)
  tunnel.send(...)
end

function driver.listen(handler)
  local listenerId = event.listen("modem_message", function (localAddr, remoteAddr, port, dist, ...)
    if not remoteAddr and not localAddr and not port then
      handler(...)
    end
  end)

  return function() event.ignore(listenerId) end
end


return driver