local syslog = require("syslog")

function start()
  syslog.listen()
end

function stop()
  syslog.ignore()
end