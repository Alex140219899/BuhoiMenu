local ffi = require('ffi')
local config = require('config')
local util = require('util')

ffi.cdef('void __stdcall ExitProcess(unsigned int uExitCode);')

local M = {}
M.auto_state = {
    enabled_since = os.time(), next_allowed_ts = 0,
    last_clock_mark = '', last_hour_mark = '',
    msg_triggered = false, packet_triggered = false, nick_triggered = false
}

function M.on_enable_toggle()
    M.auto_state.enabled_since = os.time()
    M.auto_state.next_allowed_ts = 0
    M.auto_state.msg_triggered = false
    M.auto_state.packet_triggered = false
    M.auto_state.nick_triggered = false
end

function M.on_server_message(text)
    if config.cfg.autooff.enabled and config.cfg.autooff.when_mode == 4 and config.cfg.autooff.find_text ~= '' then
        if text:find(config.cfg.autooff.find_text) then M.auto_state.msg_triggered = true end
    end
end

function M.on_player_stream_in(playerId)
    if config.cfg.autooff.enabled and config.cfg.autooff.when_mode == 6 and config.cfg.autooff.find_text ~= '' then
        if sampGetPlayerNickname(playerId) == config.cfg.autooff.find_text then M.auto_state.nick_triggered = true end
    end
end

function M.on_receive_packet(id)
    if config.cfg.autooff.enabled and config.cfg.autooff.when_mode == 5 and id == 32 then
        M.auto_state.packet_triggered = true
    end
end

local function run_action()
    local a = config.cfg.autooff
    if a.what_mode == 1 then os.execute('shutdown /s /t 5')
    elseif a.what_mode == 2 then ffi.C.ExitProcess(0)
    elseif a.what_mode == 3 then deleteChar(1)
    elseif a.what_mode == 4 then sampProcessChatInput(a.text)
    elseif a.what_mode == 5 then util.chat_add_utf8(a.text, -1)
    elseif a.what_mode == 6 then
        local ip, port = sampGetCurrentServerAddress()
        wait(1000)
        sampConnectToServer(ip, port)
    end
end

function M.start_thread()
    lua_thread.create(function()
        while true do
            wait(200)
            local a = config.cfg.autooff
            if a.enabled and a.when_mode > 0 and a.what_mode > 0 and os.time() >= M.auto_state.next_allowed_ts then
                local triggered = false
                if a.when_mode == 1 then
                    local target = a.hour * 3600 + a.min * 60 + a.sec
                    triggered = target > 0 and (os.time() - M.auto_state.enabled_since) >= target
                elseif a.when_mode == 2 then
                    local mark = os.date('%Y%m%d%H%M%S')
                    triggered = (tonumber(os.date('%H')) == a.hour and tonumber(os.date('%M')) == a.min
                        and tonumber(os.date('%S')) == a.sec and M.auto_state.last_clock_mark ~= mark)
                    if triggered then M.auto_state.last_clock_mark = mark end
                elseif a.when_mode == 3 then
                    local hour_mark = os.date('%Y%m%d%H')
                    triggered = (tonumber(os.date('%M')) == 1 and tonumber(os.date('%S')) == 0 and M.auto_state.last_hour_mark ~= hour_mark)
                    if triggered then M.auto_state.last_hour_mark = hour_mark end
                elseif a.when_mode == 4 then triggered = M.auto_state.msg_triggered; M.auto_state.msg_triggered = false
                elseif a.when_mode == 5 then triggered = M.auto_state.packet_triggered; M.auto_state.packet_triggered = false
                elseif a.when_mode == 6 then triggered = M.auto_state.nick_triggered; M.auto_state.nick_triggered = false end
                if triggered then
                    run_action()
                    if a.repeat_enabled then
                        local repeat_sec = a.repeat_hour * 3600 + a.repeat_min * 60 + a.repeat_sec
                        M.auto_state.next_allowed_ts = os.time() + math.max(repeat_sec, 1)
                        M.auto_state.enabled_since = os.time()
                    else
                        a.enabled = false
                        config.save()
                    end
                end
            end
        end
    end)
end

return M
