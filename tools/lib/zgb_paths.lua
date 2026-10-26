--[[
    zgb_paths.lua  —  where each generated model lives, shared by
    tools/gen_models.lua (writes the files) and tools/gen_model_list.lua
    (lists them for the 3D side), so the two can never disagree.
]]
local P = {}

P.CATEGORY_FOLDER = { handgun = "Handguns", revolver = "RevolversHandCannons", assault_rifle = "AssaultRifles",
    dmr = "DMRs", sniper = "SniperRifles", smg = "SMGs", shotgun = "Shotguns", lever = "LeverActions" }

function P.partFolder(p)
    local id = p.id
    if p.kind == "muzzle" then
        if id:find("Suppressor") then return "Suppressors" end
        if id:find("FlashHider") then return "FlashHiders" end
        if id:find("Choke") then return "Chokes" end
        return "MuzzleBrakes"
    end
    if p.kind == "underbarrel" then
        if id:find("^Grip") then return "Grips" end
        if id:find("^Laser") then return "Lasers" end
        return "Lights"
    end
    local map = { optic = "Optics", mount = "Mounts", handguard = "Handguards", adapter = "Adapters", bipod = "Bipods",
                  stock = "Stocks", sidesaddle = "ShellHolders", shellholder = "ShellHolders", recoilpad = "RecoilPads", sling = "Slings" }
    return map[p.kind] or "Other"
end

function P.calFolder(label) return (label:gsub("[^%w]+", "")) end

-- relative to media/models_X/ZGB/
function P.gun(spec) return "Guns/" .. (P.CATEGORY_FOLDER[spec.category] or "Other") .. "/" .. spec.id end
function P.part(part) return "Attachments/" .. P.partFolder(part) .. "/" .. part.id end
function P.magazine(mag, caliberLabel) return "Magazines/" .. P.calFolder(caliberLabel) .. "/" .. mag.id end
function P.casing(id) return "Casings/" .. id end

return P
