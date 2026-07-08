local imgui = require('mimgui')
local config = require('config')
local util = require('util')
local widgets = require('widgets')

local M = {}
local phrase_input = imgui.new.char[256]('')
local webhook_input = imgui.new.char[2048]('')
local tg_token_input = imgui.new.char[512]('')
local tg_chat_input = imgui.new.char[256]('')
local chk_notify_enabled = imgui.new.bool(false)

function M.init_inputs()
    webhook_input = imgui.new.char[2048](config.cfg.notify.webhook)
    tg_token_input = imgui.new.char[512](config.cfg.notify.telegram_bot_token)
    tg_chat_input = imgui.new.char[256](config.cfg.notify.telegram_chat_id)
    chk_notify_enabled[0] = config.cfg.notify.enabled
end

function M.draw()
    local col_w = (imgui.GetContentRegionAvail().x - 8) / 2
    if imgui.BeginChild('##notify_left', imgui.ImVec2(col_w, 0), true) then
        widgets.section_title('Настройки')
        if imgui.Checkbox(util.u8'Включено', chk_notify_enabled) then config.cfg.notify.enabled = chk_notify_enabled[0]; config.save() end
        local mode = widgets.combo_delivery_mode(config.cfg.notify.delivery_mode)
        if mode then config.cfg.notify.delivery_mode = mode; config.save() end
        if imgui.InputText(util.u8'Webhook', webhook_input, 2048) then
            config.cfg.notify.webhook = util.u8:decode(util.ffi.string(webhook_input)); config.save()
        end
        if imgui.InputText(util.u8'TG token', tg_token_input, 512) then
            config.cfg.notify.telegram_bot_token = util.u8:decode(util.ffi.string(tg_token_input)); config.save()
        end
        if imgui.InputText(util.u8'TG chat id', tg_chat_input, 256) then
            config.cfg.notify.telegram_chat_id = util.u8:decode(util.ffi.string(tg_chat_input)); config.save()
        end
        imgui.EndChild()
    end
    imgui.SameLine()
    if imgui.BeginChild('##notify_right', imgui.ImVec2(0, 0), true) then
        widgets.section_title('Фразы')
        if imgui.InputText(util.u8'Новая фраза', phrase_input, 256) then end
        if imgui.Button(util.u8'Добавить фразу', imgui.ImVec2(-1, 28)) then
            local phrase = util.u8:decode(util.ffi.string(phrase_input))
            if phrase ~= '' then table.insert(config.cfg.notify.phrases, phrase); phrase_input = imgui.new.char[256](''); config.save() end
        end
        for i, phrase in ipairs(config.cfg.notify.phrases) do
            imgui.Text(util.u8(phrase))
            imgui.SameLine()
            if imgui.Button(util.u8('Удалить##p' .. i)) then table.remove(config.cfg.notify.phrases, i); config.save(); break end
        end
        imgui.EndChild()
    end
end

return M
