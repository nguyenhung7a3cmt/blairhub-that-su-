-- BlairHub GitHub Loader

_G.BlairHub = false
task.wait(1.5)
_G.BlairHub = true

pcall(function()
    local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("BlairHubUI")
    if old then old:Destroy() end
end)

local BASE_URL = "https://raw.githubusercontent.com/nguyenhung7a3cmt/blairhub-that-su-/master/Desktop/blairscriptgithub/BlairHub/"
local _v = tostring(os.time()):sub(-4)

local function load(file, arg)
    local url = BASE_URL .. file .. "?v=" .. _v
    local okSrc, src = pcall(game.HttpGet, game, url)
    assert(okSrc and type(src) == "string" and src ~= "", "HttpGet failed: " .. file .. " | " .. tostring(src))

    local fn, compileErr = loadstring(src)
    assert(fn, "loadstring failed: " .. file .. " | " .. tostring(compileErr))

    local okRun, result = pcall(fn, arg)
    assert(okRun, "runtime failed: " .. file .. " | " .. tostring(result))
    assert(result ~= nil, "chunk returned nil: " .. file)
    return result
end

local S = load("part1.lua")
S = load("part2.lua", S)
S = load("part3.lua", S)

print("[BlairHub] Loaded")