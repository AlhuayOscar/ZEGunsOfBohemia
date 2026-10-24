--[[
    zgb_image.lua  —  tiny RGBA image + PNG writer + side-view rasterizer for
    the placeholder model prims (used by tools/gen_models.lua).

    PNG output is uncompressed (zlib "stored" blocks): bigger files, zero
    dependencies. Uses LuaJIT's `bit` (or Lua 5.2 `bit32`) when available.
]]
local Img = {}

-- ---------------------------------------------------------------- bit ops
local bxor, band, rshift
local okBit, bitlib = pcall(require, "bit")
if okBit then bxor, band, rshift = bitlib.bxor, bitlib.band, bitlib.rshift
elseif bit32 then bxor, band, rshift = bit32.bxor, bit32.band, bit32.rshift
else
    local function op(a, b, f)
        local r, p = 0, 1
        for _ = 1, 32 do
            local x, y = a % 2, b % 2
            if f(x, y) then r = r + p end
            a, b, p = (a - x) / 2, (b - y) / 2, p * 2
        end
        return r
    end
    bxor = function(a, b) return op(a, b, function(x, y) return x ~= y end) end
    band = function(a, b) return op(a, b, function(x, y) return x == 1 and y == 1 end) end
    rshift = function(a, n) return math.floor(a / 2 ^ n) end
end

local CRC = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if band(c, 1) == 1 then c = bxor(0xEDB88320, rshift(c, 1)) else c = rshift(c, 1) end
    end
    CRC[i] = c
end
local function crc32(s, crc)
    crc = bxor(crc or 0, 0xFFFFFFFF)
    for i = 1, #s do crc = bxor(CRC[band(bxor(crc, s:byte(i)), 0xFF)], rshift(crc, 8)) end
    crc = bxor(crc, 0xFFFFFFFF)
    if crc < 0 then crc = crc + 4294967296 end
    return crc
end
local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end

-- ---------------------------------------------------------------- image
function Img.new(w, h)
    local px = {}
    for i = 1, w * h * 4 do px[i] = 0 end
    return { w = w, h = h, px = px }
end

function Img.set(im, x, y, r, g, b, a)
    if x < 0 or y < 0 or x >= im.w or y >= im.h then return end
    local i = (y * im.w + x) * 4
    local p = im.px
    local sa = (a or 255) / 255
    local da = p[i + 4] / 255
    local oa = sa + da * (1 - sa)
    if oa <= 0 then return end
    p[i + 1] = math.floor((r * sa + p[i + 1] * da * (1 - sa)) / oa + 0.5)
    p[i + 2] = math.floor((g * sa + p[i + 2] * da * (1 - sa)) / oa + 0.5)
    p[i + 3] = math.floor((b * sa + p[i + 3] * da * (1 - sa)) / oa + 0.5)
    p[i + 4] = math.floor(oa * 255 + 0.5)
end

function Img.fillRect(im, x0, y0, x1, y1, r, g, b, a)
    for y = math.max(0, math.floor(y0)), math.min(im.h - 1, math.ceil(y1) - 1) do
        for x = math.max(0, math.floor(x0)), math.min(im.w - 1, math.ceil(x1) - 1) do
            Img.set(im, x, y, r, g, b, a)
        end
    end
end

--- Box-filter downscale by an integer factor (for anti-aliasing).
function Img.downscale(im, f)
    local out = Img.new(math.floor(im.w / f), math.floor(im.h / f))
    for y = 0, out.h - 1 do
        for x = 0, out.w - 1 do
            local acc = { 0, 0, 0, 0 }
            for dy = 0, f - 1 do
                for dx = 0, f - 1 do
                    local i = ((y * f + dy) * im.w + (x * f + dx)) * 4
                    local a = im.px[i + 4]
                    acc[1] = acc[1] + im.px[i + 1] * a; acc[2] = acc[2] + im.px[i + 2] * a
                    acc[3] = acc[3] + im.px[i + 3] * a; acc[4] = acc[4] + a
                end
            end
            local o = (y * out.w + x) * 4
            if acc[4] > 0 then
                out.px[o + 1] = math.floor(acc[1] / acc[4] + 0.5); out.px[o + 2] = math.floor(acc[2] / acc[4] + 0.5)
                out.px[o + 3] = math.floor(acc[3] / acc[4] + 0.5); out.px[o + 4] = math.floor(acc[4] / (f * f) + 0.5)
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------- deflate (fixed Huffman + LZ77)
local LEN_BASE  = { 3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258 }
local LEN_EXTRA = { 0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0 }
local DIST_BASE = { 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577 }
local DIST_EXTRA= { 0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13 }

