local M = {}

local function clen(b)
    if b < 0x80 then return 1
    elseif b < 0xE0 then return 2
    elseif b < 0xF0 then return 3
    else return 4 end
end

function M.clen(b) return clen(b) end

function M.len(s)
    local n, i = 0, 1
    while i <= #s do i = i + clen(s:byte(i)); n = n + 1 end
    return n
end

-- first n UTF-8 characters of s
function M.sub(s, n)
    if n <= 0 then return "" end
    local i, count = 1, 0
    while i <= #s do
        local cl = clen(s:byte(i))
        count = count + 1
        if count >= n then return s:sub(1, i + cl - 1) end
        i = i + cl
    end
    return s
end

return M
