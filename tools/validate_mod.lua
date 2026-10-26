--[[
    Checks the whole mod OFFLINE, the way the game will read it, so problems
    show up before a slow game launch:

        lua5.1 tools/validate_mod.lua          (exit code 1 when something is broken)

    - every mod folder: 42/mod.info fields, common/, poster, required mods
    - every script: items -> icons, models, visual twins; models -> mesh and
      texture files; sounds -> audio files; every gun's sounds exist
    - every Lua file compiles; no `goto` (Kahlua rejects it), no `next()` and no `package.` (Kahlua has neither)
    - AnimSet XML is well formed; sandbox options have labels
    - PNG / FBX / OGG files have valid headers; sizes of the atlas and icons
    - Workshop packaging: workshop.txt and preview.png (256 x 256)
]]
local ROOT = "Contents/mods/"
local CORE = ROOT .. "ZEGunsOfBohemiaCore/42/media/"
package.path = CORE .. "lua/shared/?.lua;" .. package.path

local isWindows = package.config:sub(1, 1) == "\\"
local fails, warns, oks = {}, {}, 0
local function fail(msg) fails[#fails + 1] = msg end
local function warn(msg) warns[#warns + 1] = msg end
local function ok() oks = oks + 1 end
local function read(path) local f = io.open(path, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local function exists(path) local f = io.open(path, "rb"); if f then f:close(); return true end return false end
local function list(cmdWin, cmdNix)
    local p = io.popen(isWindows and cmdWin or cmdNix)
    local out = {}
    for l in p:lines() do out[#out + 1] = l:gsub("\\", "/") end
    p:close(); return out
end
local function u32(s, i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
local function pngSize(path)
    local s = read(path)
    if not s or s:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
    return u32(s, 17), u32(s, 21)
end

local MODS = {}
for _, d in ipairs(list('dir /b /ad "' .. ROOT:gsub("/", "\\") .. '"', 'ls -1 "' .. ROOT .. '"')) do MODS[#MODS + 1] = d end
local MODIDS = {}
-- mods of other authors we require (Workshop items, also listed as required on our Workshop page)
local EXTERNAL = { SWMG = "Gunworks Framework, Workshop 3722064198" }
for id in pairs(EXTERNAL) do MODIDS[id] = true end

-- ---------------------------------------------------------------- mod folders
for _, m in ipairs(MODS) do
    local base = ROOT .. m .. "/"
    local info = read(base .. "42/mod.info")
    if not info then fail(m .. ": 42/mod.info missing") else
        local fields = {}
        for k, v in info:gmatch("([%w_]+)=([^\r\n]*)") do fields[k] = v end
        for _, k in ipairs({ "name", "id", "modversion", "versionMin", "description" }) do
            if not fields[k] or fields[k] == "" then fail(m .. ": mod.info has no " .. k) end
        end
        if fields.id and fields.id ~= m then fail(m .. ": mod.info id '" .. fields.id .. "' differs from the folder name") end
        MODIDS[fields.id or m] = true
        for _, k in ipairs({ "poster", "icon" }) do
            if fields[k] and not exists(base .. "42/" .. fields[k]) then fail(m .. ": " .. k .. " " .. fields[k] .. " missing") end
        end
        if not fields.poster then warn(m .. ": no poster (Workshop / mod list picture)") end
        fields.__require = fields.require
        MODS[m] = fields
        ok()
    end
    if not exists(base .. "common/README.txt") and not exists(base .. "common") then fail(m .. ": common/ folder missing (B42 layout)") end
end
for _, m in ipairs(MODS) do
    local req = MODS[m] and MODS[m].__require
    for id in (req or ""):gmatch("\\?([%w_]+)") do
        if not MODIDS[id] then fail(m .. ": requires unknown mod " .. id) end
    end
end

-- ---------------------------------------------------------------- scripts
local items, models, sounds, textures = {}, {}, {}, {}
local function blocks(text, kind)
    local out = {}
    for name, body in text:gmatch("\n%s*" .. kind .. "%s+([%w_]+)%s*{(.-)\n%s*}") do out[name] = body end
    return out
end
for _, m in ipairs(MODS) do
    local dir = ROOT .. m .. "/42/media/scripts/"
    for _, f in ipairs(list('dir /b "' .. dir:gsub("/", "\\") .. '*.txt" 2>nul', 'ls -1 "' .. dir .. '" 2>/dev/null | grep .txt$')) do
        local text = read(dir .. f) or ""
        -- items: capture the whole block body up to the matching close (items have no nested braces)
        for name, body in text:gmatch("\n%s*item%s+([%w_]+)%s*{(.-)}") do items[name] = { body = body, file = f, mod = m } end
        for name, body in text:gmatch("\n%s*model%s+([%w_]+)%s*{(.-)\n    }") do models[name] = { body = body, file = f, mod = m } end
        for name, body in text:gmatch("\n%s*sound%s+([%w_]+)%s*{(.-)\n    }") do sounds[name] = { body = body, file = f, mod = m } end
    end
end
local function modMedia(mod) return ROOT .. mod .. "/42/media/" end

local nIcons = 0
for name, it in pairs(items) do
    local icon = it.body:match("Icon%s*=%s*([%w_]+)")
    if icon and icon:find("^ZGB_") then
        local w, h = pngSize(CORE .. "textures/Item_" .. icon .. ".png")
        if not w then fail("item " .. name .. ": icon Item_" .. icon .. ".png missing or not a PNG")
        elseif w ~= 32 or h ~= 32 then warn("item " .. name .. ": icon is " .. w .. "x" .. h .. " (32x32 expected)")
        else nIcons = nIcons + 1 end
    end
    for _, field in ipairs({ "WeaponSprite", "WorldStaticModel" }) do
        local ref = it.body:match(field .. "%s*=%s*ZGB%.([%w_]+)")
        if ref and not models[ref] then fail("item " .. name .. ": " .. field .. " -> missing model " .. ref) end
    end
    for twin, model in it.body:gmatch("ModelWeaponPart%s*=%s*ZGB%.([%w_]+)%s+ZGB%.([%w_]+)") do
        if not items[twin] then fail("item " .. name .. ": ModelWeaponPart twin " .. twin .. " missing") end
        if not models[model] then fail("item " .. name .. ": ModelWeaponPart model " .. model .. " missing") end
    end
end
ok()

-- largest "Lcl Scaling" in a binary FBX (Blender's default export puts x100 there)
local function f64(s, i)
    local b = { s:byte(i, i + 7) }
    local e = (b[8] % 128) * 16 + math.floor(b[7] / 16)
    if e == 0 then return 0 end
    local m = b[7] % 16
    for k = 6, 1, -1 do m = m * 256 + b[k] end
    return (b[8] >= 128 and -1 or 1) * (1 + m / 2 ^ 52) * 2 ^ (e - 1023)
end
-- largest |value| of a node property (Lcl Scaling / Lcl Rotation) in a binary FBX
local function fbxNodeMax(data, prop, start)
    local best, pos = start, 1
    while true do
        local _, b = data:find(prop, pos, true)
        if not b then return best end
        local i = b + 1
        for _ = 1, 3 do                                   -- skip the type strings: 'S' + int32 length + bytes
            if data:sub(i, i) ~= "S" then break end
            local l1, l2, l3, l4 = data:byte(i + 1, i + 4)
            i = i + 5 + l1 + l2 * 256 + l3 * 65536 + l4 * 16777216
        end
        for _ = 1, 3 do                                   -- x, y, z
            if data:sub(i, i) ~= "D" then break end
            best = math.max(best, math.abs(f64(data, i + 1))); i = i + 9
        end
        pos = b + 1
    end
end
local function fbxNodeScale(data) return fbxNodeMax(data, "Lcl Scaling", 1) end
local function fbxNodeRotation(data) return fbxNodeMax(data, "Lcl Rotation", 0) end

local fbxOk, texSeen = 0, {}
for name, mdl in pairs(models) do
    local mesh = mdl.body:match("mesh%s*=%s*([^,\n]+)")
    local tex = mdl.body:match("texture%s*=%s*([^,\n]+)")
    local base = modMedia(mdl.mod) .. "models_X/" .. (mesh or "")
    local data = read(base .. ".fbx") or read(base .. ".X")
    if not mesh or not data then fail("model " .. name .. ": mesh file " .. tostring(mesh) .. " (.fbx/.X) missing")
    elseif data:sub(1, 18) == "Kaydara FBX Binary" or data:sub(1, 3) == "xof" or data:find("FBXHeaderExtension", 1, true) then
        fbxOk = fbxOk + 1
        if fbxNodeScale(data) > 1.5 then
            fail("model " .. name .. ": FBX node scale " .. fbxNodeScale(data) .. " (the game ignores the FBX unit: export plain metres, node scale 1)")
        end
        if fbxNodeRotation(data) > 0.5 then
            fail("model " .. name .. ": FBX node rotation " .. fbxNodeRotation(data) .. " deg (the game reads attachment points without it: muzzle flash and parts end up elsewhere; export with bake_space_transform)")
        end
    else fail("model " .. name .. ": mesh file is not FBX or .X") end
    if tex and not texSeen[tex] then
        texSeen[tex] = true
        local w = pngSize(modMedia(mdl.mod) .. "textures/" .. tex .. ".png")
        if not w then fail("model " .. name .. ": texture " .. tex .. ".png missing")
        elseif w > 4096 then warn("texture " .. tex .. " is " .. w .. " px wide (over 4096)") end
    end
end
ok()

local oggOk = 0
for name, s in pairs(sounds) do
    local file = s.body:match("file%s*=%s*([^,\n]+)")
    local data = file and read(ROOT .. s.mod .. "/42/" .. file)
    if not data then fail("sound " .. name .. ": file " .. tostring(file) .. " missing")
    elseif data:sub(1, 4) ~= "OggS" and data:sub(1, 4) ~= "RIFF" then fail("sound " .. name .. ": not an Ogg/WAV file")
    else oggOk = oggOk + 1 end
end
-- vanilla declares every sound in module Base; ours in module ZGB played nothing in game
local soundFiles = {}
for _, s in pairs(sounds) do soundFiles[ROOT .. s.mod .. "/42/media/scripts/" .. s.file] = true end
for f in pairs(soundFiles) do
    local text = read(f) or ""
    if not text:find("\nmodule%s+Base%s*\n?%s*{") then fail("sound scripts in " .. f .. " must be in module Base (like vanilla)") end
    for _, field in ipairs({ "is3D", "loop" }) do
        if text:find("\n%s*" .. field .. "%s*=") then fail("sound scripts in " .. f .. ": field " .. field .. " is not used by vanilla sounds") end
    end
end

-- every gun's sounds exist
local realPrint = print
print = function() end
require "ZGB/Defs/ZGB_Def_Parts"; require "ZGB/Defs/ZGB_Def_Weapons"
print = realPrint
for _, spec in ipairs(ZGB.WeaponFactory.all()) do
    for key, snd in pairs(spec.sounds or {}) do
        if key ~= "family" and type(snd) == "string" and snd:find("^ZGB_") and not sounds[snd] then
            fail("gun " .. spec.id .. ": sound " .. key .. " = " .. snd .. " has no sound script")
        end
    end
    if not items[spec.id] then fail("gun " .. spec.id .. ": no item script") end
end
ok()

-- every ammo type we register appears as `AmmoType = <id>` in an item script. The game creates an
-- ammo type's bullet tracer config only while reading item scripts (Item -> IsoBulletTracerEffects.
-- load); one set later by DoParam had none and the first shot crashed the game (fourth and fifth
-- in-game tests: NullPointerException in IsoBulletTracerEffects.createEffect)
do
    local inScripts = {}
    for _, it in pairs(items) do
        local id = it.body:match("\n%s*AmmoType%s*=%s*([^,\n]+)")
        if id then inScripts[id] = true end
    end
    local registries = read(CORE .. "registries.lua") or ""
    for id in registries:gmatch('AmmoType%.register%("([^"]+)"') do
        if not inScripts[id] then fail("ammo type " .. id .. " is in no item script: firing it crashes (no tracer config)") end
    end
    for _, spec in ipairs(ZGB.WeaponFactory.all()) do
        local body = items[spec.id] and items[spec.id].body or ""
        if not body:find("\n%s*AmmoType%s*=") then fail("gun " .. spec.id .. ": no AmmoType in its item script (tracer config)") end
    end
    ok()
end

-- every field ScriptApply writes exists in the installed game's own gun scripts, and is a whole
-- number where vanilla always writes one (the game rejects "RecoilDelay = 12.5")
local PZ = os.getenv("PZ_DIR") or "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"
local vanilla = read(PZ .. "/media/scripts/generated/items/weapon.txt")
if not vanilla then
    warn("game install not found (set PZ_DIR): item fields not checked against vanilla")
else
    local seen, intOnly = { displayname = true }, {}      -- DisplayName: any item; vanilla B42 uses translations
    for k, v in vanilla:gmatch("\n%s*([%w_]+)%s*=%s*([^,\r\n]*)") do
        local key = k:lower()
        seen[key] = true
        local n = tonumber(v)
        if n then intOnly[key] = (intOnly[key] ~= false) and not v:find("%.") end
    end
    package.path = ROOT .. "ZEGunsOfBohemiaIso/42/media/lua/shared/?.lua;" .. package.path
    print = function() end
    require "ZGB/ZGB_ScriptApply"
    local isoOk = pcall(require, "ZGBIso/ZGB_ViewIso")
    print = realPrint
    local provider = isoOk and ZGB.Mode.get()
    if not provider then warn("Iso view did not load: its animation fields were not checked") end
    local SA, bad = ZGB.ScriptApply, {}
    for _, spec in ipairs(ZGB.WeaponFactory.all()) do
        local anim = provider and provider.getAnimParams(spec.archetype, spec) or nil
        for _, kv in ipairs(SA.paramsFor(spec, anim)) do
            local key, v = kv[1]:lower(), kv[2]
            if not seen[key] and not bad[key] then
                bad[key] = true; fail("item field " .. kv[1] .. " is not used by any vanilla gun (wrong name? " .. spec.id .. ")")
            elseif intOnly[key] and type(v) == "number" and v ~= math.floor(v) and not bad[key] then
                bad[key] = true; fail("item field " .. kv[1] .. " = " .. v .. " on " .. spec.id .. ": the game wants a whole number")
            end
        end
    end
    ok()
end

-- ---------------------------------------------------------------- Lua
local LJ = os.getenv("LUAJIT") or ((os.getenv("LOCALAPPDATA") or "") .. "/Programs/LuaJIT/bin/luajit.exe")
local luaFiles = list('dir /b /s "' .. ROOT:gsub("/", "\\") .. '*.lua"', 'find "' .. ROOT .. '" -name "*.lua"')
local badLua = 0
for _, f in ipairs(luaFiles) do
    local src = read(f) or ""
    local fn, err = loadstring and loadstring(src, f) or load(src, f)
    if not fn then fail("Lua syntax: " .. tostring(err)); badLua = badLua + 1 end
    for line in src:gmatch("[^\n]+") do
        local code = line:gsub("%-%-.*$", "")
        if code:match("%f[%w]goto%f[%W]") then fail("Lua: `goto` (Kahlua rejects it) in " .. f) end
        if code:match("%f[%w_.:]next%s*%(") then fail("Lua: `next()` (missing in Kahlua, use ZGB.isEmpty or pairs) in " .. f) end
        -- Kahlua has no `package` table (package.loaded crashed the self-test on the test server)
        if code:match("%f[%w_]package%.") then fail("Lua: `package.` (missing in Kahlua) in " .. f) end
        if code:match("[^/]//[^/]") and not code:match("https?://") and not code:match("['\"].-//.-['\"]") then
            fail("Lua: integer division `//` in " .. f .. ": " .. line)
        end
    end
end
ok()

-- every game method we call exists in the installed game (index: tools/gen_pz_api.lua)
local apiNames = read(".cache/pz_api/names.txt")
if not apiNames then
    warn("no game API index: run tools/gen_pz_api.lua to check method names against the installed game")
else
    local known, ours, used = {}, {}, {}
    for l in apiNames:gmatch("[^\r\n]+") do known[l] = true end
    for _, f in ipairs(luaFiles) do
        local src = (read(f) or ""):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
        for id in src:gmatch("function%s+[%w_%.:]-([%a_][%w_]*)%s*%(") do ours[id] = true end
        for id in src:gmatch("([%a_][%w_]*)%s*=%s*function") do ours[id] = true end
        for id in src:gmatch(":([%a_][%w_]*)%s*%(") do used[id] = used[id] or f end
        -- names handed to callSetter / guarded calls as strings ("setMaxAmmo")
        for id in src:gmatch('"(%l+%u[%w_]*)"') do
            if id:match("^[sg]et%u") or id:match("^is%u") then used[id] = used[id] or f end
        end
    end
    local STRING_METHODS = { find = 1, sub = 1, gsub = 1, match = 1, gmatch = 1, format = 1,
                             lower = 1, upper = 1, rep = 1, byte = 1, len = 1, reverse = 1 }
    local unknown = {}
    for id, f in pairs(used) do
        if not known[id] and not ours[id] and not STRING_METHODS[id] then unknown[#unknown + 1] = id .. " (" .. f:match("[^/\\]+$") .. ")" end
    end
    table.sort(unknown)
    for _, u in ipairs(unknown) do fail("game API: no method " .. u .. " in this game build") end
    ok()
end

-- ---------------------------------------------------------------- AnimSets, sandbox labels
local xmlFiles = list('dir /b /s "' .. ROOT:gsub("/", "\\") .. '*.xml" 2>nul', 'find "' .. ROOT .. '" -name "*.xml"')
for _, f in ipairs(xmlFiles) do
    local s = read(f) or ""
    local depth = 0
    for close, tag in s:gmatch("<(/?)([%w_]+)[^>]*>") do
        if close == "/" then depth = depth - 1 else depth = depth + 1 end
        if depth < 0 then break end
    end
    if depth ~= 0 then fail("AnimSet XML not balanced: " .. f) end
    local extends = s:match('<animNode%s+x_extends="([^"]+)"')
    if extends then
        -- the game looks for the parent next to this file, in OUR mod; a vanilla node of the
        -- same name does not count (seen in game: 288 parse errors, guns could not aim or fire)
        if not exists((f:gsub("[^/\\]+$", extends))) then
            fail("AnimSet " .. f .. " extends " .. extends .. ", which is not in our mod (the game won't find the vanilla one)")
        end
    elseif not s:find("<m_AnimName>[^<]+</m_AnimName>") then fail("AnimSet without m_AnimName: " .. f) end
end
for _, m in ipairs(MODS) do
    local opts = read(ROOT .. m .. "/42/media/sandbox-options.txt")
    if opts then
        local labels = read(ROOT .. m .. "/42/media/lua/shared/Translate/EN/Sandbox_EN.txt") or ""
        for key in opts:gmatch("translation%s*=%s*([%w_]+)") do
            if not labels:find("Sandbox_" .. key .. " =", 1, true) then fail(m .. ": sandbox option " .. key .. " has no label") end
        end
        local fn = (loadstring or load)(labels)
        if not fn then fail(m .. ": Sandbox_EN.txt is not a valid Lua table") end
    end
end
ok()

-- ---------------------------------------------------------------- Workshop packaging
-- everything under Contents is uploaded: only the mods folder belongs there (test reports did land there once)
for _, name in ipairs(list('dir /b "Contents"', 'ls -1 Contents')) do
    if name ~= "mods" then fail("Contents/" .. name .. " would be uploaded to the Workshop: move it out of Contents") end
end
local ws = read("workshop.txt")
if not ws then fail("workshop.txt missing (Workshop upload)") else
    for _, k in ipairs({ "version", "title", "description", "tags", "visibility" }) do
        if not ws:find("\n" .. k .. "=") and not ws:find("^" .. k .. "=") then fail("workshop.txt has no " .. k) end
    end
end
local pw, ph = pngSize("preview.png")
if not pw then fail("preview.png missing (Workshop picture)") elseif pw ~= 256 or ph ~= 256 then fail("preview.png must be 256x256, is " .. pw .. "x" .. ph) end
ok()

-- ---------------------------------------------------------------- report
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
print(string.format("ZE Guns Of Bohemia - offline check of %d mods", #MODS))
print(string.format("  %d items, %d models (%d mesh files ok), %d sounds (%d audio files ok), %d icons, %d Lua files, %d AnimSet nodes",
      count(items), count(models), fbxOk, count(sounds), oggOk, nIcons, #luaFiles, #xmlFiles))
for _, w in ipairs(warns) do print("  WARN " .. w) end
for i, f in ipairs(fails) do if i <= 60 then print("  FAIL " .. f) end end
if #fails > 60 then print(string.format("  ... and %d more", #fails - 60)) end
print(#fails == 0 and string.format("OK: %d checks passed, %d warnings", oks, #warns)
                  or string.format("BROKEN: %d problems, %d warnings", #fails, #warns))
if #fails > 0 then os.exit(1) end
