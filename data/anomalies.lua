local utf8 = require("lib.utf8utils")

local yandere_lines = {
    "\n...보고 있어.",
    "\n...어디 가려고.",
    "\n...네 발소리가 들려.",
    "\n...기다렸어.",
    "\n...왜 도망가는 거야.",
    "\n...혼자 가지 마.",
}

local M = {}

-- 1. 문자 변형: 텍스트 중간에 'ㅎ' 삽입
M[1] = {
    color   = {0.88, 0.88, 0.88},
    vibrate = false,
    speed   = 1.0,
    apply   = function(text)
        local len = utf8.len(text)
        if len < 4 then return text .. "ㅎ" end
        local pos    = math.random(2, len - 1)
        local before = utf8.sub(text, pos)
        local after  = text:sub(#before + 1)
        return before .. "ㅎ" .. after
    end,
}

-- 2. 문장 삽입: 얀데레 메시지가 끼어듦
M[2] = {
    color   = {0.75, 0.12, 0.12},
    vibrate = false,
    speed   = 0.85,
    apply   = function(text)
        return text .. yandere_lines[math.random(#yandere_lines)]
    end,
}

-- 3. 문장 누락: 불안한 침묵
M[3] = {
    color   = {0.30, 0.30, 0.30},
    vibrate = false,
    speed   = 0.12,
    apply   = function(_)
        return "....."
    end,
}

-- 4. 색 변화: 텍스트가 붉게 변함
M[4] = {
    color   = {0.82, 0.08, 0.08},
    vibrate = false,
    speed   = 1.0,
    apply   = function(text)
        return text
    end,
}

-- 5. 진동: 글자가 떨림
M[5] = {
    color   = {0.88, 0.88, 0.88},
    vibrate = true,
    speed   = 1.0,
    apply   = function(text)
        return text
    end,
}

return M
