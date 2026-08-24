if (bit == nil and bit32 == nil) then
    -- Fengari is Lua 5.3 but does not ship bit32.  Build a tiny test-only adapter from
    -- native 5.3 bitwise operators without making the production module 5.3-specific.
    bit32 = assert(load([[
        local mask = 0xffffffff
        local function band(...)
            local value = mask
            for index = 1, select('#', ...) do value = value & select(index, ...) end
            return value & mask
        end
        local function bxor(...)
            local value = 0
            for index = 1, select('#', ...) do value = value ~ select(index, ...) end
            return value & mask
        end
        return {
            band = band,
            bxor = bxor,
            bnot = function (value) return (~value) & mask end,
            rshift = function (value, count) return (value & mask) >> count end,
            rrotate = function (value, count)
                count = count % 32
                value = value & mask
                return ((value >> count) | (value << (32 - count))) & mask
            end,
        }
    ]]))();
end

local json = dofile('data/json.lua');
local sha256 = dofile('data/sha256.lua');
local community = dofile('data/community.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(sha256.digest(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'empty SHA-256');
assert_equal(sha256.digest('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'abc SHA-256');

local databaseBody = '{"database_version":1,"published_at":"2026-08-23T00:00:00Z","ability_rules":[],"state_rules":[],"catalog":[]}';
local manifest = assert(community.validate_manifest({
    schema_version = 1,
    database_version = 1,
    minimum_warn_version = '1.9.0',
    published_at = '2026-08-23T00:00:00Z',
    database_url = 'https://raw.githubusercontent.com/SigmanS13/Warn/main/community/database.json',
    sha256 = sha256.digest(databaseBody),
    encounter_count = 0,
    rule_count = 0,
}));
local database = assert(community.validate_database(json.decode(databaseBody)));
assert_equal(sha256.digest(databaseBody), manifest.sha256, 'database hash');
assert_equal(database.database_version, manifest.database_version, 'manifest/database version');

local decoded = json.decode('{"text":"line\\nvalue","unicode":"\\u263a","array":[true,false,3]}');
assert_equal(decoded.text, 'line\nvalue', 'escaped newline');
assert_equal(decoded.array[3], 3, 'array number');

local badUrl = {
    schema_version = 1, database_version = 1, minimum_warn_version = '1.9.0',
    published_at = '2026-08-23T00:00:00Z', database_url = 'https://example.com/database.json',
    sha256 = string.rep('0', 64), encounter_count = 0, rule_count = 0,
};
local _, urlError = community.validate_manifest(badUrl);
assert_equal(urlError ~= nil, true, 'non-official database URL rejected');

local unsafe = {
    database_version = 2,
    published_at = '2026-08-23T00:00:00Z',
    ability_rules = {
        {
            id = 'unsafe_rule', content = 'Test', encounter = 'Test', actor = 'Test Boss',
            event = 'readies', ability = 'Bad Move', message = 'TEST', severity = 'critical',
            sound = '../payload.lua', verified = true, source = 'https://example.com/source',
        },
    },
    state_rules = {}, catalog = {},
};
local _, unsafeError = community.validate_database(unsafe);
assert_equal(unsafeError ~= nil, true, 'path-like sound rejected');

local update = {
    database_version = 2,
    published_at = '2026-08-23T00:00:00Z',
    ability_rules = {
        {
            id = 'existing_rule', content = 'Test', encounter = 'Updated', actor = 'Boss',
            actor_aliases = { 'Boss Prime' },
            event = 'readies', ability = 'Move', message = 'UPDATED', severity = 'danger',
            prediction = 'reactive', target_shape = 'cone', audience = { 'everyone' },
            counter = { type = 'spell', name = 'Stun', label = 'STUN!', responsibility = 'interrupt' },
            verified = true, source = 'https://example.com/source',
        },
        {
            id = 'new_rule', content = 'Test', encounter = 'New', actor = 'Boss',
            event = 'uses', ability = 'Move Two', message = 'NEW', severity = 'important',
            verified = true, source = 'https://example.com/source',
        },
    },
    state_rules = {}, catalog = {},
};
local validatedUpdate = assert(community.validate_database(update));
local merged = community.merge({
    ability_rules = { { id = 'existing_rule', message = 'OLD' } },
    state_rules = {}, catalog = {},
}, validatedUpdate);
assert_equal(#merged.ability_rules, 2, 'merge rule count');
assert_equal(merged.ability_rules[1].message, 'UPDATED', 'stable id replaced');
assert_equal(merged.ability_rules[1].target_shape, 'cone', 'classification metadata retained');
assert_equal(merged.ability_rules[1].actor_aliases[1], 'Boss Prime', 'actor alias retained');
assert_equal(merged.ability_rules[1].counter.responsibility, 'interrupt', 'counter responsibility retained');
assert_equal(merged.ability_rules[2].id, 'new_rule', 'new rule appended');

local badClassification = {
    database_version = 3, published_at = '2026-08-23T00:00:00Z', state_rules = {}, catalog = {},
    ability_rules = {
        {
            id = 'bad_shape', content = 'Test', encounter = 'Test', actor = 'Boss', event = 'readies',
            ability = 'Move', message = 'TEST', severity = 'danger', target_shape = 'guess',
            verified = true, source = 'https://example.com/source',
        },
    },
};
local _, classificationError = community.validate_database(badClassification);
assert_equal(classificationError ~= nil, true, 'unsupported classification rejected');

local executableJson, executableError = pcall(json.decode, 'return os.execute("bad")');
assert_equal(executableJson, false, 'Lua text rejected as JSON');
assert_equal(executableError ~= nil, true, 'Lua rejection includes error');

print('community_spec: all checks passed');
