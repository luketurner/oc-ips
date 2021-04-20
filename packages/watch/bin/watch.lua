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

if opts.help or not args[1] then
  print([[Usage: watch [FILE]
  
  Executes the rules in the given Watchfile, re-running rules when files change.
  ]])
  return 0
end

--[[ Example Watchfile:

/etc/rc.d/foobar.lua
  rc foobar restart

/usr/lib/foobar.lua
  pkgreload foobar

/usr/bin/foobar
  foobar
]]

local function absPath(path)
  if string.find(path, "^/") then
    return path
  else
    return fs.concat(shell.getWorkingDirectory(), path)
  end
end

local function parseWatchfileLine(line)
  if line:find("^%S") then return "t", line end

  local _, _, dep = line:find("^%s+watch%s(.*)")
  if dep then return "d", dep end

  local _, _, cmd = line:find("^%s+(.+)")
  if cmd then return "c", cmd end
end

local function parseWatchfileRule(file)
  local line = file:read("l")
  if not line then return nil end
  local rule = {targets={}, commands={}, dependencies={}}
  while line and line:find("%S") do
    local type, data = parseWatchfileLine(line)
    if type == "t" then
      currentRule.targets:insert(data)
    elseif type == "d" then
      currentRule.dependencies:insert(data)
    elseif type == "c" then
      currentRule.commands:insert(data)
    end
  end
  return rule
end

local function parseWatchfile(filename)
  local rules = {}
  local rule
  local file = io.open(filename, "r")

  repeat 
    rule = parseWatchfileRule(file)
    if rule then rules:insert(rule) end
  until not rule end

  return rules
end


local function parseTargetLine(line, rule)
  for match in line:gmatch("[^%s:]+") do
    if currentRule.path then
      currentRule.dependencies:insert(match)
    else
      currentRule.path = match
  end

  return rule
end

local function parseCommandLine(line, rule)
  rule.commands:insert(line:gsub("^%s*"))
  return rule
end



local function parseRules(filename)
  local rules = {}
  local currentRule
  local function addCurrentRuleIfValid(rule, rules)
    if rule.path then rules[rule.path] = rule end
    currentRule = { path=nil, commands={}, dependencies={} }
  end

  for line in io.lines(filename, "*l") do
    if line:find("%S") then
      addCurrentRuleIfValid()
      parseTargetLine(line, rule)
    elseif line:find("%s%S") then
      parseCommandLine(line, rule)
    end  
  end
  addCurrentRuleIfValid()
  return rules
end

local rules = parseRules(argv[1])

local listenerId = event.timer(1, function ()
  for path, rule in pairs(rules) do
    local modified = fs.lastModified(absPath(path))
    if rule.modified ~= modified then
      for _,cmd in ipairs(rule.commands) do
        shell.execute(cmd)
      end
      rule.modified = modified
    end
  end
end)

-- TODO cleanup?





-- function cleanupExecutedRc(name)
--   if processes[name] then
--     processes[name]:kill()
--   end
--   rc.runCommand(name, "stop")
--   rc.unload(name)
-- end

-- function executeRc(name)
--   rc.load(name)
--   rcs[name] = true
--   processes[name] = thread.create(rc.runCommand, name, "start")
-- end

-- function executeFile(path)
--   processes[path] = thread.create(loadfile(path))
-- end

-- function cleanupExecutedFile(path)
--   if processes[path] then processes[path]:kill() end
-- end

-- function watchFile(path, func, cleanup_func, ...)
--   local lastModified
--   print("watching file: ", path)
--   while true do
--     local nextModified = fs.lastModified(absPath(path))
--     if nextModified ~= lastModified then
--       if lastModified then
--         print("updated file:", path)
--         cleanup_func(path, ...)
--       end
--       lastModified = nextModified
--       func(path, ...)
--     end

--     os.sleep(1)
--   end
-- end

-- function watchExecutableFile(path)
--   watchFile(path, executeFile, cleanupExecutedFile)
-- end

-- function watchRc(name)
--   watchFile(
--     "/etc/rc.d/" .. name .. ".lua",
--     function() executeRc(name) end,
--     function() cleanupExecutedRc(name) end
--   )
-- end

-- for i,v in ipairs(args) do
--   threads[v] = thread.create((opts.rc and watchRc) or watchExecutableFile, v)
-- end

-- function exit()
--   for p,v in pairs(rcs) do if v then cleanupExecutedRc(p) end end
--   for p,v in pairs(processes) do
--     if v then v:kill() end
--     -- if v then v:status() end
--   end
--   for p,v in pairs(threads) do
--     if v then v:kill() end
--   end
--   -- term.clear()
-- end

-- while true do
--   id, _, v2 = term.pull("key_up")
--   if v2 == 3 or v2 == 113 then -- 3 is C-c / 113 is q
--     print("exiting...")
--     return exit()
--   end
-- end