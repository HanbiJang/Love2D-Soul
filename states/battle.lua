local utf8  = require("lib.utf8utils")
local bdata = require("data.battle")

local M = {}

local W, H       = 900, 600
local PAD        = 65
local TEXT_W     = W - PAD * 2
local CPS        = 20
local TIMER_MAX  = 3.0
local TIMER_R    = 22
local PLAYER_MAX = 3
local ENEMY_MAX  = 4

-- ── state ──────────────────────────────────────────────────
local phase      -- "flash"|"intro"|"setup"|"attack"|"result"|"victory"|"badend"|"ending"
local segs
local typer
local canInput
local time

local playerHP, enemyHP
local atkIdx     -- index into bdata.attacks (cycles on each hit/dodge)

local timerLeft
local timerGo

-- Simple sequential line queue: show lines one by one, call cb when all shown + advanced
local pending    -- list of {text, color, speed}
local afterAll   -- callback when pending exhausted and player advances

-- flash overlay
local fTimer, fText, fColor, fCallback

-- ── segment helpers ────────────────────────────────────────
local function makeSeg(text, color, speed)
    return {
        text  = text,
        shown = "",
        done  = false,
        timer = 0,
        len   = utf8.len(text),
        color = color or {0.88, 0.88, 0.88},
        speed = speed or 1.0,
        alpha = 1.0,
    }
end

local function pushSeg(text, color, speed)
    for _, s in ipairs(segs) do s.alpha = 0.35 end
    local seg = makeSeg(text, color, speed)
    seg.alpha = 1.0
    table.insert(segs, seg)
    typer    = seg
    canInput = false
end

-- ── flash ──────────────────────────────────────────────────
local function doFlash(txt, col, dur, cb)
    phase     = "flash"
    fText     = txt
    fColor    = col
    fTimer    = dur
    fCallback = cb
    canInput  = false
end

-- ── pending queue ──────────────────────────────────────────
local function showLines(lines, colors, cb)
    pending  = {}
    for i, ln in ipairs(lines) do
        pending[i] = { text = ln, color = colors and colors[i] or {0.88, 0.88, 0.88} }
    end
    afterAll = cb
end

local function advancePending()
    if #pending > 0 then
        local e = table.remove(pending, 1)
        pushSeg(e.text, e.color)
    else
        local cb = afterAll
        afterAll = nil
        if cb then cb() end
    end
end

-- ── attack flow ────────────────────────────────────────────
local function beginAttack(idx)
    atkIdx = idx
    phase  = "setup"
    local atk = bdata.attacks[atkIdx]
    showLines(
        atk.setup,
        nil,
        function()
            phase     = "attack"
            timerLeft = TIMER_MAX
            timerGo   = false
            pushSeg(atk.text, {0.95, 0.88, 0.70}, 0.85)
        end
    )
    advancePending()
end

