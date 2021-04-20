local ip = require("ip")
local cfgfile = require("cfgfile")

function stop()
  ip.halt()
end

function start()
  local config, err = cfgfile.load("/etc/ip.cfg")
  if err then error(err) end
  ip.init(config)
end

