local Intro    = require("states.intro")
local Corridor = require("states.corridor")

local current

local function switchTo(state)
    current = state
end

local function loadKoreanFont(size)
    local paths = {
        "C:/Windows/Fonts/malgun.ttf",
        "C:/Windows/Fonts/gulim.ttc",
    }
    for _, path in ipairs(paths) do
        local f = io.open(path, "rb")
        if f then
            local data = f:read("*a")
            f:close()
            local fd = love.filesystem.newFileData(data, "font.ttf")
            local ok, font = pcall(love.graphics.newFont, fd, size)
            if ok then return font end
        end
    end
    return love.graphics.newFont(size)
end

function love.load()
    love.graphics.setFont(loadKoreanFont(20))

    Intro.load(function()
        Corridor.load()
        switchTo(Corridor)
    end)
    switchTo(Intro)
end

function love.update(dt)    current.update(dt)    end
function love.draw()        current.draw()        end
function love.keypressed(k) current.keypressed(k) end
