-- Pure encounter-browser metadata helpers. Kept separate from ImGui so layout behavior can
-- be regression-tested without loading Ashita.

local M = {};

function M.build_categories(catalog, rules, get_rule_group)
    local map = {};

    local function ensure_group(content, group)
        map[content] = map[content] or {};
        map[content][group] = map[content][group] or { name = group, indexed_count = 0, rule_count = 0 };
        return map[content][group];
    end

    for _, entry in ipairs(catalog or {}) do
        local content = tostring(entry.content or 'Other');
        local group = tostring(entry.group or 'General');
        local item = ensure_group(content, group);
        item.indexed_count = item.indexed_count + 1;
    end

    for _, rule in ipairs(rules or {}) do
        if (rule.verified == true) then
            local content = tostring(rule.content or 'Other');
            local group = tostring(get_rule_group(rule) or 'General');
            local item = ensure_group(content, group);
            item.rule_count = item.rule_count + 1;
        end
    end

    local result = {};
    for content, groups in pairs(map) do
        local category = { content = content, groups = {}, indexed_count = 0, rule_count = 0 };
        for _, group in pairs(groups) do
            table.insert(category.groups, group);
            category.indexed_count = category.indexed_count + group.indexed_count;
            category.rule_count = category.rule_count + group.rule_count;
        end
        table.sort(category.groups, function (a, b) return a.name:lower() < b.name:lower(); end);
        table.insert(result, category);
    end
    table.sort(result, function (a, b) return a.content:lower() < b.content:lower(); end);
    return result;
end

function M.find_group(categories, content, group_name)
    for _, category in ipairs(categories or {}) do
        if (category.content == content) then
            for _, group in ipairs(category.groups or {}) do
                if (group.name == group_name) then return group; end
            end
        end
    end
    return nil;
end

function M.group_is_visible(group, show_indexed_only)
    return group ~= nil and ((group.rule_count or 0) > 0 or show_indexed_only == true);
end

function M.group_label(group)
    if ((group.rule_count or 0) > 0) then
        return string.format('%s  (%d)', tostring(group.name), group.rule_count);
    end
    return tostring(group.name) .. '  (indexed only)';
end

function M.empty_message(content, group_name, search_term, group)
    if (tostring(search_term or '') ~= '') then
        return 'No verified alerts match this search and category selection.';
    end
    if (content ~= nil and group_name ~= nil and group ~= nil and (group.rule_count or 0) == 0) then
        return string.format('%s / %s is indexed for research, but has no verified alerts yet. This is not a loading error.', tostring(content), tostring(group_name));
    end
    return 'No verified alerts match this view.';
end

return M;
