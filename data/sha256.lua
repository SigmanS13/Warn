-- Pure Lua SHA-256 used to verify downloaded community database bytes.

local bitops = rawget(_G, 'bit') or rawget(_G, 'bit32');
if (bitops == nil) then
    local ok, loaded = pcall(require, 'bit');
    if (ok) then bitops = loaded; end
end
if (bitops == nil) then error('SHA-256 requires bit or bit32 operations.'); end

local band = bitops.band;
local bxor = bitops.bxor;
local bnot = bitops.bnot;
local rshift = bitops.rshift;
local ror = bitops.ror or bitops.rrotate;

local constants = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

local function add(...)
    local total = 0;
    for index = 1, select('#', ...) do total = total + (select(index, ...)); end
    return band(total, 0xFFFFFFFF);
end

local function byte_word(a, b, c, d)
    return add(a * 0x1000000, b * 0x10000, c * 0x100, d);
end

local function to_unsigned(value)
    value = band(value, 0xFFFFFFFF);
    if (value < 0) then return value + 4294967296; end
    return value;
end

local function word_hex(value)
    value = to_unsigned(value);
    local digits = '0123456789abcdef';
    local parts = {};
    for index = 7, 0, -1 do
        local nibble = math.floor(value / (16 ^ index)) % 16;
        table.insert(parts, digits:sub(nibble + 1, nibble + 1));
    end
    return table.concat(parts);
end

local sha256 = {};

function sha256.digest(message)
    if (type(message) ~= 'string') then error('SHA-256 input must be a string.'); end

    local originalLength = #message;
    local bitLength = originalLength * 8;
    local high = math.floor(bitLength / 4294967296);
    local low = bitLength % 4294967296;
    local zeroCount = (56 - ((originalLength + 1) % 64)) % 64;
    message = message .. string.char(0x80) .. string.rep('\0', zeroCount) .. string.char(
        math.floor(high / 0x1000000) % 256,
        math.floor(high / 0x10000) % 256,
        math.floor(high / 0x100) % 256,
        high % 256,
        math.floor(low / 0x1000000) % 256,
        math.floor(low / 0x10000) % 256,
        math.floor(low / 0x100) % 256,
        low % 256);

    local hash = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    };

    local words = {};
    for chunk = 1, #message, 64 do
        for index = 0, 15 do
            local offset = chunk + (index * 4);
            words[index] = byte_word(message:byte(offset, offset + 3));
        end
        for index = 16, 63 do
            local x = words[index - 15];
            local y = words[index - 2];
            local sigma0 = bxor(ror(x, 7), ror(x, 18), rshift(x, 3));
            local sigma1 = bxor(ror(y, 17), ror(y, 19), rshift(y, 10));
            words[index] = add(words[index - 16], sigma0, words[index - 7], sigma1);
        end

        local a, b, c, d = hash[1], hash[2], hash[3], hash[4];
        local e, f, g, h = hash[5], hash[6], hash[7], hash[8];
        for index = 0, 63 do
            local sum1 = bxor(ror(e, 6), ror(e, 11), ror(e, 25));
            local choice = bxor(band(e, f), band(bnot(e), g));
            local temp1 = add(h, sum1, choice, constants[index + 1], words[index]);
            local sum0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22));
            local majority = bxor(band(a, b), band(a, c), band(b, c));
            local temp2 = add(sum0, majority);
            h, g, f, e, d, c, b, a = g, f, e, add(d, temp1), c, b, a, add(temp1, temp2);
        end

        hash[1] = add(hash[1], a);
        hash[2] = add(hash[2], b);
        hash[3] = add(hash[3], c);
        hash[4] = add(hash[4], d);
        hash[5] = add(hash[5], e);
        hash[6] = add(hash[6], f);
        hash[7] = add(hash[7], g);
        hash[8] = add(hash[8], h);
    end

    local parts = {};
    for index = 1, 8 do parts[index] = word_hex(hash[index]); end
    return table.concat(parts);
end

return sha256;
