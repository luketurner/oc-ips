local fs = require("filesystem")
local shell = require("shell")
local process = require("process")
local rc = require("rc")
local thread = require("thread")
local term = require("term")

local args, opts = shell.parse(...)

local threads = {}
local processes = {}
local rcs = {}

if opts.help then
  print([[Usage: watch [OPTION]... [FILE]...
  --rc    runs file using rc framework (start/stop)

  Runs the given file(s) as subprocesses, and re-runs automatically on change.
  ]])
  return 0
end

function absPath(path)
  if string.find(path, "^/") then
    return path
  else
    return fs.concat(shell.getWorkingDirectory(), path)
  end
end

function cleanupExecutedRc(name)
  if processes[name] then
    processes[name]:kill()
  end
  rc.runCommand(name, "stop")
  rc.unload(name)
end

function executeRc(name)
  rc.load(name)
  rcs[name] = true
  processes[name] = thread.create(rc.runCommand, name, "start")
end

function executeFile(path)
  processes[path] = thread.create(loadfile(path))
end

function cleanupExecutedFile(path)
  if processes[path] then processes[path]:kill() end
end

function watchFile(path, func, cleanup_func, ...)
  local lastModified
  print("watching file: ", path)
  while true do
    local nextModified = fs.lastModified(absPath(path))
    if nextModified ~= lastModified then
      if lastModified then
        print("updated file:", path)
        cleanup_func(path, ...)
      end
      lastModified = nextModified
      func(path, ...)
    end

    os.sleep(1)
  end
end

function watchExecutableFile(path)
  watchFile(path, executeFile, cleanupExecutedFile)
end

function watchRc(name)
  watchFile(
    "/etc/rc.d/" .. name .. ".lua",
    function() executeRc(name) end,
    function() cleanupExecutedRc(name) end
  )
end

for i,v in ipairs(args) do
  threads[v] = thread.create((opts.rc and watchRc) or watchExecutableFile, v)
end

function exit()
  for p,v in pairs(rcs) do if v then cleanupExecutedRc(p) end end
  for p,v in pairs(processes) do
    if v then v:kill() end
    -- if v then v:status() end
  end
  for p,v in pairs(threads) do
    if v then v:kill() end
  end
  -- term.clear()
end

while true do
  id, _, v2 = term.pull("key_up")
  if v2 == 3 or v2 == 113 then -- 3 is C-c / 113 is q
    print("exiting...")
    return exit()
  end
end