local tx = require("transform")
local icmp = require("ip/icmp")
local ipaddr = require("ip/addr")

local ip = {}

function routeMessage(ipHeader, ...) do
  warn("routeMessage not implemented yet")
end

-- TODO
function signalHandler(ipHeader, ...) do
  local addr, port = ipHeader.destAddr, ipHeader.destPort

  -- signals pushed for debugging purposes -- not an official API (yet)
  event.push("ip_message", wipHeader)

  local ifcfg = ip.getInterface(addr)
  if not ifcfg then
    -- This packet wasn't intended for us
    routeMessage(ipHeader, ...)
    return
  end

  local conn = ip.getListener(addr, port)
  if not conn then
    -- We are the destination of this packet, but nothing is listening for the packets.
    -- Inform the client with an ICMP message.
    ip.send(ipHeader.srcAddr, ipHeader.srcPort, icmp.unreachablePort(ipHeader))
    return
  end

  return conn.handler(...)
end

function ip.init(config) do

  if ip.listeners then
    error("IP is already initialized")
  end

  ip.enabledDrivers = config.enabledDrivers
  ip.routes = config.routes
  ip.interfaces = config.interfaces

  ip.drivers = {}
  ip.listeners = {}

  for _,driverName in ipairs(ip.enabledDrivers) do
    local driver = require("ip/drivers/"..driverName)
    ip.drivers[driverName] = {
      package=driver,
      listenerCleanup=nil
    }
  end

  for _,ifcfg in ip.interfaces do
    if not ip.drivers[ifcfg.type] then
      error("unknown interface type: "..ifcfg.type)
    end
  end

  for _,driver in ip.drivers do
    driver.listenerCleanup = driver.package.listen(signalHandler)
  end

  ip.listen(".", 1, function (header, icmpMsg, ...)
    if icmpMsg.error then
      -- TODO handle error
    elseif icmpMsg.command == "echo" then
      ip.send(header.srcAddr, header.srcPort, {
        command="echo-response",
        echo=icmpMsg.echo
      })
    elseif icmpMsg.command == "echo-response" then
      event.push("icmp_echo_response", header.srcAddr, icmpMsg.echo)
    elseif icmpMsg.command == "wake" then
      -- ??
    elseif icmpMsg.command == "sleep" then
      -- ??
    e
  end)

  event.push("ip_init")
end

function ip.halt() do
  ip.listeners = {}
  for _,driver in ip.drivers do
    if driver.listenerCleanup then driver.listenerCleanup() end
  end
end


function ip.getListener(addr, port)
  -- n.b. use pairs() because ip.listeners is a sparse array (may contain nils followed by more listeners)
  for i,c in pairs(ip.listeners) do
    if c.port == port and ipaddr.isAddrMatch(addr, c.addr) then
      return c, i
    end
  end
end

function ip.getInterface(addr)
  for _,ifcfg in ipairs(ip.interfaces) do
    if ipaddr.isAddrMatch(addr, ifcfg.addr) then
      return ifcfg
    end
  end
end

function ip.getInterfaceByLinkAddr(linkAddr)
  for _,ifcfg in ipairs(ip.interfaces) do
    if linkAddr == ifcfg.linkAddr then
      return ifcfg
    end
  end
end

function ip.getDriver(ifType)
  return ip.drivers[ifType]
end

function ip.getMatchingRoute(addr)
  for _,v in ip.routes
end

function ip.send(addr, port, ...)
  local route = ip.getMatchingRoute(addr)
  if not route then error("unknown address: "..addr) end

  local ifcfg = ip.getInterfaceByLinkAddr(route.linkAddr)
  if not ifcfg then error("invalid route: cannot find interface with id "..route.linkAddr) end

  local driver = ip.getDriver(ifcfg.type)
  if not driver then error("unknown interface type: "..ifcfg.type) end

  local header = {
    srcAddr: ifcfg.hostname, -- TODO use interface-specific IP addr.
    srcPort: port, -- TODO configurable?
    destAddr: addr,
    destPort: port,
    ttl: 16 -- TODO configurable?
  }

  driver.send(route.linkAddr, route.destLinkAddr, port, header, ...)
end

function ip.listen(addr, port, handler) {
  checkArg(1, addr, "string")
  checkArg(2, port, "number")

  if ip.getListener(addr, port) then
    error("already listening on specified address+port combination")
  end

  local cfg = ip.getInterface(addr)
  if not cfg then error("unknown ip address: "..addr) end

  local driver = ip.getDriver(cfg.type)
  if not driver then error("unknown interface type: "..cfg.type) end


  table.insert(ip.listeners, { port=port, addr=addr, handler=handler })
  local listenerId = #ip.listeners

  event.push("ip_listen", addr, port)

  return listenerId
}

function ip.ignore(listenerId) {
  ip.listeners[listenerId] = nil
}

return ip