--[[
    Writes the plain-text list of every asset that needs a 3D model, for the
    3D side (in Portuguese, like the team talks):

        lua5.1 tools/gen_model_list.lua            -> docs/MODEL_LIST.txt

    Generated from the same data as the placeholder models (guns, parts,
    magazines, casings), with the same folders as tools/gen_models.lua.
]]
local CORE = "Contents/mods/ZEGunsOfBohemiaCore/42/media/"
package.path = CORE .. "lua/shared/?.lua;tools/lib/?.lua;" .. package.path
local realPrint = print
print = function() end
require "ZGB/Defs/ZGB_Def_Parts"
require "ZGB/Defs/ZGB_Def_Weapons"
require "ZGB/Defs/ZGB_Def_Models"
require "ZGB/ZGB_Visuals"
print = realPrint
local Paths = require "zgb_paths"
local Sources = dofile("tools/model_sources.lua")
local function box(id) return Sources.MODELS[id] and "[x]" or "[ ]" end
local function sourceLine(id)
    local src = Sources.MODELS[id]
    if not src then return nil end
    local p = Sources.PACKS[src.pack]
    return "    Modelo real: " .. p.title .. " (" .. p.author .. ", " .. p.license .. ") - o artista pode substituir"
end

local WF, PF, MGF, MF, V, AC, R = ZGB.WeaponFactory, ZGB.PartFactory, ZGB.MagazineFactory, ZGB.ModelFactory,
                                  ZGB.Visuals, ZGB.AmmoCatalog, ZGB.Attachments

local CATEGORY_PT = { handgun = "PISTOLAS", revolver = "REVÓLVERES E HAND CANNONS", assault_rifle = "FUZIS DE ASSALTO",
    dmr = "FUZIS DMR (ATIRADOR DESIGNADO)", sniper = "FUZIS DE PRECISÃO (FERROLHO)", smg = "SUBMETRALHADORAS",
    shotgun = "ESCOPETAS", lever = "RIFLES DE ALAVANCA" }
local FOLDER_PT = { Optics = "MIRAS", Mounts = "MONTAGENS", Handguards = "GUARDA-MÃOS", Adapters = "ADAPTADORES",
    Grips = "EMPUNHADURAS", Lights = "LANTERNAS", Lasers = "LASERS", Bipods = "BIPÉS", Suppressors = "SUPRESSORES",
    MuzzleBrakes = "FREIOS DE BOCA E COMPENSADORES", FlashHiders = "QUEBRA-CHAMAS", Stocks = "CORONHAS",
    ShellHolders = "PORTA-CARTUCHOS", RecoilPads = "SOLEIRAS (RECOIL PADS)", Slings = "BANDOLEIRAS", Chokes = "CHOKES" }
local FOLDER_ORDER = { "Optics", "Mounts", "Handguards", "Adapters", "Grips", "Lights", "Lasers", "Bipods",
    "Suppressors", "FlashHiders", "MuzzleBrakes", "Stocks", "ShellHolders", "RecoilPads", "Slings" }
local TIER_PT = { standard = "padrão", extended = "estendido", drum = "tambor" }
local FINISH_PT = { polymer = "polímero preto", wood = "madeira + aço oxidado", steel = "aço", blued = "aço oxidado",
    olive = "verde-oliva", tan = "areia (tan)" }
local CHANNEL_PT = { scope = "mira (scope)", canon = "boca do cano (canon)", stock = "coronha (stock)",
    sling = "bandoleira (sling)", recoilpad = "embaixo do cano (recoilpad)" }

