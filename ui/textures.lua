local ffi = require('ffi');
local d3d = require('d3d8');

local textures = { cache = {} };

local function file_exists(path)
    if (path == nil or path == '') then return false; end
    if (ashita ~= nil and ashita.fs ~= nil and ashita.fs.exists ~= nil) then
        return ashita.fs.exists(path);
    end
    local handle = io.open(path, 'rb');
    if (handle == nil) then return false; end
    handle:close();
    return true;
end

function textures.load(path)
    if (not file_exists(path)) then return nil; end
    if (textures.cache[path] ~= nil) then return textures.cache[path]; end

    local pointer = ffi.new('IDirect3DTexture8*[1]');
    local result = ffi.C.D3DXCreateTextureFromFileA(d3d.get_device(), path, pointer);
    if (result ~= ffi.C.S_OK or pointer[0] == nil) then return nil; end

    local image = ffi.new('IDirect3DTexture8*', pointer[0]);
    d3d.gc_safe_release(image);
    local value = { image = image, path = path };
    textures.cache[path] = value;
    return value;
end

function textures.pointer(texture)
    if (texture == nil or texture.image == nil) then return nil; end
    return tonumber(ffi.cast('uint32_t', texture.image));
end

function textures.clear()
    textures.cache = {};
    collectgarbage('collect');
end

return textures;
