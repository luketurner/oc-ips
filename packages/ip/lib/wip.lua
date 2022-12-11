local package = require("package")
local event = require("event")
local tx = require("transforms")
local component = require("component")

local wip = {
  interfaces={},
  conns={},
  forwardingEnabled=nil,
  routeTable={} -- localNetAddr, remoteNetAddr, addr
}

local globalListenerId

function startGlobalListener(handler)
  if not globalListenerId then
    globalListenerId = event.listen("modem_message", handler)
  end
end

function stopGlobalListener()
  if globalListenerId then event.ignore(globalListenerId) end
end

function wip.isAddrInSubnet(subnet, addr)
  return subnet == addr or addr:find("^"..subnet:gsub("%.", "%%."))
end

function wip.isAddrMatch(a1, a2)
  return wip.isAddrInSubnet(a1, a2) or wip.isAddrInSubnet(a2, a1)
end

function wip.configure(config)
  wip.interfaces = config.interfaces
  wip.forwardingEnabled = config.forwardingEnabled
end

function wip.getOpenConn(addr, port)
  local connIx = tx.first(wip.conns, function(c)
    return c.port == port and matchesAddress(addr, c.addr)
  end)
  if connIx then return wip.conns[connIx], connIx end
end

function wip.getConfigForInterface(netAddr)
  for _,ifcfg in pairs(wip.interfaces) do
    if ifcfg.netAddr == netAddr then
      return ifcfg
    end
  end
end

function wip.getModem(addr)
  for _,ic in pairs(wip.interfaces) do
    if wip.isAddrMatch(ic.addr, addr) and ic.netAddr then
      local fullNetAddress = component.get(ic.netAddr, "modem")
      if not fullNetAddress then
        error("invalid wip.conf: unknown net address " .. ic.netAddr)
      end
      return component.proxy(fullNetAddress)
    end
  end
end

local function forwardMessage(wipHeader, ...)
  if wip.forwardingEnabled then
    local ttl, destAddr, destPort = wipHeader.ttl wipHeader.destAddr, wipHeader.destPort
    
    if ttl < 2 then
      event.push("forward_skipped_ttl", destAddr, destPort) -- for debugging, remove later
      return
    end

    for _, route in wip.routeTable do
      if wip.isAddrMatch(route, destAddr) then
        local modem = wip.getModem(route.localNetAddr)
        local destNetAddr = route.remoteNetAddr
        local newWipHeader = {table.unpack(wipHeader)}
        newWipHeader.ttl = wipHeader.ttl - 1
        modem.send(destNetAddr, destPort, newWipHeader, ...)
      end
    end
  else
    event.push("forward_skipped", wipHeader.destAddr, wipHeader.destPort) -- for debugging, remove later
  end
end

local function messageHandler(_, receiverNetAddress, senderNetAddress, port, wipHeader, ...)
  local addr, port = wipHeader.destAddr, wipHeader.destPort

  local receivingInterface = wip.getModem(addr)
  if not receivingInterface then
    -- This packet wasn't intended for us
    routeMessage(wipHeader, ...)
    return
  end

  local conn = wip.getOpenConn(addr, port)
  if not conn then
    -- this packet was intended for us, but there is no handler to call.
    -- TODO should send an error packet back to client
    return
  end

  return conn.handler(...)
  -- event.push("wip_message", wipHeader, ...)
end

function wip.listen(addr, port, handler)
  checkArg(1, addr, "string")
  checkArg(2, port, "number")

  if wip.getOpenConn(addr, port) then
    error("already listening on specified address+port combination")
  end

  local modem = wip.getModem(addr)
  if not modem then error("unknown wip address: "..addr) end

  startGlobalListener(messageHandler)
  modem.open(port)
  table.insert(wip.conns, { port=port, addr=addr, handler=handler })
  event.push("wip_listen", addr, port)
end

function wip.ignore(addr, port)
  local modem = wip.getModem(addr)
  if not modem then return end

  local conn, connIx = wip.getOpenConn(addr, port)
  if conn then
    modem.close(port)
    wip.conns:remove(connIx)

    if #wip.conns == 0 then
      -- no open connections, we can disable the WIP message handler
      stopGlobalListener()
    end

    event.push("wip_ignore", addr, port)
  end
end

function wip.send(addr, port, ...)

return wip