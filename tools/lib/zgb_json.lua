--[[
    zgb_json.lua  —  tiny JSON encoder for the tools (catalogue, model manifest).
    Tables with [1] (or empty) are arrays; others are objects with sorted keys.
]]
local J = {}

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function J.encode(v)
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t" }
            return map[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        return tostring(v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "nil" then return "null"
    end
    local out = {}
    if v[1] ~= nil or next(v) == nil then
        for _, x in ipairs(v) do out[#out + 1] = J.encode(x) end
        return "[" .. table.concat(out, ",") .. "]"
    end
    for _, k in ipairs(sortedKeys(v)) do out[#out + 1] = J.encode(tostring(k)) .. ":" .. J.encode(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

return J
