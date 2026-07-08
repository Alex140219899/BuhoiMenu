local imgui = require('mimgui')
local config = require('config')
local climate = require('climate')
local util = require('util')
local widgets = require('widgets')

local M = {}
local chk_lock_time = imgui.new.bool(false)
local chk_lock_weather = imgui.new.bool(false)

function M.init_inputs()
    chk_lock_time[0] = config.cfg.climate.lock_time
    chk_lock_weather[0] = config.cfg.climate.lock_weather
end

function M.draw()
    widgets.section_title('Климат')
    local t = imgui.new.int(config.cfg.climate.time_value)
    local w = imgui.new.int(config.cfg.climate.weather_value)
    if imgui.SliderInt(util.u8'Час', t, 0, 23) then config.cfg.climate.time_value = t[0]; climate.set_time(t[0]) end
    if imgui.SliderInt(util.u8'Погода', w, 0, 45) then config.cfg.climate.weather_value = w[0]; climate.set_weather(w[0]) end
    if imgui.Checkbox(util.u8'Заморозить время', chk_lock_time) then config.cfg.climate.lock_time = chk_lock_time[0]; config.save() end
    if imgui.Checkbox(util.u8'Заморозить погоду', chk_lock_weather) then config.cfg.climate.lock_weather = chk_lock_weather[0]; config.save() end
end

return M
