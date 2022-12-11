local component = require("component")
local event = require("event")
local driver = {}

local function getModem(ipAddr)
  lolcal 
  return component.get(addr, "modem")
end

function driver.send(ipHeader, ...)
  local modem = getModem(ipHeader.destAddr)
  modem.send(destLinkAddr, port, ...)
end

function driver.broadcast(ipHeader, ...)
  local modem = getModem(upHeader.destAddr)
  modem.send(destLinkAddr, port, ...)
end

function driver.listen(handler)
    
    local listenerId = event.listen("modem_message", function (localAddr, remoteAddr, port, _, ...)
      if localAddr and remoteAddr and port then
        handler(...)
      end
    end)

    for id,_ in component.list("modem") do
      local m = component.proxy(id)
      for i=100,200,1 do m.open(i) end
    end
  
    return function()
      for id,_ in component.list("modem") do
        local m = component.proxy(id)
        for i=100,200,1 do m.close(i) end
      end
      event.ignore(listenerId)
    end
  end

-- function driver.listen(destAddr, destPort, handler)
--   local fullDestAddr = getModem(destAddr).address
--   local listenerId = event.listen("modem_message", function (localAddr, remoteAddr, port, dist, ...)
--     if localAddr == fullDestAddr then
--       handler(remoteAddr, port, ...)
--     end
--   end)

--   return function() event.ignore(listenerId) end
-- end


return driver