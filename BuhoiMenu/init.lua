local imgui = require('mimgui')
local se = require('lib.samp.events')

local config = require('config')
local online = require('online')
local autooff = require('autooff')
local updater = require('updater')
local app = require('app')
local events = require('events')
local util = require('util')
local paths = require('paths')

local M = {}

function M.run()
    if _G.BUHOIMENU_LOADED then return end
    _G.BUHOIMENU_LOADED = true

    config.load()
    app.init_inputs()
    app.setup()

    function se.onServerMessage(color, text) events.on_server_message(color, text) end
    function se.onPlayerStreamIn(playerId) events.on_player_stream_in(playerId) end
    function onReceivePacket(id) events.on_receive_packet(id) end
    function se.onSendCommand(command) return events.on_send_command(command) end
    function se.onSetWeather(id) return events.on_set_weather(id) end
    function se.onSetPlayerTime(hour, min) return events.on_set_player_time(hour) end
    function se.onSetWorldTime(hour) return events.on_set_world_time(hour) end
    function se.onSetInterior(interior) events.on_set_interior(interior) end

    util.chat_add_utf8('[BuhoiMenu] /buhoimenu — меню | папка: ' .. paths.get_data_dir(), 0x00C8FF)

    updater.start_worker()
    updater.run_github_update()
    online.start_thread()
    autooff.start_thread()

    while true do
        imgui.ShowCursor = app.window[0]
        imgui.Process = app.window[0] or config.cfg.timer.enabled
        wait(0)
    end
end

return M