--- Raw deflate stream (one final block, fixed Huffman codes).
function Img.deflate(s)
    local out, acc, nacc = {}, 0, 0
    local function bits(v, n)                    -- LSB first
        for _ = 1, n do
            if v % 2 == 1 then acc = acc + 2 ^ nacc end
            v = math.floor(v / 2)
            nacc = nacc + 1
            if nacc == 8 then out[#out + 1] = string.char(acc); acc, nacc = 0, 0 end
        end
    end
    local function huff(code, n)                 -- Huffman codes go MSB first
        for i = n - 1, 0, -1 do bits(math.floor(code / 2 ^ i) % 2, 1) end
    end
    local function lit(v)
        if v < 144 then huff(48 + v, 8)
        elseif v < 256 then huff(400 + v - 144, 9)
        elseif v < 280 then huff(v - 256, 7)
        else huff(192 + v - 280, 8) end
    end
    local function match(len, dist)
        local i = #LEN_BASE
        while LEN_BASE[i] > len do i = i - 1 end
        lit(256 + i); bits(len - LEN_BASE[i], LEN_EXTRA[i])
        local d = #DIST_BASE
        while DIST_BASE[d] > dist do d = d - 1 end
        huff(d - 1, 5); bits(dist - DIST_BASE[d], DIST_EXTRA[d])
    end
    bits(1, 1); bits(1, 2)                        -- final block, fixed Huffman
    local n, head, i = #s, {}, 1
    while i <= n do
        local best, bestDist = 0, 0
        if i + 2 <= n then
            local key = s:sub(i, i + 2)
            local cand = head[key]
            if cand and i - cand <= 32768 then
                local l = 0
                while l < 258 and i + l <= n and s:byte(cand + l) == s:byte(i + l) do l = l + 1 end
                if l >= 3 then best, bestDist = l, i - cand end
            end
            head[key] = i
        end
        if best >= 3 then
            match(best, bestDist)
            for k = i + 1, math.min(i + best - 1, n - 2) do head[s:sub(k, k + 2)] = k end
            i = i + best
        else
            lit(s:byte(i)); i = i + 1
        end
    end
    lit(256)
    if nacc > 0 then out[#out + 1] = string.char(acc) end
    return table.concat(out)
end

local function clamp8(v)
    if v ~= v then return 0 end                -- NaN
    v = math.floor(v + 0.5)
    if v < 0 then return 0 elseif v > 255 then return 255 end
    return v
end

function Img.png(im)
    local rows = {}
    for y = 0, im.h - 1 do
        local row = { "\0" }
        for x = 0, im.w - 1 do
            local i = (y * im.w + x) * 4
            row[#row + 1] = string.char(clamp8(im.px[i + 1]), clamp8(im.px[i + 2]), clamp8(im.px[i + 3]), clamp8(im.px[i + 4]))
        end
        rows[#rows + 1] = table.concat(row)
    end
    local raw = table.concat(rows)
    local z, a1, a2 = { "\120\1", Img.deflate(raw) }, 1, 0
    for i = 1, #raw do a1 = (a1 + raw:byte(i)) % 65521; a2 = (a2 + a1) % 65521 end
    z[#z + 1] = u32(a2 * 65536 + a1)
    local function chunk(kind, data) return u32(#data) .. kind .. data .. u32(crc32(kind .. data)) end
    return "\137PNG\r\n\26\n"
        .. chunk("IHDR", u32(im.w) .. u32(im.h) .. "\8\6\0\0\0")
        .. chunk("IDAT", table.concat(z))
        .. chunk("IEND", "")
end

function Img.save(im, path)
    local f = assert(io.open(path, "wb"))
    f:write(Img.png(im)); f:close()
end

-- ---------------------------------------------------------------- side-view rasterizer
--[[ Draw prims seen from the right (x right, y up, z towards the viewer).
     materials: name -> { rgb = {r,g,b} 0-1 }.  bounds: { min, max }.
     ppm = pixels per metre; pad = margin in pixels; ss = supersampling. ]]
function Img.renderSide(prims, materials, bounds, ppm, pad, ss, w, h)
    ss = ss or 2
    local W = w or math.max(1, math.ceil((bounds.max[1] - bounds.min[1]) * ppm + pad * 2))
    local H = h or math.max(1, math.ceil((bounds.max[2] - bounds.min[2]) * ppm + pad * 2))
    local im = Img.new(W * ss, H * ss)
    local function px(x) return (x - bounds.min[1]) * ppm * ss + pad * ss end
    local function py(y) return (bounds.max[2] - y) * ppm * ss + pad * ss end
    local order = {}
    for i, p in ipairs(prims) do
        local zmax = p.t == "box" and p.b[3] or (p.c[3] + (p.axis == "z" and p.len or p.r))
        order[#order + 1] = { p = p, z = zmax, i = i }
    end
    table.sort(order, function(a, b) if a.z ~= b.z then return a.z < b.z end return a.i < b.i end)
    for _, o in ipairs(order) do
        local p = o.p
        local c = (materials[p.m] or materials.steel).rgb
        local r, g, b = c[1] * 255, c[2] * 255, c[3] * 255
        local x0, y0, x1, y1
        if p.t == "box" then
            x0, x1, y0, y1 = px(p.a[1]), px(p.b[1]), py(p.b[2]), py(p.a[2])
        elseif p.axis == "x" then
            x0, x1, y0, y1 = px(p.c[1]), px(p.c[1] + p.len), py(p.c[2] + p.r), py(p.c[2] - p.r)
        elseif p.axis == "y" then
            x0, x1, y0, y1 = px(p.c[1] - p.r), px(p.c[1] + p.r), py(p.c[2] + p.len), py(p.c[2])
        end
        if x0 then
            if x1 - x0 < ss then x1 = x0 + ss end
            if y1 - y0 < ss then y1 = y0 + ss end
            -- outline, then a body lit from above
            Img.fillRect(im, x0, y0, x1, y1, r * 0.45, g * 0.45, b * 0.45, 255)
            local hgt = math.max(1, y1 - y0 - 2 * ss)
            for yy = math.floor(y0 + ss), math.ceil(y1 - ss) - 1 do
                local t = (yy - y0) / hgt
                local k = 1.25 - 0.5 * t
                Img.fillRect(im, x0 + ss, yy, x1 - ss, yy + 1, math.min(255, r * k), math.min(255, g * k), math.min(255, b * k), 255)
            end
        else -- cylinder seen end-on (axis z): a disc
            local cx, cy, rr = px(p.c[1]), py(p.c[2]), p.r * ppm * ss
            for yy = math.floor(cy - rr), math.ceil(cy + rr) do
                for xx = math.floor(cx - rr), math.ceil(cx + rr) do
                    local d = math.sqrt((xx - cx) ^ 2 + (yy - cy) ^ 2)
                    if d <= rr then
                        local k = d > rr - ss and 0.45 or (1.15 - 0.3 * (yy - (cy - rr)) / (2 * rr))
                        Img.set(im, xx, yy, math.min(255, r * k), math.min(255, g * k), math.min(255, b * k), 255)
                    end
                end
            end
        end
    end
    return Img.downscale(im, ss), W, H
end

return Img
