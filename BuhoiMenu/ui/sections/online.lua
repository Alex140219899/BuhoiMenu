local imgui = require('mimgui')
local config = require('config')
local online = require('online')
local util = require('util')
local widgets = require('widgets')

local M = {}
local chk_timer_show_clock = imgui.new.bool(false)
local chk_timer_ses_online = imgui.new.bool(false)
local chk_timer_ses_afk = imgui.new.bool(false)
local chk_timer_ses_full = imgui.new.bool(false)
local chk_timer_day_online = imgui.new.bool(false)
local chk_timer_day_afk = imgui.new.bool(false)
local chk_timer_day_full = imgui.new.bool(false)
local chk_timer_week_online = imgui.new.bool(false)
local chk_timer_week_afk = imgui.new.bool(false)
local chk_timer_week_full = imgui.new.bool(false)
local chk_timer_enabled = imgui.new.bool(false)

function M.init_inputs()
    chk_timer_show_clock[0] = config.cfg.timer.show_clock
    chk_timer_ses_online[0] = config.cfg.timer.ses_online
    chk_timer_ses_afk[0] = config.cfg.timer.ses_afk
    chk_timer_ses_full[0] = config.cfg.timer.ses_full
    chk_timer_day_online[0] = config.cfg.timer.day_online
    chk_timer_day_afk[0] = config.cfg.timer.day_afk
    chk_timer_day_full[0] = config.cfg.timer.day_full
    chk_timer_week_online[0] = config.cfg.timer.week_online
    chk_timer_week_afk[0] = config.cfg.timer.week_afk
    chk_timer_week_full[0] = config.cfg.timer.week_full
    chk_timer_enabled[0] = config.cfg.timer.enabled
end

function M.draw_timer_overlay()
    if not config.cfg.timer.enabled then return end
    local flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse
        + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoInputs
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, config.cfg.timer.round)
    imgui.SetNextWindowPos(imgui.ImVec2(config.cfg.timer.pos_x, config.cfg.timer.pos_y), imgui.Cond.Always)
    imgui.Begin(util.u8'##timer_overlay', nil, flags)
    if config.cfg.timer.show_clock then
        imgui.Text(util.u8(online.now_time))
        imgui.Text(util.u8(online.get_str_date(os.time())))
        imgui.Separator()
    end
    if sampGetGamestate() ~= 3 then
        imgui.Text(util.u8('Подключение: ' .. util.as_clock(online.online.connect_time)))
    else
        local t = config.cfg.timer
        if t.ses_online then imgui.Text(util.u8('Сессия (чистый): ' .. util.as_clock(online.online.session_online))) end
        if t.ses_afk then imgui.Text(util.u8('AFK за сессию: ' .. util.as_clock(online.online.session_afk))) end
        if t.ses_full then imgui.Text(util.u8('Онлайн за сессию: ' .. util.as_clock(online.online.session_full))) end
        if t.day_online then imgui.Text(util.u8('За день (чистый): ' .. util.as_clock(online.online.day_online))) end
        if t.day_afk then imgui.Text(util.u8('AFK за день: ' .. util.as_clock(online.online.day_afk))) end
        if t.day_full then imgui.Text(util.u8('Онлайн за день: ' .. util.as_clock(online.online.day_full))) end
        if t.week_online then imgui.Text(util.u8('За неделю (чистый): ' .. util.as_clock(online.online.week_online))) end
        if t.week_afk then imgui.Text(util.u8('AFK за неделю: ' .. util.as_clock(online.online.week_afk))) end
        if t.week_full then imgui.Text(util.u8('Онлайн за неделю: ' .. util.as_clock(online.online.week_full))) end
    end
    imgui.End()
    imgui.PopStyleVar()
end

function M.draw(window)
    local col_w = (imgui.GetContentRegionAvail().x - 8) / 2
    if imgui.BeginChild('##online_left', imgui.ImVec2(col_w, 320), true) then
        widgets.section_title('Настройки')
        local rows = {
            { chk_timer_show_clock, 'show_clock', 'Текущее дата и время' },
            { chk_timer_ses_online, 'ses_online', 'Онлайн сессию' },
            { chk_timer_ses_afk, 'ses_afk', 'AFK за сессию' },
            { chk_timer_ses_full, 'ses_full', 'Общий за сессию' },
            { chk_timer_day_online, 'day_online', 'Онлайн за день' },
            { chk_timer_day_afk, 'day_afk', 'АФК за день' },
            { chk_timer_day_full, 'day_full', 'Общий за день' },
            { chk_timer_week_online, 'week_online', 'Онлайн за неделю' },
            { chk_timer_week_afk, 'week_afk', 'АФК за неделю' },
            { chk_timer_week_full, 'week_full', 'Общий за неделю' },
        }
        for _, row in ipairs(rows) do
            if imgui.Checkbox(util.u8(row[3]), row[1]) then config.cfg.timer[row[2]] = row[1][0]; config.save() end
        end
        imgui.EndChild()
    end
    imgui.SameLine()
    if imgui.BeginChild('##online_right', imgui.ImVec2(0, 320), true) then
        widgets.section_title('Таймер')
        if imgui.Checkbox(util.u8'Включить таймер', chk_timer_enabled) then config.cfg.timer.enabled = chk_timer_enabled[0]; config.save() end
        local pr = imgui.new.int(config.cfg.timer.round)
        if imgui.SliderInt(util.u8'Скругление', pr, 0, 16) then config.cfg.timer.round = pr[0]; config.save() end
        if imgui.Button(util.u8'Местоположение (SPACE)', imgui.ImVec2(-1, 28)) then online.pick_timer_position(window) end
        local ip, port = sampGetCurrentServerAddress()
        local cur = ip .. ':' .. tostring(port)
        if config.cfg.timer.server == cur then
            if imgui.Button(util.u8'Снять основной сервер', imgui.ImVec2(-1, 28)) then config.cfg.timer.server = ''; config.save() end
        else
            if imgui.Button(util.u8'Сделать этот сервер основным', imgui.ImVec2(-1, 28)) then config.cfg.timer.server = cur; config.save() end
        end
        imgui.EndChild()
    end
    widgets.section_title('Статистика')
    for _, line in ipairs({
        'Сессия online: ' .. util.as_clock(online.online.session_online),
        'Сессия afk: ' .. util.as_clock(online.online.session_afk),
        'День online: ' .. util.as_clock(online.online.day_online),
        'Неделя online: ' .. util.as_clock(online.online.week_online),
    }) do imgui.Text(util.u8(line)) end
    imgui.Text(util.u8'По дням недели (Пн-Вс):')
    for i = 1, 7 do
        if i == util.get_weekday_index() then imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.85, 0.45, 1.00)) end
        imgui.Text(util.u8(('%s | Online: %s | AFK: %s | Full: %s'):format(
            online.weekdays_ru[i], util.as_clock(online.online.week_days_online[i]),
            util.as_clock(online.online.week_days_afk[i]), util.as_clock(online.online.week_days_full[i])
        )))
        if i == util.get_weekday_index() then imgui.PopStyleColor() end
    end
end

return M
