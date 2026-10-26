--[[ A fake of the PZ UI the Gunsmith screen uses (ISPanel, ISButton, text and texture
     drawing), for two jobs:
       * tests: run the real window code offline, every draw call recorded
       * tools/preview_gunsmith.lua: turn the recorded calls into a PNG, so the layout can
         be looked at without starting the game
     Textures are drawn as the model's silhouette (placeholder geometry): no PNG reader. ]]
local MockUI = { ops = {} }

local function rec(op) MockUI.ops[#MockUI.ops + 1] = op end
local function noop() end

function MockUI.install(screenW, screenH)
    MockUI.ops = {}
    MockUI.screenW, MockUI.screenH = screenW or 1920, screenH or 1080
    local Element = {}
    Element.__index = Element
    function Element:derive(name)
        local c = setmetatable({ Type = name }, { __index = self })
        c.__index = c
        return c
    end
    function Element.new(cls, x, y, w, h)
        return setmetatable({ x = x, y = y, width = w, height = h, children = {} }, cls)
    end
    for _, k in ipairs({ "initialise", "instantiate", "createChildren", "update", "render", "prerender",
                         "addToUIManager", "removeFromUIManager", "bringToTop", "setVisible", "setAlwaysOnTop" }) do
        Element[k] = noop
    end
    function Element:addChild(c) self.children[#self.children + 1] = c end
    function Element:getMouseX() return MockUI.mouseX or 0 end
    function Element:getMouseY() return MockUI.mouseY or 0 end
    function Element:drawRect(x, y, w, h, a, r, g, b) rec({ "rect", x, y, w, h, r, g, b, a }) end
    function Element:drawRectBorder(x, y, w, h, a, r, g, b) rec({ "border", x, y, w, h, r, g, b, a }) end
    function Element:drawLine2(x, y, x2, y2, a, r, g, b) rec({ "line", x, y, x2, y2, r, g, b, a }) end
    function Element:drawText(s, x, y, r, g, b, a, font)
        assert(type(s) == "string", "drawText needs a string, got " .. type(s)); rec({ "text", x, y, s, r, g, b, a })
    end
    function Element:drawTextCentre(s, x, y, r, g, b, a, font)
        assert(type(s) == "string", "drawTextCentre needs a string"); rec({ "text", x - #s * 3.5, y, s, r, g, b, a })
    end
    function Element:drawTextureScaled(t, x, y, w, h, a) assert(t, "nil texture"); rec({ "tex", x, y, w, h, t, a }) end
    Element.drawTextureScaledAspect = Element.drawTextureScaled
    ISUIElement, ISPanel = Element, Element
    ISButton = Element:derive("ISButton")
    function ISButton:new(x, y, w, h, title) local o = Element.new(self, x, y, w, h); o.title = title; return o end
    getCore = function() return { getScreenWidth = function() return MockUI.screenW end,
                                  getScreenHeight = function() return MockUI.screenH end } end
    getTextManager = function() return { getFontHeight = function() return 16 end,
                                         MeasureStringX = function(_, _, s) return #s * 7 end } end
    UIFont = { Small = 1, Medium = 2, Large = 3 }
    Keyboard = { KEY_ESCAPE = 1 }
    Events = Events or {}
    Events.OnKeyPressed = Events.OnKeyPressed or { Add = noop }
    getTexture = function(path) return { path = path } end
    -- the window requires the vanilla UI files: they are these fakes
    for _, mod in ipairs({ "ISUI/ISPanel", "ISUI/ISButton", "ISUI/ISCollapsableWindow", "ISUI/ISScrollingListBox",
                           "TimedActions/ISBaseTimedAction" }) do
        package.preload[mod] = function() return true end
    end
end

-- ------------------------------------------------------------ PNG of the recorded calls
function MockUI.toPNG(path, Img)
    local im = Img.new(MockUI.screenW, MockUI.screenH)
    Img.fillRect(im, 0, 0, im.w, im.h, 60, 72, 58, 255)                   -- "the game" behind the overlay
    local MF, WF, PF = ZGB.ModelFactory, ZGB.WeaponFactory, ZGB.PartFactory
    local cache = {}
    local function silhouette(name)
        if cache[name] ~= nil then return cache[name] or nil end
        local id = name:match("Preview/([%w_]+)%.png$") or name
        local base = id:gsub("_nostock", ""):gsub("_nohandguard", "")
        local spec, part = WF.get(base), PF.get(base)
        local model = (spec and MF.gunModel(spec)) or (part and MF.partModel(part))
        cache[name] = model and Img.renderSide(model.prims, MF.MATERIALS, MF.bounds(model.prims), 300, 0, 1) or false
        return cache[name] or nil
    end
    local function c8(v) return math.floor(math.max(0, math.min(1, v or 1)) * 255 + 0.5) end
    for _, op in ipairs(MockUI.ops) do
        local k = op[1]
        if k == "rect" then
            Img.fillRect(im, op[2], op[3], op[2] + op[4], op[3] + op[5], c8(op[6]), c8(op[7]), c8(op[8]), c8(op[9]))
        elseif k == "border" then
            local x, y, w, h = op[2], op[3], op[4], op[5]
            local r, g, b, a = c8(op[6]), c8(op[7]), c8(op[8]), c8(op[9])
            Img.fillRect(im, x, y, x + w, y + 1, r, g, b, a); Img.fillRect(im, x, y + h - 1, x + w, y + h, r, g, b, a)
            Img.fillRect(im, x, y, x + 1, y + h, r, g, b, a); Img.fillRect(im, x + w - 1, y, x + w, y + h, r, g, b, a)
        elseif k == "line" then
            local x1, y1, x2, y2 = op[2], op[3], op[4], op[5]
            local n = math.max(1, math.floor(math.max(math.abs(x2 - x1), math.abs(y2 - y1))))
            for i = 0, n do
                Img.set(im, math.floor(x1 + (x2 - x1) * i / n), math.floor(y1 + (y2 - y1) * i / n), c8(op[6]), c8(op[7]), c8(op[8]), c8(op[9]))
            end
        elseif k == "text" then                                           -- text = a bar of its length
            Img.fillRect(im, op[2], op[3] + 4, op[2] + #op[4] * 7, op[3] + 12, c8(op[5]), c8(op[6]), c8(op[7]), math.floor(c8(op[8]) * 0.85))
        elseif k == "tex" then
            local sp = silhouette(op[6].path or "")
            local x, y, w, h = op[2], op[3], op[4], op[5]
            if sp then
                for py = 0, math.floor(h) - 1 do
                    for px = 0, math.floor(w) - 1 do
                        local sx, sy = math.floor(px * sp.w / w), math.floor(py * sp.h / h)
                        local i = (sy * sp.w + sx) * 4
                        if sp.px[i + 4] > 0 then Img.set(im, math.floor(x + px), math.floor(y + py), sp.px[i + 1], sp.px[i + 2], sp.px[i + 3], sp.px[i + 4]) end
                    end
                end
            else
                Img.fillRect(im, x, y, x + w, y + h, 150, 150, 160, 200)          -- item icon
            end
        end
    end
    Img.save(im, path)
end

return MockUI
