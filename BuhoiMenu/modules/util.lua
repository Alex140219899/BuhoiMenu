local encoding = require('encoding')
local ffi = require('ffi')

encoding.default = 'UTF-8'
local u8 = encoding.UTF8

local M = { u8 = u8, ffi = ffi }

function M.chat_add_utf8(msg, color)
    local text = tostring(msg or '')
    local prev = encoding.default
    encoding.default = 'CP1251'
    local ok, decoded = pcall(function() return encoding.UTF8:decode(text) end)
    encoding.default = prev
    sampAddChatMessage(ok and decoded or text, color or 0x66CCFF)
end

function M.file_exists(path)
    if type(doesFileExist) == 'function' then
        return doesFileExist(path)
    end
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
end

function M.copy_file(src, dst)
    local r = io.open(src, 'rb')
    if not r then return false end
    local body = r:read('*a')
    r:close()
    local w = io.open(dst, 'wb')
    if not w then return false end
    w:write(body or '')
    w:close()
    return true
end

function M.version_trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

function M.version_to_parts(v)
    local parts = {}
    for n in tostring(v or ''):gmatch('%d+') do
        parts[#parts + 1] = tonumber(n) or 0
    end
    return parts
end

function M.compare_versions(a, b)
    local pa, pb = M.version_to_parts(a), M.version_to_parts(b)
    local n = math.max(#pa, #pb)
    for i = 1, n do
        local va, vb = pa[i] or 0, pb[i] or 0
        if va ~= vb then return va > vb and 1 or -1 end
    end
    return 0
end

function M.read_script_version_from_path(path)
    local f = io.open(path or '', 'rb')
    if not f then return nil end
    local head = f:read(65536) or ''
    f:close()
    local v = head:match("script_version%s*%(%s*['\"]([^'\"]+)['\"]%s*%)")
    if v and v ~= '' then return M.version_trim(v) end
    return nil
end

function M.get_local_script_version()
    local ts = thisScript and thisScript()
    if ts and ts.path then
        local from_disk = M.read_script_version_from_path(ts.path)
        if from_disk then return from_disk end
    end
    if ts and ts.version and tostring(ts.version) ~= '' then
        return M.version_trim(ts.version)
    end
    return 'unknown'
end

function M.as_clock(sec)
    if sec < 0 then sec = 0 end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format('%02d:%02d:%02d', h, m, s)
end

function M.get_weekday_index()
    local w = tonumber(os.date('%w'))
    return (w == 0) and 7 or w
end

function M.pick_mode(current, target)
    if current ~= target then return target end
    return 0
end

function M.is_monet_loader()
    return MONET_VERSION ~= nil
end

function M.url_cache_bust(base)
    local sep = base:find('?', 1, true) and '&' or '?'
    return base .. sep .. 't=' .. tostring(os.time())
end

return M
