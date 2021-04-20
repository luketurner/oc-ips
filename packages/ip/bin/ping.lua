local ip = require("ip")
local shell = require("shell")
local component = require("component")
local computer = require("computer")
local event = require("event")
local uuid = require("uuid")

local args, opts = shell.parse(...)

if #args ~= 1 or opts.help then
  print([[Usage: ping [HOST]

  Sends an ICMP echo message to the specified host.
  ]])
  return 0
end

local host = args[1]
local echoData = uuid.next()

ip.send(host, 1, {
  command="echo",
  echo=echoData
})

local ev = event.pull("icmp_echo_response", host, echoData)
print(ev)