--[[
    ZGB_Sandbox.lua  —  read sandbox options with safe defaults.

    Options live in each addon's media/sandbox-options.txt under the page
    "ZGB". In game they show up as SandboxVars.<Namespace>.<Option>. Outside
    the game (tests) or before the world loads, the default is returned.

      ZGB.Sandbox.get("ZGBHolding", "UseAimingLevel", true)
]]
require "ZGB/ZGB_Core"

ZGB.Sandbox = ZGB.Sandbox or { overrides = {} }
local SB = ZGB.Sandbox

function SB.get(namespace, option, default)
    local o = SB.overrides[namespace]
    if o and o[option] ~= nil then return o[option] end
    local vars = rawget(_G, "SandboxVars")
    local ns = vars and vars[namespace]
    local v = ns and ns[option]
    if v == nil then return default end
    if type(default) == "number" then return tonumber(v) or default end
    return v
end

--- Testing / debug helper: force a value without SandboxVars.
function SB.set(namespace, option, value)
    SB.overrides[namespace] = SB.overrides[namespace] or {}
    SB.overrides[namespace][option] = value
end

function SB._reset() SB.overrides = {} end

return SB
