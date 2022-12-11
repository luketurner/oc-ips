local event = require("event")
local tx = require("transforms")

local eventLog = {}
local currentIndex = 0
local ringBufferSize = 20
local listenerId

local syslog = {}

syslog.forbiddenEventTypes = {
  "key_up",
  "key_down"
}

function syslog.isEventLoggable(evt)
  for _,evtType in ipairs(syslog.forbiddenEventTypes) do
    if evtType == evt[1] then
      return false
    end
  end
  return true
end

local function handleEvent(...)
  local evt = table.pack(...)
  if evt[1] and syslog.isEventLoggable(evt) then
    local nextIndex = (currentIndex + 1) % ringBufferSize
    eventLog[nextIndex] = evt
    currentIndex = nextIndex
  end
end

function syslog.listen()
  if not listenerId then
    -- TODO does this listen to everything?
    listenerId = event.listen(nil, handleEvent)
  end
end

function syslog.ignore()
  if listenerId then event.ignore(listenerId) end
end

function syslog.tail(count)
  if not count or count > ringBufferSize then
    count = ringBufferSize
  end
  return tx.sub(eventLog, (currentIndex - count + 1) % ringBufferSize, currentIndex)
end

return syslog