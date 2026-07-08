local imgui = require('mimgui')
local config = require('config')
local autooff = require('autooff')
local util = require('util')
local widgets = require('widgets')

local M = {}
local auto_text_input = imgui.new.char[512]('')
local find_text_input = imgui.new.char[512]('')

function M.init_inputs()
    auto_text_input = imgui.new.char[512](config.cfg.autooff.text or '')
    find_text_input = imgui.new.char[512](config.cfg.autooff.find_text or '')
end

function M.draw()
    local col_w = (imgui.GetContentRegionAvail().x - 8) / 2
    local child_flags = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
    if imgui.BeginChild('##when_col', imgui.ImVec2(col_w, 214), true, child_flags) then
        widgets.section_title('Когда')
        local when_labels = { 'Через время', 'В опред. время', 'После ПейДея', 'После сообщения в чат', 'При потере соединения', 'При игроке в стриме' }
        for i, label in ipairs(when_labels) do
            if widgets.colored_select_button(util.u8(label .. '##w' .. i), config.cfg.autooff.when_mode == i, imgui.ImVec2(-1, 24)) then
                config.cfg.autooff.when_mode = util.pick_mode(config.cfg.autooff.when_mode, i); config.save()
            end
        end
        imgui.EndChild()
    end
    imgui.SameLine()
    if imgui.BeginChild('##what_col', imgui.ImVec2(0, 214), true, child_flags) then
        widgets.section_title('Что сделать')
        local what_labels = { 'Выключить ПК', 'Выйти из игры', 'Крашнуть игру', 'Написать в чат', 'Уведомление в чат', 'Перезайти на сервер' }
        for i, label in ipairs(what_labels) do
            if widgets.colored_select_button(util.u8(label .. '##a' .. i), config.cfg.autooff.what_mode == i, imgui.ImVec2(-1, 24)) then
                config.cfg.autooff.what_mode = util.pick_mode(config.cfg.autooff.what_mode, i); config.save()
            end
        end
        imgui.EndChild()
    end
    if config.cfg.autooff.when_mode == 1 or config.cfg.autooff.when_mode == 2 then
        local h, m, s = imgui.new.int(config.cfg.autooff.hour), imgui.new.int(config.cfg.autooff.min), imgui.new.int(config.cfg.autooff.sec)
        if imgui.SliderInt(util.u8'Часы', h, 0, 23) then config.cfg.autooff.hour = h[0]; config.save() end
        if imgui.SliderInt(util.u8'Минуты', m, 0, 59) then config.cfg.autooff.min = m[0]; config.save() end
        if imgui.SliderInt(util.u8'Секунды', s, 0, 59) then config.cfg.autooff.sec = s[0]; config.save() end
    end
    if config.cfg.autooff.when_mode == 4 or config.cfg.autooff.when_mode == 6 then
        if imgui.InputText(util.u8'##textt', find_text_input, 512) then
            config.cfg.autooff.find_text = util.u8:decode(util.ffi.string(find_text_input))
            config.cfg.autooff.find_nick = config.cfg.autooff.find_text
            config.save()
        end
    end
    if config.cfg.autooff.what_mode == 4 or config.cfg.autooff.what_mode == 5 then
        if imgui.InputText(util.u8'##texttt', auto_text_input, 512) then
            config.cfg.autooff.text = util.u8:decode(util.ffi.string(auto_text_input)); config.save()
        end
        if imgui.Button(config.cfg.autooff.repeat_enabled and util.u8'Повтор: ВКЛ' or util.u8'Повтор: ВЫКЛ', imgui.ImVec2(120, 24)) then
            config.cfg.autooff.repeat_enabled = not config.cfg.autooff.repeat_enabled; config.save()
        end
        if config.cfg.autooff.repeat_enabled then
            local rh, rm, rs = imgui.new.int(config.cfg.autooff.repeat_hour), imgui.new.int(config.cfg.autooff.repeat_min), imgui.new.int(config.cfg.autooff.repeat_sec)
            if imgui.SliderInt(util.u8'Часы', rh, 0, 23) then config.cfg.autooff.repeat_hour = rh[0]; config.save() end
            if imgui.SliderInt(util.u8'Минуты', rm, 0, 59) then config.cfg.autooff.repeat_min = rm[0]; config.save() end
            if imgui.SliderInt(util.u8'Секунды', rs, 0, 59) then config.cfg.autooff.repeat_sec = rs[0]; config.save() end
        end
    elseif config.cfg.autooff.repeat_enabled then
        config.cfg.autooff.repeat_enabled = false; config.save()
    end
    if imgui.Button(config.cfg.autooff.enabled and util.u8'Включено' or util.u8'Выключено', imgui.ImVec2(-1, 32)) then
        config.cfg.autooff.enabled = not config.cfg.autooff.enabled
        autooff.on_enable_toggle()
        config.save()
    end
end

return M
