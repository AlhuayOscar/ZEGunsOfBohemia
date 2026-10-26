--[[
    Indexes the names the INSTALLED game knows, so validate_mod.lua can catch a
    wrong game-API name (`item:setRecoilDelai(...)`) without starting the game:

        lua5.1 tools/gen_pz_api.lua            (once per game update; ~1 min)

    Reads every zombie/* class in projectzomboid.jar (method and field names from
    the constant pool) and every function defined in the game's own media/lua.
    Writes .cache/pz_api/names.txt (one name per line) and .cache/pz_api/build.txt.
    Game folder: PZ_DIR or the default Steam path. Needs tar (Windows 10+ has it).
]]
local PZ = os.getenv("PZ_DIR") or "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"
local OUT = ".cache/pz_api/"
local isWindows = package.config:sub(1, 1) == "\\"
local function sh(cmd) local p = io.popen(cmd); local s = p:read("*a"); p:close(); return s end
local function read(path) local f = io.open(path, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

local jar = PZ .. "/projectzomboid.jar"
do local f = io.open(jar, "rb"); assert(f, "game not found at " .. PZ .. " (set PZ_DIR)"); f:close() end
local classes = OUT .. "classes"
if isWindows then
    os.execute('mkdir "' .. classes:gsub("/", "\\") .. '" 2>NUL')
    os.execute('C:\\Windows\\System32\\tar.exe -xf "' .. jar .. '" -C "' .. classes .. '" zombie org/joml')  -- joml: vectors (getOffset)
else
    os.execute('mkdir -p "' .. classes .. '" && cd "' .. classes .. '" && unzip -qo "' .. jar .. '" "zombie/*" "org/joml/*"')
end

local names, n = {}, 0
local function add(s) if not names[s] then names[s] = true; n = n + 1 end end
local files = sh(isWindows and ('dir /b /s "' .. classes:gsub("/", "\\") .. '\\*.class"') or ('find "' .. classes .. '" -name "*.class"'))
local nClasses = 0
for path in files:gmatch("[^\r\n]+") do
    local data = read(path)
    if data then
        nClasses = nClasses + 1
        for id in data:gmatch("[%a_][%w_]*") do if #id <= 60 then add(id) end end   -- 1-char too: Vector3f:x()
    end
end
-- vanilla Lua: globals and methods it defines (ISPanel:initialise, ...)
local luaFiles = sh(isWindows and ('dir /b /s "' .. (PZ .. "/media/lua"):gsub("/", "\\") .. '\\*.lua"') or ('find "' .. PZ .. '/media/lua" -name "*.lua"'))
for path in luaFiles:gmatch("[^\r\n]+") do
    local code = read(path) or ""
    for id in code:gmatch("function%s+[%w_%.:]-([%a_][%w_]*)%s*%(") do add(id) end
    for id in code:gmatch("[%.:]([%a_][%w_]*)%s*=%s*function") do add(id) end
end

local list = {}
for k in pairs(names) do list[#list + 1] = k end
table.sort(list)
local f = assert(io.open(OUT .. "names.txt", "wb")); f:write(table.concat(list, "\n"), "\n"); f:close()
local build = sh(isWindows and ('dir /b "' .. PZ:gsub("/", "\\") .. '"') or ('ls "' .. PZ .. '"')):match("(%d+%.%d+%.%d+)") or "?"
f = assert(io.open(OUT .. "build.txt", "wb")); f:write(build, "\n"); f:close()
print(string.format("indexed %d names from %d classes + vanilla Lua (build %s) -> %snames.txt", n, nClasses, build, OUT))