local out = {}
local function w(s) out[#out + 1] = s or "" end
local function cm(m) return string.format("%.1f", m * 100):gsub("%.", ",") end
local function metres(m) return string.format("%.2f", m):gsub("%.", ",") .. " m" end
local function sizeOf(prims)
    local b = MF.bounds(prims)
    return cm(b.max[1] - b.min[1]) .. " x " .. cm(b.max[2] - b.min[2]) .. " x " .. cm(b.max[3] - b.min[3]) .. " cm"
end
local function names(list)
    local t = {}
    for _, s in ipairs(list) do t[#t + 1] = s end
    return table.concat(t, ", ")
end
local function sortedSlots(slots)
    local ids = ZGB.sortedKeys(slots)
    table.sort(ids, function(a, b)
        local oa, ob = slots[a].order or 99, slots[b].order or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return ids
end

-- counts
local guns, parts, noModel, mags = WF.all(), {}, {}, MGF.all()
for _, p in ipairs(PF.all()) do
    if MF.partModel(p) then parts[#parts + 1] = p else noModel[#noModel + 1] = p end
end
local casings, seenCasing = {}, {}
for _, group in ipairs(ZGB.sortedKeys(AC.CASINGS)) do
    local c = AC.CASINGS[group]
    if not seenCasing[c.id] then seenCasing[c.id] = true; casings[#casings + 1] = { id = c.id, name = c.displayName, group = group } end
end
local total = #guns + #parts + #mags + #casings

local RULE = string.rep("=", 78)
local rule = string.rep("-", 78)

w("ZE GUNS OF BOHEMIA - LISTA DE MODELOS 3D (v" .. ZGB.VERSION .. ")")
w("Gerado por tools/gen_model_list.lua a partir dos dados do mod. Não editar à mão.")
w(RULE)
w(string.format("TOTAL: %d modelos para fazer", total))
w(string.format("  %3d armas", #guns))
w(string.format("  %3d attachments (+ %d sem modelo: chokes internos)", #parts, #noModel))
w(string.format("  %3d carregadores", #mags))
w(string.format("  %3d cápsulas vazias", #casings))
local real = 0
for id in pairs(Sources.MODELS) do real = real + 1 end
w()
w(string.format("[x] = já tem modelo real baixado (CC0 / CC-BY, ver CREDITS.txt): %d", real))
w(string.format("[ ] = ainda é placeholder: %d", total - real))
w()
w("REGRAS")
w("  - Nome do arquivo = ID do item. Ex.: AK47.fbx, Optic_RedDot.fbx")
w("  - Cada item tem sua pasta em Contents/mods/ZEGunsOfBohemiaCore/42/media/models_X/ZGB/")
w("    (hoje tem um placeholder lá: troque pelo seu modelo com o mesmo nome).")
w("  - Unidade: metros. Eixos: x = para frente (boca do cano), y = para cima, z = para a direita.")
w("  - Origem da arma: topo do punho, onde a mão segura.")
w("  - Origem do attachment: o ponto onde ele encaixa. Supressores/freios crescem para")
w("    frente, coronhas para trás, miras para cima, empunhaduras/lanternas para baixo.")
w("  - Tamanhos abaixo: arma = comprimento real; attachment = tamanho do placeholder")
w("    (comprimento x altura x largura), só como referência.")
w("  - Variantes (ex.: AK47__Mount_AK_SideRail) NÃO entram nesta lista: modele a arma")
w("    base e cada peça separada. As variantes são a arma com a peça já montada.")
w("  - Guia completo: docs/MODELS.md")
w()

-- ================================================================ guns
w(RULE); w("1. ARMAS (" .. #guns .. ")"); w(RULE)
for _, c in ipairs(ZGB.CATEGORIES) do
    local list = {}
    for _, s in ipairs(guns) do if s.category == c.id then list[#list + 1] = s end end
    if #list > 0 then
        w(); w(CATEGORY_PT[c.id] .. " (" .. #list .. ")"); w(rule)
        for _, s in ipairs(list) do
            local d = MF.gunDims(s.id) or {}
            w(string.format("%s %s - %s", box(s.id), s.id, s.displayName))
            if sourceLine(s.id) then w(sourceLine(s.id)) end
            w("    Pasta:       models_X/ZGB/" .. Paths.gun(s) .. "/" .. s.id .. ".fbx")
            w("    Calibre:     " .. AC.CALIBERS[s.caliber].label .. "   Comprimento: " .. metres(d.len or 0)
              .. "   Acabamento: " .. (FINISH_PT[d.finish] or d.finish or "?"))
            if #s.magazines > 0 then
                local m = {}
                for _, mg in ipairs(s.magazines) do m[#m + 1] = mg.id .. " (" .. TIER_PT[mg.tier] .. ", " .. mg.capacity .. ")" end
                w("    Carregador:  " .. table.concat(m, " | "))
            else
                w("    Carregador:  interno, " .. s.internalCapacity .. " cartuchos (sem modelo de carregador)")
            end
            local slots = sortedSlots(s.slots)
            if #slots == 0 then
                w("    Encaixes:    nenhum (só mira de ferro)")
            else
                w("    Encaixes:")
                local function slotLine(slotId, def, indent, via)
                    local fits = {}
                    for _, p in ipairs(PF.all()) do
                        if R.accepts(def, p) then fits[#fits + 1] = p end
                    end
                    local ids = {}
                    for _, p in ipairs(fits) do ids[#ids + 1] = p.id end
                    w(indent .. "- " .. (def.label or slotId) .. (via and (" (depois de " .. via .. ")") or "") .. ": " .. names(ids))
                    for _, p in ipairs(fits) do
                        for _, cid in ipairs(sortedSlots(p.provides)) do
                            slotLine(cid, p.provides[cid], indent .. "    ", p.id)
                        end
                    end
                end
                for _, id in ipairs(slots) do slotLine(id, s.slots[id], "      ", nil) end
            end
            if s.notes then w("    Obs.:        " .. s.notes) end
            w()
        end
    end
end

-- ================================================================ attachments
w(RULE); w("2. ATTACHMENTS (" .. #parts .. " com modelo)"); w(RULE)
local byFolder = {}
for _, p in ipairs(parts) do
    local f = Paths.partFolder(p)
    byFolder[f] = byFolder[f] or {}
    table.insert(byFolder[f], p)
end
for _, folder in ipairs(FOLDER_ORDER) do
    local list = byFolder[folder]
    if list then
        w(); w(FOLDER_PT[folder] .. " (" .. #list .. ")"); w(rule)
        for _, p in ipairs(list) do
            local m = MF.partModel(p)
            w(string.format("%s %s - %s", box(p.id), p.id, p.displayName))
            if sourceLine(p.id) then w(sourceLine(p.id)) end
            w("    Pasta:       models_X/ZGB/" .. Paths.part(p) .. "/" .. p.id .. ".fbx")
            w("    Tamanho:     " .. sizeOf(m.prims))
            local mode = V.mode(p)
            if mode == "rendered" then
                w("    Aparece:     desenhado pelo jogo no ponto " .. (CHANNEL_PT[V.CHANNEL_POINT[p.vanillaPartType]] or "?") .. " da arma")
            else
                local hides = m.hides and #m.hides > 0 and (" (substitui: " .. table.concat(m.hides, ", ") .. " da arma)") or ""
                w("    Aparece:     montado dentro da variante da arma" .. hides)
            end
            local direct, chained = {}, {}
            for _, s in ipairs(guns) do
                local onBase = false
                for _, def in pairs(s.slots) do if R.accepts(def, p) then onBase = true; break end end
                if onBase then direct[#direct + 1] = s.id
                elseif R.isCompatible(s, p.fullType) then
                    local _, reason, info = R.canAttach(s, {}, p.fullType)
                    local need = {}
                    if reason == "needs" and info.chains[1] then
                        for _, ft in ipairs(info.chains[1]) do need[#need + 1] = PF.get(ft).id end
                    end
                    chained[#chained + 1] = s.id .. " (precisa " .. table.concat(need, " + ") .. ")"
                end
            end
            if #direct > 0 then w("    Encaixa em:  " .. names(direct)) end
            if #chained > 0 then w("    Com peça antes: " .. names(chained)) end
            local provides = {}
            for _, cid in ipairs(sortedSlots(p.provides)) do provides[#provides + 1] = p.provides[cid].label or cid end
            if #provides > 0 then w("    Cria encaixe: " .. names(provides) .. " (deixe espaço/ponto para a peça de cima)") end
            w()
        end
    end
end
if #noModel > 0 then
    local ids = {}
    for _, p in ipairs(noModel) do ids[#ids + 1] = p.id end
    w("SEM MODELO (internos, só ícone): " .. names(ids)); w()
end

-- ================================================================ magazines
w(RULE); w("3. CARREGADORES (" .. #mags .. ")"); w(RULE)
local byCal, calOrder = {}, {}
for _, m in ipairs(mags) do
    if not byCal[m.caliber] then byCal[m.caliber] = {}; calOrder[#calOrder + 1] = m.caliber end
    table.insert(byCal[m.caliber], m)
end
for _, cal in ipairs(calOrder) do
    w(); w(AC.CALIBERS[cal].label .. " (" .. #byCal[cal] .. ")"); w(rule)
    for _, m in ipairs(byCal[cal]) do
        local users = {}
        for _, s in ipairs(WF.gunsForMagazine(m.item)) do users[#users + 1] = s.id end
        w(string.format("[ ] %s - %s", m.id, m.displayName))
        w("    Pasta:       models_X/ZGB/" .. Paths.magazine(m, AC.CALIBERS[m.caliber].label) .. "/" .. m.id .. ".fbx")
        w("    Tipo:        " .. TIER_PT[m.tier] .. ", " .. m.capacity .. " cartuchos   Usado por: " .. names(users))
        w()
    end
end

-- ================================================================ casings
w(RULE); w("4. CÁPSULAS VAZIAS (" .. #casings .. ")"); w(RULE)
w("Caem no chão ao atirar (vista isométrica). Modelos pequenos e simples.")
w()
for _, c in ipairs(casings) do
    w(string.format("[ ] %s - %s", c.id, c.name))
    w("    Pasta:       models_X/ZGB/" .. Paths.casing(c.id) .. "/" .. c.id .. ".fbx")
    w()
end

local path = arg[1] or "docs/MODEL_LIST.txt"
local f = assert(io.open(path, "wb"))
f:write(table.concat(out, "\n")); f:close()
print(string.format("wrote %s: %d models (%d guns, %d attachments, %d magazines, %d casings)",
      path, total, #guns, #parts, #mags, #casings))