local function nextAttack()
    beginAttack((atkIdx % #bdata.attacks) + 1)
end

local function onDodge()
    timerGo  = false
    enemyHP  = enemyHP - 1
    phase    = "result"
    local atk = bdata.attacks[atkIdx]

    if enemyHP <= 0 then
        showLines(
            { atk.dodge },
            { {0.60, 0.90, 0.60} },
            function()
                phase = "victory"
                local vcols = {}
                for i = 1, #bdata.victory do vcols[i] = {0.82, 0.82, 0.82} end
                showLines(bdata.victory, vcols, function()
                    doFlash("...", {0.50, 0.50, 0.50}, 2.0, function()
                        phase    = "ending"
                        canInput = true
                    end)
                end)
                advancePending()
            end
        )
    else
        showLines({ atk.dodge }, { {0.60, 0.90, 0.60} }, nextAttack)
    end
    advancePending()
end

local function onHit()
    timerGo  = false
    playerHP = playerHP - 1
    phase    = "result"
    local atk = bdata.attacks[atkIdx]

    if playerHP <= 0 then
        showLines(
            { atk.hit },
            { {0.90, 0.30, 0.30} },
            function()
                doFlash(
                    bdata.badend .. "\n\n\nBAD END",
                    {0.85, 0.08, 0.08},
                    4.5,
                    function()
                        phase    = "badend"
                        canInput = true
                    end
                )
            end
        )
    else
        showLines({ atk.hit }, { {0.90, 0.30, 0.30} }, nextAttack)
    end
    advancePending()
end

-- ── draw helpers ───────────────────────────────────────────
local function segLineCount(seg)
    local font = love.graphics.getFont()
    local text = #seg.shown > 0 and seg.shown or " "
    local _, lines = font:getWrap(text, TEXT_W)
    return math.max(1, #lines)
end

local function drawSeg(seg, x, y)
    local lh = love.graphics.getFont():getHeight() * 1.35
    love.graphics.setColor(seg.color[1], seg.color[2], seg.color[3], seg.alpha)
    love.graphics.printf(seg.shown, x, y, TEXT_W, "left")
    return segLineCount(seg) * lh
end

local function drawHP()
    for i = 1, PLAYER_MAX do
        local x = PAD + (i - 1) * 22
        if i <= playerHP then
            love.graphics.setColor(0.85, 0.22, 0.22)
            love.graphics.circle("fill", x, 32, 7)
        else
            love.graphics.setColor(0.25, 0.12, 0.12)
            love.graphics.circle("line", x, 32, 7)
        end
    end
    for i = 1, ENEMY_MAX do
        local x = W - PAD - (ENEMY_MAX - i) * 22
        if i <= enemyHP then
            love.graphics.setColor(0.55, 0.18, 0.55)
            love.graphics.circle("fill", x, 32, 7)
        else
            love.graphics.setColor(0.20, 0.12, 0.20)
            love.graphics.circle("line", x, 32, 7)
        end
    end
end

local function drawTimer()
    if phase ~= "attack" then return end
    local cx = W / 2
    local cy = H - 38
    local r  = TIMER_R

    love.graphics.setColor(0.08, 0.08, 0.10)
    love.graphics.circle("fill", cx, cy, r)

    if timerGo then
        local progress = (TIMER_MAX - timerLeft) / TIMER_MAX
        local t  = timerLeft / TIMER_MAX
        local rc = math.min(1.0, 0.30 + (1 - t) * 1.2)
        local gc = 0.55 * t * t
        love.graphics.setColor(rc, gc, 0.05)
        love.graphics.arc("fill", "pie", cx, cy, r,
            -math.pi / 2,
            -math.pi / 2 + progress * math.pi * 2)

        love.graphics.setColor(0.80, 0.80, 0.80)
        love.graphics.printf("SPACE", cx - 100, cy - 8, 200, "center")
    end

    love.graphics.setColor(0.30, 0.30, 0.35)
    love.graphics.circle("line", cx, cy, r)
end

-- ── public ─────────────────────────────────────────────────
function M.load()
    segs     = {}
    typer    = nil
    canInput = false
    time     = 0
    pending  = {}
    afterAll = nil

    playerHP  = PLAYER_MAX
    enemyHP   = ENEMY_MAX
    atkIdx    = #bdata.attacks  -- wraps to 1 on first nextAttack
    timerLeft = TIMER_MAX
    timerGo   = false

    phase = "intro"
    local icols = {}
    for i = 1, #bdata.intro do icols[i] = {0.78, 0.78, 0.78} end
    showLines(bdata.intro, icols, function()
        beginAttack(1)
    end)
    advancePending()
end

function M.update(dt)
    time = time + dt

    if phase == "flash" then
        fTimer = fTimer - dt
        if fTimer <= 0 and fCallback then
            local cb = fCallback; fCallback = nil; cb()
        end
        return
    end

    if typer and not typer.done then
        typer.timer = typer.timer + dt
        local n = math.min(math.floor(typer.timer * CPS * typer.speed), typer.len)
        typer.shown = utf8.sub(typer.text, n)
        if n >= typer.len then
            typer.done = true
            typer      = nil
            canInput   = true
            if phase == "attack" then timerGo = true end
        end
    end

    if phase == "attack" and timerGo then
        timerLeft = timerLeft - dt
        if timerLeft <= 0 then
            onHit()
        end
    end
end

function M.draw()
    love.graphics.clear(0.02, 0.02, 0.04)

    if phase == "flash" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(fColor[1], fColor[2], fColor[3])
        love.graphics.printf(fText, PAD, H / 2 - 60, TEXT_W, "center")
        return
    end

    if phase == "badend" then
        love.graphics.setColor(0.14, 0.02, 0.02)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(0.72, 0.08, 0.08)
        love.graphics.printf("BAD END", PAD, H / 2 - 20, TEXT_W, "center")
        love.graphics.setColor(0.38, 0.20, 0.20)
        love.graphics.printf("[ ESC ] 종료", PAD, H / 2 + 40, TEXT_W, "center")
        return
    end

    if phase == "ending" then
        love.graphics.setColor(0.02, 0.04, 0.02)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(0.35, 0.60, 0.35)
        love.graphics.printf("...", PAD, H / 2 - 20, TEXT_W, "center")
        love.graphics.setColor(0.20, 0.32, 0.20)
        love.graphics.printf("[ ESC ] 종료", PAD, H / 2 + 40, TEXT_W, "center")
        return
    end

    -- Header HP
    drawHP()
    love.graphics.setColor(0.10, 0.10, 0.12)
    love.graphics.line(PAD, 54, W - PAD, 54)

    -- Segments
    local font    = love.graphics.getFont()
    local lh      = font:getHeight() * 1.35
    local areaTop = 70
    local areaBot = H - 72
    love.graphics.setScissor(0, areaTop, W, areaBot - areaTop)

    local totalH = 0
    for _, seg in ipairs(segs) do
        totalH = totalH + segLineCount(seg) * lh + 16
    end
    local avail  = areaBot - areaTop
    local startY = areaTop
    if totalH > avail then startY = areaTop - (totalH - avail) end

    local y = startY
    for _, seg in ipairs(segs) do
        local h = drawSeg(seg, PAD, y)
        y = y + h + 16
    end
    love.graphics.setScissor()

    -- Bottom divider
    love.graphics.setColor(0.10, 0.10, 0.12)
    love.graphics.line(PAD, H - 66, W - PAD, H - 66)

    drawTimer()

    -- Advance arrow (non-attack phases)
    local showArrow = canInput and
        (phase == "intro" or phase == "setup" or
         phase == "result" or phase == "victory")
    if showArrow then
        love.graphics.setColor(0.22, 0.22, 0.22)
        love.graphics.printf("→", PAD, H - 50, TEXT_W, "center")
    end
end

function M.keypressed(key)
    if key == "escape" then
        if phase == "badend" or phase == "ending" then love.event.quit() end
        return
    end

    if not canInput then return end

    if phase == "attack" and key == "space" then
        onDodge()
        return
    end

    if key == "right" or key == "space" or key == "return" then
        if phase == "intro" or phase == "setup" or
           phase == "result" or phase == "victory" then
            advancePending()
        end
    end
end

return M
