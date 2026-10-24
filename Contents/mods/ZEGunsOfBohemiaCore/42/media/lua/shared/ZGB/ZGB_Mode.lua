--[[
    ZGB_Mode.lua  —  "Who owns the animations?"

    The crash/flicker you hit with the ADS addon came from TWO systems driving the
    character's weapon animations at the same time (ISO anims + viewpoint anims).
    The rule in this mod: exactly ONE view provider may be registered per session.

      * ZEGunsOfBohemiaIso  registers provider "iso"  (pure Lua, no Java)
      * ZEGunsOfBohemiaFP   (future) registers "fp"   (needs ZombieBuddy / Java)

    A second registration is refused loudly instead of silently stacking.
    mod.info `incompatible=` stops them loading together; this is the runtime
    safety net in case someone forces it (or a third mod is involved).
]]
require "ZGB/ZGB_Core"

ZGB.Mode = ZGB.Mode or {
    provider     = nil,   -- the registered provider table
    providerName = nil,   -- "iso" | "fp"
    conflicts    = {},    -- list of strings describing problems found
}
local Mode = ZGB.Mode

-- Mod IDs that drive first-person / Java-side animation.
-- !! VERIFY: put the EXACT ids from those mods' mod.info files here.
Mode.FP_MOD_IDS = {
    "ZombieBuddy",
    "Viewpoint",
}

--- True if a mod id is active. B42 sometimes reports ids with a leading "\".
function Mode.isModActive(id)
    if not getActivatedMods then return false end
    local mods = getActivatedMods()
    for i = 0, mods:size() - 1 do
        local m = tostring(mods:get(i))
        if m == id or m == ("\\" .. id) then return true end
    end
    return false
end

function Mode.activeFpMods()
    local found = {}
    for _, id in ipairs(Mode.FP_MOD_IDS) do
        if Mode.isModActive(id) then found[#found + 1] = id end
    end
    return found
end

--[[ Provider contract (what a view addon must implement):

    provider = {
        name = "iso",
        -- Script params for vanilla's animation system, per archetype.
        -- Returns a table like { SwingAnim="Rifle", IdleAnim="Idle_Weapon2", ... }
        getAnimParams = function(archetypeId, weaponSpec) end,
        -- Optional hooks:
        onWeaponEquipped = function(player, item, spec) end,
        onAttachmentsChanged = function(player, item, spec) end,
    }
]]
function Mode.registerProvider(provider)
    assert(type(provider) == "table" and provider.name, "provider needs a name")
    if Mode.provider and Mode.providerName ~= provider.name then
        local msg = "Refusing view provider '" .. provider.name .. "': '" ..
                    Mode.providerName .. "' is already active. Enable only ONE ZE Guns Of Bohemia view addon."
        Mode.conflicts[#Mode.conflicts + 1] = msg
        ZGB.err(msg)
        return false
    end
    if type(provider.getAnimParams) ~= "function" then
        ZGB.err("View provider '" .. provider.name .. "' has no getAnimParams()")
        return false
    end
    Mode.provider, Mode.providerName = provider, provider.name
    ZGB.log("View provider active:", provider.name)
    return true
end

function Mode.get() return Mode.provider end
function Mode.is(name) return Mode.providerName == name end

--- Call an optional provider hook safely.
function Mode.notify(hookName, ...)
    local p = Mode.provider
    if p and type(p[hookName]) == "function" then
        local ok, e = pcall(p[hookName], ...)
        if not ok then ZGB.err("provider hook", hookName, "failed:", e) end
    end
end

return Mode
