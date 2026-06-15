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

local function load(file)
    loadstring(game:HttpGet(BASE_URL .. file))()
end

load("part1.lua")
load("part2.lua")
load("part3.lua")

print("[BlairHub] Loaded")