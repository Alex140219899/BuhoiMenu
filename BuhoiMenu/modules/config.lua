local paths = require('paths')
local util = require('util')

local M = {}

M.cfg = {
    ui = { active_section = 'main' },
    notify = {
        webhook = '',
        telegram_bot_token = '',
        telegram_chat_id = '',
        delivery_mode = 'discord',
        enabled = true,
        phrases = {},
        bank = {
            enabled = false,
            webhook = '',
            telegram_bot_token = '',
            telegram_chat_id = '',
            delivery_mode = 'discord',
            events = {}
        }
    },
    climate = {
        time_value = 12,
        weather_value = 1,
        lock_time = false,
        lock_weather = false
    },
    autooff = {
        enabled = false,
        when_mode = 0,
        what_mode = 0,
        hour = 0,
        min = 0,
        sec = 0,
        repeat_enabled = false,
        repeat_hour = 0,
        repeat_min = 0,
        repeat_sec = 0,
        text = '',
        find_text = '',
        find_nick = ''
    },
    timer = {
        enabled = false,
        show_clock = true,
        ses_online = true,
        ses_afk = true,
        ses_full = true,
        day_online = true,
        day_afk = true,
        day_full = true,
        week_online = true,
        week_afk = true,
        week_full = true,
        pos_x = 20,
        pos_y = 240,
        round = 8,
        server = ''
    }
}

local function migrate_old_configs()
    if util.file_exists(paths.get_cfg_path()) then return end
    paths.ensure_data_dir()
    local candidates = {
        paths.get_worked_dir() .. '/BuhoiMenu.json',
        paths.get_worked_dir() .. '/buhoimenu/config.json',
        paths.get_worked_dir() .. '/BuhoiMenu/config.json'
    }
    for _, src in ipairs(candidates) do
        if util.file_exists(src) then
            util.copy_file(src, paths.get_cfg_path())
            return
        end
    end
end

function M.save()
    paths.ensure_data_dir()
    local f = io.open(paths.get_cfg_path(), 'w')
    if not f then return end
    local ok, data = pcall(encodeJson, M.cfg)
    f:write(ok and data or '{}')
    f:close()
end

local function ensure_defaults()
    local cfg = M.cfg
    if cfg.autooff.when_mode == nil then cfg.autooff.when_mode = 0 end
    if cfg.autooff.what_mode == nil then cfg.autooff.what_mode = 0 end
    if cfg.autooff.repeat_enabled == nil then cfg.autooff.repeat_enabled = false end
    if cfg.autooff.repeat_hour == nil then cfg.autooff.repeat_hour = 0 end
    if cfg.autooff.repeat_min == nil then cfg.autooff.repeat_min = 0 end
    if cfg.autooff.repeat_sec == nil then cfg.autooff.repeat_sec = 0 end
    if cfg.autooff.find_text == nil then cfg.autooff.find_text = '' end
    if cfg.autooff.find_nick == nil then cfg.autooff.find_nick = '' end
    if cfg.autooff.find_text == '' and cfg.autooff.find_nick ~= '' then
        cfg.autooff.find_text = cfg.autooff.find_nick
    end
    if cfg.timer == nil then cfg.timer = {} end
    local t = cfg.timer
    if t.enabled == nil then t.enabled = false end
    if t.show_clock == nil then t.show_clock = true end
    if t.ses_online == nil then t.ses_online = true end
    if t.ses_afk == nil then t.ses_afk = true end
    if t.ses_full == nil then t.ses_full = true end
    if t.day_online == nil then t.day_online = true end
    if t.day_afk == nil then t.day_afk = true end
    if t.day_full == nil then t.day_full = true end
    if t.week_online == nil then t.week_online = true end
    if t.week_afk == nil then t.week_afk = true end
    if t.week_full == nil then t.week_full = true end
    if t.pos_x == nil then t.pos_x = 20 end
    if t.pos_y == nil then t.pos_y = 240 end
    if t.round == nil then t.round = 8 end
    if t.server == nil then t.server = '' end
    if cfg.notify.bank == nil then
        cfg.notify.bank = {
            enabled = false, webhook = '', telegram_bot_token = '',
            telegram_chat_id = '', delivery_mode = 'discord', events = {}
        }
    end
    local bank = cfg.notify.bank
    if bank.events == nil then bank.events = {} end
    if bank.delivery_mode == nil then bank.delivery_mode = 'discord' end
    if bank.webhook == nil then bank.webhook = '' end
    if bank.telegram_bot_token == nil then bank.telegram_bot_token = '' end
    if bank.telegram_chat_id == nil then bank.telegram_chat_id = '' end
    if bank.enabled == nil then bank.enabled = false end
    if cfg.ui and cfg.ui.scale ~= nil then cfg.ui.scale = nil end
end

function M.load()
    migrate_old_configs()
    if not util.file_exists(paths.get_cfg_path()) then
        M.save()
        return
    end
    local f = io.open(paths.get_cfg_path(), 'r')
    if not f then return end
    local raw = f:read('*a')
    f:close()
    if raw == '' then return end
    local ok, data = pcall(decodeJson, raw)
    if ok and type(data) == 'table' then
        M.cfg.ui = data.ui or M.cfg.ui
        M.cfg.notify = data.notify or M.cfg.notify
        M.cfg.climate = data.climate or M.cfg.climate
        M.cfg.autooff = data.autooff or M.cfg.autooff
        M.cfg.timer = data.timer or M.cfg.timer
    end
    ensure_defaults()
end

return M
