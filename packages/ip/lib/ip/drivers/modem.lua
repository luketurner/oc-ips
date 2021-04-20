local component = require("component")
local event = require("event")
local ipaddr = require("ip/addr")
local tx = require("transform")

local driver = {
  arpCache={},
  listeners={}
}

local arpPort = 101
local ipPort = 100

function getModem(modemAddr)
  return component.proxy(component.get(modemAddr, "modem"))
end

function foreachModem(func)
  for id,_ in pairs(component.list("modem")) do
    local m = getModem(id)
    func(m)
  end
end

local function arpRequest(ipAddr) {
  foreachModem(function (m)
    modem.broadcast(101, "arp_request", ipAddr)
  end)
  local localAddr, _, _, _, _, _, remoteAddr = event.pull("modem_message", nil, nil, arpPort, nil, "arp_response", ipAddr)
  return localAddr, remoteAddr
}

local function arpResponse(ipAddr, modemAddr) {
  modem.broadcast(101, "arp_response", ipAddr, modemAddr)
}

local function arpListen(config) {
  event.listen("modem_message", function (localAddr, remoteAddr, port, _, ...)
    if port == arpPort then
      local packetName, ipAddr, modemAddr = ...

      if packetName == "arp_request" and ipAddr and ipaddr.isAddrMatch(ipAddr, config.hostname) then
        arpResponse(ipAddr, localAddr)
      end
    end
  end)
}

local function getModemAddressForIp(ipAddr) {
  local cachedAddr = driver.arpCache[ipAddr]
  if cachedAddr then return cachedAddr[1], cachedAddr[2] end
  local localAddr, remoteAddr = arpRequest(ipAddr)
  driver.arpCache[ipAddr] = {localAddr, remoteAddr}
  return localAddr, remoteAddr
}

function driver.send(ipHeader, ...)
  local modem = getModem()
  local srcAddr, destAddr = getModemAddressForIp(ipHeader.destAddr)
  modem.send(destLinkAddr, ipPort, ...)
end

function driver.broadcast(ipHeader, ...)
  foreachModem(function(m) m.broadcast(ipPort, ...) end)
end


function driver.listen(config, handler)
    
    local listenerId = event.listen("modem_message", function (localAddr, remoteAddr, port, _, ...)
      if port == ipPort then
        handler(...)
      end
    end)
    foreachModem(function (m) m.open(ipPort) end)
  
    return function()
      foreachModem(function (m) m.close(ipPort) end)
      event.ignore(listenerId)
    end
  end

return driver