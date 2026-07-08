local config = require('config')
local climate = require('climate')
local notify = require('notify')
local autooff = require('autooff')
local app = require('app')

local M = {}

function M.on_server_message(color, text)
    autooff.on_server_message(text)
    notify.on_server_message(text)
end

function M.on_player_stream_in(playerId)
    autooff.on_player_stream_in(playerId)
end

function M.on_receive_packet(id)
    autooff.on_receive_packet(id)
end

function M.on_send_command(command)
    if type(command) ~= 'string' or command == '' then return end
    local key = command:match('^%s*(%S+)'):lower()
    if key == '/buhoimenu' then app.window[0] = not app.window[0]; return false end
    if key == '/offme' then config.cfg.ui.active_section = 'autooff'; app.window[0] = true; return false end
    if key == '/online' then config.cfg.ui.active_section = 'online'; app.window[0] = true; return false end
    if key == '/bt' then climate.toggle_lock_time(); return false end
    if key == '/bw' then climate.toggle_lock_weather(); return false end
    if key == '/st' then
        local arg = command:match('^%S+%s+(.+)$')
        if arg then climate.set_time(arg:match('^%s*(.-)%s*$')) end
        return false
    end
    if key == '/sw' then
        local arg = command:match('^%S+%s+(.+)$')
        if arg then climate.set_weather(arg:match('^%s*(.-)%s*$')) end
        return false
    end
end

function M.on_set_weather(id) return climate.on_set_weather(id) end
function M.on_set_player_time(hour) return climate.on_set_player_time(hour) end
function M.on_set_world_time(hour) return climate.on_set_world_time(hour) end
function M.on_set_interior(interior) climate.on_set_interior(interior) end

return M
