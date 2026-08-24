local browser = dofile('ui/encounter_browser.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

local catalog = {
    { content='Example', group='Actionable', encounter='A' },
    { content='Example', group='Research', encounter='B' },
    { content='Example', group='Research', encounter='C' },
};
local rules = {
    { content='Example', group='Actionable', verified=true },
    { content='Example', group='Actionable', verified=true },
    { content='Example', group='Research', verified=false },
};
local categories = browser.build_categories(catalog, rules, function (rule) return rule.group; end);

assert_equal(#categories, 1, 'category count');
assert_equal(categories[1].indexed_count, 3, 'indexed encounter count');
assert_equal(categories[1].rule_count, 2, 'verified rule count');
assert_equal(#categories[1].groups, 2, 'group count');

local actionable = browser.find_group(categories, 'Example', 'Actionable');
local research = browser.find_group(categories, 'Example', 'Research');
assert_equal(actionable.rule_count, 2, 'actionable group rule count');
assert_equal(research.indexed_count, 2, 'research group indexed count');
assert_equal(browser.group_is_visible(actionable, false), true, 'actionable visible by default');
assert_equal(browser.group_is_visible(research, false), false, 'research hidden by default');
assert_equal(browser.group_is_visible(research, true), true, 'research visible when requested');
assert_equal(browser.group_label(research), 'Research  (indexed only)', 'research label');
assert_equal(browser.empty_message('Example', 'Research', '', research),
    'Example / Research is indexed for research, but has no verified alerts yet. This is not a loading error.',
    'research empty state');

print('encounter_browser_spec: all checks passed');
