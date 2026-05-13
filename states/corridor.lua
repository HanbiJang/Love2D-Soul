local utf8       = require("lib.utf8utils")
local texts      = require("data.texts")
local anomDefs   = require("data.anomalies")

local M = {}

local W, H    = 900, 600
local PAD     = 65
local TEXT_W  = W - PAD * 2
local CPS     = 20   -- base chars per second (typewriter)

-- ── state ──────────────────────────────────────────────────
local loop, step
local segs          -- list of segments shown on screen
local typer         -- segment currently being typed (ref into segs)
local canInput
local phase         -- "walk" | "choose" | "flash"
local time

-- flash overlay
local fTimer, fText, fColor, fCallback

-- anomaly
local hasAnom, aType, aStep

-- ── UTF-8 aware character-by-character draw ────────────────
local function iterChars(s, fn)
    local i, ci = 1, 0
    while i <= #s do
        local cl = utf8.clen(s:byte(i))
        fn(s:sub(i, i + cl - 1), ci)
        i = i + cl; ci = ci + 1
    end
end

-- ── segment ────────────────────────────────────────────────
local function makeSeg(text, color, vibrate, speed)
    return {
        text    = text,
        shown   = "",
        done    = false,
        timer   = 0,
        len     = utf8.len(text),
        color   = color   or {0.88, 0.88, 0.88},
        vibrate = vibrate or false,
        speed   = speed   or 1.0,
        alpha   = 1.0,
    }
end

local function pushSeg(seg)
    for _, s in ipairs(segs) do s.alpha = 0.35 end
    seg.alpha = 1.0
    table.insert(segs, seg)
    typer    = seg
    canInput = false
end

