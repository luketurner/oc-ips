local syslog = require("syslog")
local shell = require("shell")
local tty = require("tty")

local args, opts = shell.parse(...)


function write_event(evt)
  -- from dmesg.lua
  io.write("[" .. os.date("%T") .. "] ")
  io.write(tostring(evt[1]) .. string.rep(" ", math.max(10 - #tostring(evt[1]), 0) + 1))
  io.write(tostring(evt[2]) .. string.rep(" ", 37 - #tostring(evt[2])))
  if evt.n > 2 then
    for i = 3, evt.n do
      io.write("  " .. tostring(evt[i]))
    end
  end
  io.write("\n")
end

local events = syslog.tail(tonumber(args[1]) or 10)
if #events == 0 then
  print("no matching events")
else
  for v,evt in ipairs(events) do
    write_event(evt)
  end
end
