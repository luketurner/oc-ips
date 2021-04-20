
local ipaddr = {}

function ipaddr.isAddrInSubnet(subnet, addr)
  return subnet == addr or addr:find("^"..subnet:gsub("%.", "%%."))
end

function ipaddr.isAddrMatch(a1, a2)
  return ipaddr.isAddrInSubnet(a1, a2) or ipaddr.isAddrInSubnet(a2, a1)
end

return ipaddr