-- ── anomaly ────────────────────────────────────────────────
local function rollAnom()
    if math.random() < 0.65 then
        hasAnom = true
        aType   = anomDefs[math.random(#anomDefs)]
        aStep   = math.random(2, 5)
    else
        hasAnom, aType, aStep = false, nil, nil
    end
end

local function stepText(s)
    local pool = texts[s]
    local base = pool[math.random(#pool)]
    if hasAnom and s == aStep then
        return aType.apply(base), aType.color, aType.vibrate, aType.speed
    end
    return base, {0.88, 0.88, 0.88}, false, 1.0
end

-- ── flash ──────────────────────────────────────────────────
local function flash(txt, col, dur, cb)
    phase     = "flash"
    fText     = txt
    fColor    = col
    fTimer    = dur
    fCallback = cb
    canInput  = false
end

-- ── loop control ───────────────────────────────────────────
local onBoss

local function startLoop()
    step     = 0
    segs     = {}
    typer    = nil
    phase    = "walk"
    canInput = true
    rollAnom()
end

local function advance()
    loop = loop + 1
    if loop > 8 then
        flash("...\n\n\n그가 기다리고 있다.", {0.72, 0.05, 0.05}, 3.5, onBoss)
    else
        flash(string.format("루프  %d", loop), {0.28, 0.28, 0.28}, 1.0, startLoop)
    end
end

local function resetGame()
    flash("...\n\n다시.", {0.55, 0.05, 0.05}, 1.8, function()
        loop = 1
        startLoop()
    end)
end

local function resolve(wentForward)
    local correct = (hasAnom and not wentForward) or (not hasAnom and wentForward)
    if correct then advance() else resetGame() end
end

-- ── drawing helpers ────────────────────────────────────────
local function segLineCount(seg)
    local font = love.graphics.getFont()
    local text = #seg.shown > 0 and seg.shown or " "
    local _, lines = font:getWrap(text, TEXT_W)
    return math.max(1, #lines)
end

local function drawSeg(seg, x, y)
    local font = love.graphics.getFont()
    local lh   = font:getHeight() * 1.35
    local r, g, b = seg.color[1], seg.color[2], seg.color[3]
    local a       = seg.alpha

    if not seg.vibrate then
        love.graphics.setColor(r, g, b, a)
        love.graphics.printf(seg.shown, x, y, TEXT_W, "left")
    else
        local xo, yo = 0, 0
        iterChars(seg.shown, function(ch, ci)
            if ch == "\n" then
                yo = yo + lh; xo = 0
            else
                local vy = math.sin(time * 9 + ci * 0.75) * 2.8
                love.graphics.setColor(r, g, b, a)
                love.graphics.print(ch, x + xo, y + yo + vy)
                xo = xo + font:getWidth(ch)
            end
        end)
    end

    return segLineCount(seg) * lh
end

-- ── public ─────────────────────────────────────────────────
function M.load(bossCb)
    onBoss = bossCb
    math.randomseed(os.time())
    loop = 1
    time = 0
    startLoop()
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
        local n = math.min(
            math.floor(typer.timer * CPS * typer.speed),
            typer.len
        )
        typer.shown = utf8.sub(typer.text, n)
        if n >= typer.len then
            typer.done = true
            typer      = nil
            canInput   = true
            if phase == "walk" and step == 6 then
                phase = "choose"
            end
        end
    end
end

function M.draw()
    love.graphics.clear(0.02, 0.02, 0.04)

    -- ── flash overlay ──
    if phase == "flash" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(fColor[1], fColor[2], fColor[3])
        love.graphics.printf(fText, PAD, H / 2 - 40, TEXT_W, "center")
        return
    end

    local font = love.graphics.getFont()
    local lh   = font:getHeight() * 1.35

    -- ── header ──
    love.graphics.setColor(0.30, 0.30, 0.30)
    love.graphics.printf(string.format("루프  %d / 8", loop), PAD, 20, TEXT_W, "center")
    love.graphics.setColor(0.10, 0.10, 0.12)
    love.graphics.line(PAD, 54, W - PAD, 54)

    -- ── segments (with scroll clipping) ──
    local areaTop = 70
    local areaBot = H - 72
    love.graphics.setScissor(0, areaTop, W, areaBot - areaTop)

    -- compute total height to scroll if needed
    local totalH = 0
    for _, seg in ipairs(segs) do
        totalH = totalH + segLineCount(seg) * lh + 16
    end
    local avail   = areaBot - areaTop
    local startY  = areaTop
    if totalH > avail then startY = areaTop - (totalH - avail) end

    local y = startY
    for _, seg in ipairs(segs) do
        local h = drawSeg(seg, PAD, y)
        y = y + h + 16
    end

    love.graphics.setScissor()

    -- ── step dots ──
    local dotY  = H - 28
    local dw    = 6 * 24
    local dx    = W / 2 - dw / 2
    for i = 1, 6 do
        if i <= step then
            love.graphics.setColor(0.58, 0.58, 0.58)
            love.graphics.circle("fill", dx + (i - 1) * 24, dotY, 4)
        else
            love.graphics.setColor(0.14, 0.14, 0.14)
            love.graphics.circle("line", dx + (i - 1) * 24, dotY, 4)
        end
    end

    -- ── bottom prompt ──
    love.graphics.setColor(0.10, 0.10, 0.12)
    love.graphics.line(PAD, H - 66, W - PAD, H - 66)

    if phase == "choose" and canInput then
        love.graphics.setColor(0.60, 0.60, 0.60)
        love.graphics.printf("← 돌아가기", PAD, H - 50, TEXT_W / 2, "center")
        love.graphics.printf("앞으로 →",   PAD + TEXT_W / 2, H - 50, TEXT_W / 2, "center")
    elseif phase == "walk" and canInput and step < 6 then
        love.graphics.setColor(0.20, 0.20, 0.20)
        love.graphics.printf("→", PAD, H - 50, TEXT_W, "center")
    end
end

function M.keypressed(key)
    if key == "escape" then love.event.quit(); return end
    if not canInput then return end

    if phase == "choose" then
        if     key == "right" then resolve(true)
        elseif key == "left"  then resolve(false) end
        return
    end

    if phase == "walk" and key == "right" and step < 6 then
        step = step + 1
        local t, c, v, s = stepText(step)
        pushSeg(makeSeg(t, c, v, s))
    end
end

return M
