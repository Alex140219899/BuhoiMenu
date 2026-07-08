local imgui = require('mimgui')
local config = require('config')
local online = require('online')
local util = require('util')
local updater = require('updater')
local widgets = require('widgets')

local M = {}

function M.draw()
    widgets.section_title('Главная')
    imgui.Text(util.u8'Команда: /buhoimenu')
    imgui.Text(util.u8('Сессия online: ' .. util.as_clock(online.online.session_online)))
    imgui.Text(util.u8('Режим уведомлений: ' .. config.cfg.notify.delivery_mode))
    imgui.Separator()
    imgui.Text(util.u8('Локальная версия: ' .. util.get_local_script_version()))
    imgui.Text(util.u8('Версия GitHub: ' .. (updater.state.remote_script_ver ~= '' and updater.state.remote_script_ver or 'не проверена')))
    imgui.TextWrapped(util.u8('Статус: ' .. updater.state.status))
    if not updater.state.busy then
        if imgui.Button(util.u8'Проверить обновления', imgui.ImVec2(-1, 28)) then updater.check_updates_chat_only() end
        if imgui.Button(util.u8'Обновить с GitHub', imgui.ImVec2(-1, 28)) then updater.run_github_update() end
    end
end

return M
