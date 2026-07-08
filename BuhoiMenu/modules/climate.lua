local config = require('config')

local M = {}
M.actual_world = { time = 12, weather = 1 }

function M.set_time(hour, no_save)
    hour = tonumber(hour)
    if not hour or hour < 0 or hour > 23 then return end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, hour)
    raknetEmulRpcReceiveBitStream(94, bs)
    raknetDeleteBitStream(bs)
    if not no_save then config.cfg.climate.time_value = hour; config.save() end
end

function M.set_weather(id, no_save)
    id = tonumber(id)
    if not id or id < 0 or id > 45 then return end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, id)
    raknetEmulRpcReceiveBitStream(152, bs)
    raknetDeleteBitStream(bs)
    if not no_save then config.cfg.climate.weather_value = id; config.save() end
end

function M.on_set_weather(id)
    M.actual_world.weather = id
    if config.cfg.climate.lock_weather then return false end
end

function M.on_set_player_time(hour)
    M.actual_world.time = hour
    if config.cfg.climate.lock_time then return false end
end

function M.on_set_world_time(hour)
    M.actual_world.time = hour
    if config.cfg.climate.lock_time then return false end
end

function M.on_set_interior(interior)
    local in_world = (interior == 0)
    if config.cfg.climate.lock_time then
        M.set_time(in_world and config.cfg.climate.time_value or M.actual_world.time, true)
    end
    if config.cfg.climate.lock_weather then
        M.set_weather(in_world and config.cfg.climate.weather_value or M.actual_world.weather, true)
    end
end

function M.toggle_lock_time()
    config.cfg.climate.lock_time = not config.cfg.climate.lock_time
    config.save()
end

function M.toggle_lock_weather()
    config.cfg.climate.lock_weather = not config.cfg.climate.lock_weather
    config.save()
end

return M
