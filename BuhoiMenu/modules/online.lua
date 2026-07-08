local config = require('config')
local util = require('util')

local M = {}

M.online = {
    session_online = 0, session_full = 0, session_afk = 0,
    day_online = 0, day_full = 0, day_afk = 0,
    week_online = 0, week_full = 0, week_afk = 0,
    week_days_full = { [1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0 },
    week_days_online = { [1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0 },
    week_days_afk = { [1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0 },
    start_time = os.time(), connect_time = 0
}

M.now_time = os.date('%H:%M:%S')
M.weekdays_ru = { [1]='Понедельник',[2]='Вторник',[3]='Среда',[4]='Четверг',[5]='Пятница',[6]='Суббота',[7]='Воскресенье' }
M.months_ru = { [1]='января',[2]='февраля',[3]='марта',[4]='апреля',[5]='мая',[6]='июня',[7]='июля',[8]='августа',[9]='сентября',[10]='октября',[11]='ноября',[12]='декабря' }

function M.get_str_date(unix_time)
    local day = tonumber(os.date('%d', unix_time))
    local month = M.months_ru[tonumber(os.date('%m', unix_time))]
    local w = tonumber(os.date('%w', unix_time))
    return ('%s, %d %s'):format(M.weekdays_ru[(w == 0) and 7 or w], day, month)
end

function M.pick_timer_position(window)
    lua_thread.create(function()
        window[0] = false
        if sampSetCursorMode then sampSetCursorMode(4) end
        util.chat_add_utf8('[BuhoiMenu] Нажмите SPACE для сохранения позиции таймера', 0x00C8FF)
        while true do
            config.cfg.timer.pos_x, config.cfg.timer.pos_y = getCursorPos()
            if isKeyDown(32) then
                if sampSetCursorMode then sampSetCursorMode(0) end
                config.save()
                util.chat_add_utf8('[BuhoiMenu] Позиция таймера сохранена', 0x00C8FF)
                break
            end
            wait(0)
        end
    end)
end

function M.start_thread()
    lua_thread.create(function()
        while true do
            wait(1000)
            M.now_time = os.date('%H:%M:%S')
            local ip, port = sampGetCurrentServerAddress()
            local cur = ip .. ':' .. tostring(port)
            if config.cfg.timer.server ~= '' and config.cfg.timer.server ~= cur then
                M.online.connect_time = M.online.connect_time + 1
                M.online.start_time = M.online.start_time + 1
                goto continue
            end
            if sampGetGamestate() == 3 then
                local day = util.get_weekday_index()
                M.online.session_online = M.online.session_online + 1
                M.online.session_full = os.time() - M.online.start_time
                M.online.session_afk = M.online.session_full - M.online.session_online
                M.online.day_online = M.online.day_online + 1
                M.online.day_full = M.online.day_full + 1
                M.online.day_afk = M.online.day_full - M.online.day_online
                M.online.week_online = M.online.week_online + 1
                M.online.week_full = M.online.week_full + 1
                M.online.week_afk = M.online.week_full - M.online.week_online
                M.online.week_days_online[day] = M.online.week_days_online[day] + 1
                M.online.week_days_full[day] = M.online.week_days_full[day] + 1
                M.online.week_days_afk[day] = M.online.week_days_full[day] - M.online.week_days_online[day]
                M.online.connect_time = 0
            else
                M.online.connect_time = M.online.connect_time + 1
                M.online.start_time = M.online.start_time + 1
            end
            ::continue::
        end
    end)
end

return M
