local cfgfile = {}

function cfgfile.load(filename)
  local env = {}
  local result, reason = loadfile(filename, 't', env)
  if result then
    result, reason = xpcall(result, debug.traceback)
    if result then
      return env
    end
  end
  return nil, reason
end

return cfgfile