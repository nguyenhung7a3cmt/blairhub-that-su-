-- BlairHub GitHub Loader
-- 3-chunk split, shared table S

_G.BlairHub = false
task.wait(1.5)
_G.BlairHub = true

pcall(function()
    local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("BlairHubUI")
    if old then old:Destroy() end
end)

local BASE_URL = "https://raw.githubusercontent.com/nguyenhung7a3cmt/blairhub-that-su-/master/Desktop/blairscriptgithub/BlairHub/"
local function load(file, shared)
    return loadstring(game:HttpGet(BASE_URL .. file))(shared)
end

local S = {}
S = load("part1.lua", S)
S = load("part2.lua", S)
S = load("part3.lua", S)

print("[BlairHub] Split loader loaded")
