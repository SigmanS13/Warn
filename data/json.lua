-- Small strict JSON decoder used by Warn's data-only community updater.
-- Remote content is parsed as data and is never passed to load/loadstring/loadfile.

local json = { null = {} };

local function decode_error(position, message)
    error(string.format('JSON error at byte %d: %s', position, message), 0);
end

local function utf8_character(codepoint)
    if (codepoint <= 0x7F) then
        return string.char(codepoint);
    elseif (codepoint <= 0x7FF) then
        return string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40));
    elseif (codepoint <= 0xFFFF) then
        return string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40));
    elseif (codepoint <= 0x10FFFF) then
        return string.char(
            0xF0 + math.floor(codepoint / 0x40000),
            0x80 + (math.floor(codepoint / 0x1000) % 0x40),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40));
    end
    return nil;
end

function json.decode(input)
    if (type(input) ~= 'string') then error('JSON input must be a string.', 0); end
    local length = #input;
    local position = 1;

    local function skip_whitespace()
        while (position <= length) do
            local byte = input:byte(position);
            if (byte == 0x20 or byte == 0x09 or byte == 0x0A or byte == 0x0D) then
                position = position + 1;
            else
                break
            end
        end
    end

    local parse_value;

    local function parse_hex4(at)
        local text = input:sub(at, at + 3);
        if (#text ~= 4 or not text:match('^[0-9a-fA-F]+$')) then
            decode_error(at, 'invalid Unicode escape');
        end
        return tonumber(text, 16);
    end

    local function parse_string()
        position = position + 1; -- opening quote
        local parts = {};
        local segmentStart = position;

        while (position <= length) do
            local byte = input:byte(position);
            if (byte == 0x22) then
                table.insert(parts, input:sub(segmentStart, position - 1));
                position = position + 1;
                return table.concat(parts);
            elseif (byte == 0x5C) then
                table.insert(parts, input:sub(segmentStart, position - 1));
                position = position + 1;
                if (position > length) then decode_error(position, 'unterminated escape'); end
                local escaped = input:sub(position, position);
                local replacements = {
                    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                    b = '\b', f = '\f', n = '\n', r = '\r', t = '\t',
                };
                if (replacements[escaped] ~= nil) then
                    table.insert(parts, replacements[escaped]);
                    position = position + 1;
                elseif (escaped == 'u') then
                    local codepoint = parse_hex4(position + 1);
                    position = position + 5;
                    if (codepoint >= 0xD800 and codepoint <= 0xDBFF) then
                        if (input:sub(position, position + 1) ~= '\\u') then
                            decode_error(position, 'high surrogate without low surrogate');
                        end
                        local low = parse_hex4(position + 2);
                        if (low < 0xDC00 or low > 0xDFFF) then
                            decode_error(position + 2, 'invalid low surrogate');
                        end
                        codepoint = 0x10000 + ((codepoint - 0xD800) * 0x400) + (low - 0xDC00);
                        position = position + 6;
                    elseif (codepoint >= 0xDC00 and codepoint <= 0xDFFF) then
                        decode_error(position - 4, 'unexpected low surrogate');
                    end
                    local encoded = utf8_character(codepoint);
                    if (encoded == nil) then decode_error(position, 'invalid Unicode codepoint'); end
                    table.insert(parts, encoded);
                else
                    decode_error(position, 'invalid escape');
                end
                segmentStart = position;
            elseif (byte < 0x20) then
                decode_error(position, 'control character in string');
            else
                position = position + 1;
            end
        end
        decode_error(position, 'unterminated string');
    end

    local function parse_number()
        local start = position;
        if (input:sub(position, position) == '-') then position = position + 1; end
        if (input:sub(position, position) == '0') then
            position = position + 1;
        else
            if (not input:sub(position, position):match('%d')) then decode_error(position, 'invalid number'); end
            while (position <= length and input:sub(position, position):match('%d')) do position = position + 1; end
        end
        if (input:sub(position, position) == '.') then
            position = position + 1;
            if (not input:sub(position, position):match('%d')) then decode_error(position, 'invalid fraction'); end
            while (position <= length and input:sub(position, position):match('%d')) do position = position + 1; end
        end
        local exponent = input:sub(position, position);
        if (exponent == 'e' or exponent == 'E') then
            position = position + 1;
            local sign = input:sub(position, position);
            if (sign == '+' or sign == '-') then position = position + 1; end
            if (not input:sub(position, position):match('%d')) then decode_error(position, 'invalid exponent'); end
            while (position <= length and input:sub(position, position):match('%d')) do position = position + 1; end
        end
        local value = tonumber(input:sub(start, position - 1));
        if (value == nil or value ~= value or value == math.huge or value == -math.huge) then
            decode_error(start, 'number is not finite');
        end
        return value;
    end

    local function parse_array(depth)
        if (depth > 64) then decode_error(position, 'maximum nesting depth exceeded'); end
        position = position + 1;
        skip_whitespace();
        local result = {};
        if (input:sub(position, position) == ']') then position = position + 1; return result; end
        while (true) do
            table.insert(result, parse_value(depth + 1));
            skip_whitespace();
            local token = input:sub(position, position);
            if (token == ']') then position = position + 1; return result; end
            if (token ~= ',') then decode_error(position, 'expected comma or closing bracket'); end
            position = position + 1;
            skip_whitespace();
        end
    end

    local function parse_object(depth)
        if (depth > 64) then decode_error(position, 'maximum nesting depth exceeded'); end
        position = position + 1;
        skip_whitespace();
        local result = {};
        if (input:sub(position, position) == '}') then position = position + 1; return result; end
        while (true) do
            if (input:sub(position, position) ~= '"') then decode_error(position, 'expected string key'); end
            local key = parse_string();
            if (result[key] ~= nil) then decode_error(position, 'duplicate object key: ' .. key); end
            skip_whitespace();
            if (input:sub(position, position) ~= ':') then decode_error(position, 'expected colon'); end
            position = position + 1;
            skip_whitespace();
            result[key] = parse_value(depth + 1);
            skip_whitespace();
            local token = input:sub(position, position);
            if (token == '}') then position = position + 1; return result; end
            if (token ~= ',') then decode_error(position, 'expected comma or closing brace'); end
            position = position + 1;
            skip_whitespace();
        end
    end

    parse_value = function (depth)
        skip_whitespace();
        local token = input:sub(position, position);
        if (token == '"') then return parse_string(); end
        if (token == '{') then return parse_object(depth); end
        if (token == '[') then return parse_array(depth); end
        if (token == '-' or token:match('%d')) then return parse_number(); end
        if (input:sub(position, position + 3) == 'true') then position = position + 4; return true; end
        if (input:sub(position, position + 4) == 'false') then position = position + 5; return false; end
        if (input:sub(position, position + 3) == 'null') then position = position + 4; return json.null; end
        decode_error(position, 'unexpected token');
    end

    local result = parse_value(0);
    skip_whitespace();
    if (position <= length) then decode_error(position, 'trailing content'); end
    return result;
end

return json;
