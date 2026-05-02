local M = {}

local W, H = 900, 600

--[[
  실루엣 형태 (각 줄을 픽셀 너비 기준으로 화면 중앙 정렬)

       ██████████         ← 머리 위
      ████████████        ← 머리
    ██████████████████    ← 머리 + 귀 (가장 넓은 머리)
      ████████████        ← 머리 아래
        ████████          ← 턱
         ██████           ← 목 위
          ████            ← 목 (가장 좁음)
  ████████████████████████ ← 어깨 (가장 넓음)
  ████████████████████████ ← 가슴
]]
local ART = {
    "그그그그그그그그그그",
    "그그그그그그그그그그그그",
    "그그그그그그그그그그그그그그그그그그",
    "그그그그그그그그그그그그",
    "그그그그그그그그그그",
    "그그그그그그그그",
    "그그그그그그",
    "그그그그그그그그그그그그그그그그그그그그그그그그그그그그그그",
    "그그그그그그그그그그그그그그그그그그그그그그그그그그그그그그",
}

local DIALOG = {
    { text = "...",               delay = 1.5 },
    { text = "...찾았어.",        delay = 1.8 },
    { text = "오래 기다렸어.",    delay = 1.6 },
    { text = "이제 어디도 못 가.", delay = 99  },
}

local ART_INTERVAL = 0.20
local ART_PAUSE    = 1.0

local time
local artIndex, artShown, artTimer
local dlgIndex, dlgShown, dlgTimer
local phase
local canProceed
local onDone

function M.load(callback)
    time       = 0
    artIndex   = 0
    artShown   = {}
    artTimer   = ART_INTERVAL
    dlgIndex   = 0
    dlgShown   = {}
    dlgTimer   = 0
    phase      = "art"
    canProceed = false
    onDone     = callback
end

function M.update(dt)
    time = time + dt

    if phase == "art" then
        artTimer = artTimer - dt
        if artTimer <= 0 then
            artIndex = artIndex + 1
            table.insert(artShown, ART[artIndex])
            if artIndex >= #ART then
                phase    = "dialog"
                dlgTimer = ART_PAUSE
            else
                artTimer = ART_INTERVAL
            end
        end

    elseif phase == "dialog" then
        dlgTimer = dlgTimer - dt
        if dlgTimer <= 0 then
            dlgIndex = dlgIndex + 1
            local entry = DIALOG[dlgIndex]
            table.insert(dlgShown, entry.text)
            if dlgIndex >= #DIALOG then
                phase      = "wait"
                canProceed = true
            else
                dlgTimer = entry.delay
            end
        end
    end
end

function M.draw()
    love.graphics.clear(0, 0, 0)

    local font = love.graphics.getFont()
    local lh   = font:getHeight() * 1.45

    local artBlockH = #ART    * lh
    local dlgBlockH = #DIALOG * lh * 1.3
    local totalH    = artBlockH + 48 + dlgBlockH
    local startY    = H / 2 - totalH / 2

    -- 아트: 각 줄을 픽셀 너비 기준으로 중앙 정렬
    for i, line in ipairs(artShown) do
        local lineW = font:getWidth(line)
        local x     = W / 2 - lineW / 2
        local y     = startY + (i - 1) * lh

        -- 위쪽 줄(머리)은 밝게, 아래쪽(어깨)은 조금 더 밝게
        local t = i / #ART
        local v = 0.38 + 0.52 * t
        love.graphics.setColor(v, v, v)
        love.graphics.print(line, x, y)
    end

    -- 대사
    local dlgY = startY + artBlockH + 48
    for i, line in ipairs(dlgShown) do
        if i == #dlgShown then
            love.graphics.setColor(0.82, 0.10, 0.10)
        else
            love.graphics.setColor(0.42, 0.05, 0.05)
        end
        love.graphics.printf(line, 0, dlgY + (i - 1) * lh * 1.3, W, "center")
    end

    -- 진행 안내 깜빡임
    if canProceed and math.sin(time * 2.5) > 0 then
        love.graphics.setColor(0.18, 0.18, 0.18)
        love.graphics.printf("[ 아무 키나 ]", 0, H - 48, W, "center")
    end
end

function M.keypressed(_)
    if canProceed and onDone then
        onDone()
    end
end

return M
