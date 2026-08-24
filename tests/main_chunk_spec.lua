local chunk, err = loadfile('warn.lua');
assert(chunk ~= nil, 'warn.lua must compile as one Lua main chunk: ' .. tostring(err));

print('main_chunk_spec: complete warn.lua compiles below the Lua local-variable limit');
