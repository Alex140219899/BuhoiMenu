script_name('BuhoiMenu')
script_author('Buhoi')
script_description('Unified menu: timer, climate, notify, auto off')
script_version('1.0.0')

local imgui = require('mimgui')
local encoding = require('encoding')
local ffi = require('ffi')
local effil = require('effil')
local se = require('lib.samp.events')

encoding.default = 'UTF-8'
local u8 = encoding.UTF8
ffi.cdef('void __stdcall ExitProcess(unsigned int uExitCode);')

local working_dir = getWorkingDirectory():gsub('\\', '/')
local cfg_path = working_dir .. '/BuhoiMenu.json'
local UPDATE_MANIFEST_URL = 'https://raw.githubusercontent.com/Alex140219899/BuhoiMenu/main/BuhoiUpdate.json'
local UPDATE_TMP_MANIFEST = working_dir .. '/.buhoi_manifest_tmp.json'
local UPDATE_TMP_SCRIPT = working_dir .. '/.buhoi_new.lua'
local cfg = {
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

local updater

local function file_exists(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
end

local function chat_add_utf8(msg, color)
    local text = tostring(msg or '')
    local ok, decoded = pcall(function() return u8:decode(text) end)
    sampAddChatMessage(ok and decoded or text, color or 0x66CCFF)
end

local function version_trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

local function read_script_version_from_path(path)
    local f = io.open(path or '', 'rb')
    if not f then return nil end
    local head = f:read(65536) or ''
    f:close()
    local v = head:match("script_version%s*%(%s*['\"]([^'\"]+)['\"]%s*%)")
    if v and v ~= '' then return version_trim(v) end
    return nil
end

local function get_local_script_version()
    local ts = thisScript and thisScript()
    if ts and ts.path then
        local from_disk = read_script_version_from_path(ts.path)
        if from_disk then return from_disk end
    end
    if ts and ts.version and tostring(ts.version) ~= '' then
        return version_trim(ts.version)
    end
    return 'unknown'
end

local function download_url_to_file_sync(dest, url, timeout_sec)
    if type(downloadUrlToFile) ~= 'function' then
        return false
    end
    local ml = package.loaded['moonloader'] or require('moonloader')
    local st = ml.download_status
    local done, ok = false, false
    pcall(function()
        downloadUrlToFile(url, dest, function(_, status)
            if status == st.STATUS_ENDDOWNLOADDATA then
                done, ok = true, true
            elseif st.STATUS_ENDDOWNLOADERR and status == st.STATUS_ENDDOWNLOADERR then
                done, ok = true, false
            end
        end)
    end)
    local elapsed, limit = 0, math.floor((timeout_sec or 60) * 10)
    while not done and elapsed < limit do
        wait(100)
        elapsed = elapsed + 1
    end
    return ok and file_exists(dest)
end

local function fetch_update_manifest()
    local function with_cache_bust(base)
        local sep = base:find('?', 1, true) and '&' or '?'
        return base .. sep .. 't=' .. tostring(os.time())
    end
    local urls = { with_cache_bust(UPDATE_MANIFEST_URL) }
    if UPDATE_MANIFEST_URL:find('/main/', 1, true) then
        urls[#urls + 1] = with_cache_bust(UPDATE_MANIFEST_URL:gsub('/main/', '/master/', 1))
    elseif UPDATE_MANIFEST_URL:find('/master/', 1, true) then
        urls[#urls + 1] = with_cache_bust(UPDATE_MANIFEST_URL:gsub('/master/', '/main/', 1))
    end
    local last_err = ''
    for _, url in ipairs(urls) do
        if file_exists(UPDATE_TMP_MANIFEST) then pcall(os.remove, UPDATE_TMP_MANIFEST) end
        if download_url_to_file_sync(UPDATE_TMP_MANIFEST, url, 45) then
            local f = io.open(UPDATE_TMP_MANIFEST, 'r')
            if f then
                local raw = f:read('*a') or ''
                f:close()
                pcall(os.remove, UPDATE_TMP_MANIFEST)
                local ok, data = pcall(decodeJson, raw)
                if ok and type(data) == 'table' then
                    if data.current_version and tostring(data.current_version) ~= '' then
                        return data, nil
                    end
                    last_err = 'В BuhoiUpdate.json отсутствует current_version'
                else
                    last_err = 'Ошибка разбора BuhoiUpdate.json'
                end
            else
                last_err = 'Не удалось открыть скачанный BuhoiUpdate.json'
            end
        end
    end
    if last_err == '' then
        last_err = 'Файл не скачан. Проверьте UPDATE_MANIFEST_URL: ' .. UPDATE_MANIFEST_URL
    end
    return nil, last_err
end

local function apply_manifest_to_updater(m)
    updater.remote_version = version_trim(m.current_version)
    updater.update_info = type(m.update_info) == 'string' and m.update_info or ''
    updater.update_url = type(m.update_url) == 'string' and m.update_url or ''
    updater.has_update = updater.remote_version ~= '' and updater.remote_version ~= get_local_script_version()
end

local function check_updates_chat_only()
    if updater.busy then
        updater.status = 'Подождите, проверка уже выполняется.'
        return
    end
    updater.busy = true
    updater.status = 'Проверяем обновления...'
    lua_thread.create(function()
        local manifest, err = fetch_update_manifest()
        if not manifest then
            updater.status = 'Ошибка: ' .. tostring(err)
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            updater.busy = false
            return
        end
        apply_manifest_to_updater(manifest)
        if updater.has_update then
            updater.status = ('Доступно обновление: %s -> %s'):format(get_local_script_version(), updater.remote_version)
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            if updater.update_info ~= '' then
                chat_add_utf8('[BuhoiMenu] Что изменено: ' .. updater.update_info, 0x66CCFF)
            end
        else
            updater.status = ('У вас актуальная версия: %s'):format(get_local_script_version())
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
        end
        updater.busy = false
    end)
end

local function run_script_update()
    if updater.busy then
        updater.status = 'Подождите, операция уже выполняется.'
        return
    end
    updater.busy = true
    updater.status = 'Запуск обновления...'
    lua_thread.create(function()
        local manifest, err = fetch_update_manifest()
        if not manifest then
            updater.status = 'Ошибка: ' .. tostring(err)
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            updater.busy = false
            return
        end
        apply_manifest_to_updater(manifest)
        if not updater.has_update then
            updater.status = ('Обновлений нет. Текущая версия: %s'):format(get_local_script_version())
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            updater.busy = false
            return
        end
        if updater.update_url == '' then
            updater.status = 'В BuhoiUpdate.json отсутствует update_url'
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            updater.busy = false
            return
        end
        if file_exists(UPDATE_TMP_SCRIPT) then pcall(os.remove, UPDATE_TMP_SCRIPT) end
        updater.status = 'Скачиваем новую версию скрипта...'
        if not download_url_to_file_sync(UPDATE_TMP_SCRIPT, updater.update_url, 120) then
            updater.status = 'Ошибка скачивания новой версии .lua'
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            updater.busy = false
            return
        end
        local fin = io.open(UPDATE_TMP_SCRIPT, 'rb')
        if not fin then
            updater.status = 'Не удалось прочитать скачанный файл.'
            updater.busy = false
            return
        end
        local body = fin:read('*a') or ''
        fin:close()
        local path = thisScript().path
        local fout = io.open(path, 'wb') or io.open(path:gsub('/', '\\'), 'wb')
        if not fout then
            updater.status = 'Не удалось записать BuhoiMenu.lua'
            chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
            updater.busy = false
            return
        end
        fout:write(body)
        if fout.flush then pcall(fout.flush, fout) end
        fout:close()
        pcall(os.remove, UPDATE_TMP_SCRIPT)
        updater.status = ('Обновлено до версии %s. Перезагружаем...'):format(updater.remote_version)
        chat_add_utf8('[BuhoiMenu] ' .. updater.status, 0x66CCFF)
        if updater.update_info ~= '' then
            chat_add_utf8('[BuhoiMenu] Что изменено: ' .. updater.update_info, 0x66CCFF)
        end
        updater.busy = false
        wait(900)
        local ts = thisScript and thisScript()
        if ts and type(ts.reload) == 'function' then
            ts:reload()
        elseif type(reloadScript) == 'function' then
            reloadScript()
        end
    end)
end

local function migrate_nested_config_if_needed()
    if file_exists(cfg_path) then return end
    local nested = getWorkingDirectory():gsub('\\', '/') .. '/BuhoiMenu/config.json'
    if not file_exists(nested) then return end
    local fin = io.open(nested, 'r')
    if not fin then return end
    local raw = fin:read('*a')
    fin:close()
    local fout = io.open(cfg_path, 'w')
    if not fout then return end
    fout:write(raw)
    fout:close()
end

local function save_cfg()
    local f = io.open(cfg_path, 'w')
    if not f then return end
    local ok, data = pcall(encodeJson, cfg)
    f:write(ok and data or '{}')
    f:close()
end

local function load_cfg()
    migrate_nested_config_if_needed()
    if not file_exists(cfg_path) then
        save_cfg()
        return
    end
    local f = io.open(cfg_path, 'r')
    if not f then return end
    local raw = f:read('*a')
    f:close()
    if raw == '' then return end
    local ok, data = pcall(decodeJson, raw)
    if ok and type(data) == 'table' then
        cfg.ui = data.ui or cfg.ui
        if cfg.ui.scale ~= nil then cfg.ui.scale = nil end
        cfg.notify = data.notify or cfg.notify
        cfg.climate = data.climate or cfg.climate
        cfg.autooff = data.autooff or cfg.autooff
        cfg.timer = data.timer or cfg.timer
    end
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
    if cfg.timer.enabled == nil then cfg.timer.enabled = false end
    if cfg.timer.show_clock == nil then cfg.timer.show_clock = true end
    if cfg.timer.ses_online == nil then cfg.timer.ses_online = true end
    if cfg.timer.ses_afk == nil then cfg.timer.ses_afk = true end
    if cfg.timer.ses_full == nil then cfg.timer.ses_full = true end
    if cfg.timer.day_online == nil then cfg.timer.day_online = true end
    if cfg.timer.day_afk == nil then cfg.timer.day_afk = true end
    if cfg.timer.day_full == nil then cfg.timer.day_full = true end
    if cfg.timer.week_online == nil then cfg.timer.week_online = true end
    if cfg.timer.week_afk == nil then cfg.timer.week_afk = true end
    if cfg.timer.week_full == nil then cfg.timer.week_full = true end
    if cfg.timer.pos_x == nil then cfg.timer.pos_x = 20 end
    if cfg.timer.pos_y == nil then cfg.timer.pos_y = 240 end
    if cfg.timer.round == nil then cfg.timer.round = 8 end
    if cfg.timer.server == nil then cfg.timer.server = '' end
    if cfg.notify.bank == nil then
        cfg.notify.bank = {
            enabled = false,
            webhook = '',
            telegram_bot_token = '',
            telegram_chat_id = '',
            delivery_mode = 'discord',
            events = {}
        }
    end
    if cfg.notify.bank.events == nil then cfg.notify.bank.events = {} end
    if cfg.notify.bank.delivery_mode == nil then cfg.notify.bank.delivery_mode = 'discord' end
    if cfg.notify.bank.webhook == nil then cfg.notify.bank.webhook = '' end
    if cfg.notify.bank.telegram_bot_token == nil then cfg.notify.bank.telegram_bot_token = '' end
    if cfg.notify.bank.telegram_chat_id == nil then cfg.notify.bank.telegram_chat_id = '' end
    if cfg.notify.bank.enabled == nil then cfg.notify.bank.enabled = false end
end

local window = imgui.new.bool(false)
local phrase_input = imgui.new.char[256]('')
local webhook_input = imgui.new.char[2048]('')
local tg_token_input = imgui.new.char[512]('')
local tg_chat_input = imgui.new.char[256]('')
local auto_text_input = imgui.new.char[512]('')
local find_text_input = imgui.new.char[512]('')
local find_nick_input = imgui.new.char[64]('')
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
local chk_climate_lock_time = imgui.new.bool(false)
local chk_climate_lock_weather = imgui.new.bool(false)
local chk_notify_enabled = imgui.new.bool(false)
local chk_notify_bank_enabled = imgui.new.bool(false)
local bank_webhook_input = imgui.new.char[2048]('')
local bank_tg_token_input = imgui.new.char[512]('')
local bank_tg_chat_input = imgui.new.char[256]('')
--- Типы банковских сообщений (подстроки / паттерны в духе salary_imgui)
local bank_event_chks = {}
local BANK_EVENT_DEFS = {
    { id = 'deposit_withdraw', label = 'Снятие с депозита', pat = 'Вы сняли деньги с депозитного', plain = true },
    { id = 'deposit_put', label = 'Пополнение депозита', pat = 'Вы положили на свой депозитный', plain = true },
    { id = 'bank_put', label = 'Пополнение банковского счёта', pat = 'Вы положили на свой банковский счет', plain = true },
    { id = 'bank_withdraw', label = 'Снятие с банковского счёта', pat = 'Вы сняли со своего банковского', plain = true },
    { id = 'bank_atm_info', label = 'Банкомат: остаток на счёте', pat = '[Информация] Остаток:', plain = true },
    { id = 'bank_transfer', label = 'Банковский перевод игроку', pat = 'Вы перевели', plain = true },
    { id = 'bank_transfer_in', label = 'Входящий перевод на счёт (от игрока)', pat = 'Вам поступил перевод', plain = true },
    { id = 'salary_to_bank', label = 'Зачисление зарплаты на счёт', pat = 'Зачислено на банковский сч', plain = true },
    { id = 'vc_exchange', label = 'Обмен с Vice City / валюта', pat = 'Вы успешно обменяли', plain = true },
    { id = 'btc_sell', label = 'Продажа BTC (обмен BTC на $)', pat = 'Вы совершили обмен BTC', plain = true },
    { id = 'btc_buy', label = 'Покупка BTC ($ на BTC)', pat = 'Вы совершили обмен %$.+ на .+ BTC', plain = false },
    { id = 'pay_cash', label = 'Передача наличных (/pay)', pat = 'Вы передали $', plain = true },
}

local online = {
    session_online = 0,
    session_full = 0,
    session_afk = 0,
    day_online = 0,
    day_full = 0,
    day_afk = 0,
    week_online = 0,
    week_full = 0,
    week_afk = 0,
    week_days_full = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, -- Mon..Sun
    week_days_online = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 },
    week_days_afk = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 },
    start_time = os.time(),
    connect_time = 0
}

local actual_world = { time = 12, weather = 1 }
local autooff_fired = false
local weekdays_ru = { [1] = 'Понедельник', [2] = 'Вторник', [3] = 'Среда', [4] = 'Четверг', [5] = 'Пятница', [6] = 'Суббота', [7] = 'Воскресенье' }
local months_ru = { [1] = 'января', [2] = 'февраля', [3] = 'марта', [4] = 'апреля', [5] = 'мая', [6] = 'июня', [7] = 'июля', [8] = 'августа', [9] = 'сентября', [10] = 'октября', [11] = 'ноября', [12] = 'декабря' }
local now_time = os.date('%H:%M:%S')
local auto_state = {
    enabled_since = os.time(),
    next_allowed_ts = 0,
    last_clock_mark = '',
    last_hour_mark = '',
    msg_triggered = false,
    packet_triggered = false,
    nick_triggered = false
}

updater = {
    busy = false,
    has_update = false,
    remote_version = '',
    update_info = '',
    update_url = '',
    status = 'Нажмите "Проверить обновление".'
}

local function as_clock(sec)
    if sec < 0 then sec = 0 end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format('%02d:%02d:%02d', h, m, s)
end

local function get_str_date(unix_time)
    local day = tonumber(os.date('%d', unix_time))
    local month = months_ru[tonumber(os.date('%m', unix_time))]
    local w = tonumber(os.date('%w', unix_time))
    local weekday = weekdays_ru[(w == 0) and 7 or w]
    return ('%s, %d %s'):format(weekday, day, month)
end

local function draw_timer_overlay()
    if not cfg.timer.enabled then return end
    local flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoInputs
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, cfg.timer.round)
    imgui.SetNextWindowPos(imgui.ImVec2(cfg.timer.pos_x, cfg.timer.pos_y), imgui.Cond.Always)
    imgui.Begin(u8'##timer_overlay', nil, flags)
    if cfg.timer.show_clock then
        imgui.Text(u8(now_time))
        imgui.Text(u8(get_str_date(os.time())))
        imgui.Separator()
    end
    if sampGetGamestate() ~= 3 then
        imgui.Text(u8('Подключение: ' .. as_clock(online.connect_time)))
    else
        if cfg.timer.ses_online then imgui.Text(u8('Сессия (чистый): ' .. as_clock(online.session_online))) end
        if cfg.timer.ses_afk then imgui.Text(u8('AFK за сессию: ' .. as_clock(online.session_afk))) end
        if cfg.timer.ses_full then imgui.Text(u8('Онлайн за сессию: ' .. as_clock(online.session_full))) end
        if cfg.timer.day_online then imgui.Text(u8('За день (чистый): ' .. as_clock(online.day_online))) end
        if cfg.timer.day_afk then imgui.Text(u8('AFK за день: ' .. as_clock(online.day_afk))) end
        if cfg.timer.day_full then imgui.Text(u8('Онлайн за день: ' .. as_clock(online.day_full))) end
        if cfg.timer.week_online then imgui.Text(u8('За неделю (чистый): ' .. as_clock(online.week_online))) end
        if cfg.timer.week_afk then imgui.Text(u8('AFK за неделю: ' .. as_clock(online.week_afk))) end
        if cfg.timer.week_full then imgui.Text(u8('Онлайн за неделю: ' .. as_clock(online.week_full))) end
    end
    imgui.End()
    imgui.PopStyleVar()
end

local function pick_timer_position()
    lua_thread.create(function()
        window[0] = false
        if sampSetCursorMode then sampSetCursorMode(4) end
        sampAddChatMessage('[BuhoiMenu] Нажмите SPACE для сохранения позиции таймера', 0x00C8FF)
        while true do
            local cX, cY = getCursorPos()
            cfg.timer.pos_x = cX
            cfg.timer.pos_y = cY
            if isKeyDown(32) then
                if sampSetCursorMode then sampSetCursorMode(0) end
                save_cfg()
                sampAddChatMessage('[BuhoiMenu] Позиция таймера сохранена', 0x00C8FF)
                break
            end
            wait(0)
        end
    end)
end

local function get_weekday_index()
    local w = tonumber(os.date('%w')) -- 0=Sunday, 1=Monday, ... 6=Saturday
    return (w == 0) and 7 or w
end

local function is_monet_loader()
    return MONET_VERSION ~= nil
end

local function async_http_request(method, url, args, resolve, reject)
    local request_thread = effil.thread(function(m, u, a, monet)
        local requests = require('requests')
        local payload = monet and effil.dump(a) or a
        local ok, response = pcall(requests.request, m, u, payload)
        if ok then
            response.json, response.xml = nil, nil
            return true, response
        end
        return false, response
    end)(method, url, args, is_monet_loader())

    if not resolve then resolve = function() end end
    if not reject then reject = function() end end

    lua_thread.create(function()
        while true do
            local status, err = request_thread:status()
            if err then return reject(err) end
            if status == 'completed' then
                local ok, resp = request_thread:get()
                return (ok and resolve or reject)(resp)
            elseif status == 'canceled' then
                return reject('canceled')
            end
            wait(0)
        end
    end)
end

local function send_discord(msg)
    if cfg.notify.webhook == '' then return end
    local payload = {
        content = nil,
        embeds = { { description = msg, color = 16744062 } },
        attachments = {}
    }
    local ok, data = pcall(encodeJson, payload)
    if not ok then return end
    async_http_request('POST', cfg.notify.webhook, {
        headers = { ['content-type'] = 'application/json' },
        data = u8(data)
    })
end

local function send_telegram(msg)
    if cfg.notify.telegram_bot_token == '' or cfg.notify.telegram_chat_id == '' then return end
    local url = 'https://api.telegram.org/bot' .. cfg.notify.telegram_bot_token .. '/sendMessage'
    local payload = {
        chat_id = cfg.notify.telegram_chat_id,
        text = msg,
        disable_web_page_preview = true
    }
    local ok, data = pcall(encodeJson, payload)
    if not ok then return end
    async_http_request('POST', url, {
        headers = { ['content-type'] = 'application/json' },
        data = u8(data)
    })
end

local function send_notify(msg)
    if not cfg.notify.enabled then return end
    if cfg.notify.delivery_mode == 'discord' or cfg.notify.delivery_mode == 'both' then
        send_discord(msg)
    end
    if cfg.notify.delivery_mode == 'telegram' or cfg.notify.delivery_mode == 'both' then
        send_telegram(msg)
    end
end

local function send_bank_discord(msg)
    if not cfg.notify.bank or cfg.notify.bank.webhook == '' then return end
    local payload = {
        content = nil,
        embeds = { { description = msg, color = 3447003 } },
        attachments = {}
    }
    local ok, data = pcall(encodeJson, payload)
    if not ok then return end
    async_http_request('POST', cfg.notify.bank.webhook, {
        headers = { ['content-type'] = 'application/json' },
        data = u8(data)
    })
end

local function send_bank_telegram(msg)
    if not cfg.notify.bank then return end
    if cfg.notify.bank.telegram_bot_token == '' or cfg.notify.bank.telegram_chat_id == '' then return end
    local url = 'https://api.telegram.org/bot' .. cfg.notify.bank.telegram_bot_token .. '/sendMessage'
    local payload = {
        chat_id = cfg.notify.bank.telegram_chat_id,
        text = msg,
        disable_web_page_preview = true
    }
    local ok, data = pcall(encodeJson, payload)
    if not ok then return end
    async_http_request('POST', url, {
        headers = { ['content-type'] = 'application/json' },
        data = u8(data)
    })
end

local function send_bank_notify(msg)
    if not cfg.notify.bank or not cfg.notify.bank.enabled then return end
    local mode = cfg.notify.bank.delivery_mode or 'discord'
    if mode == 'discord' or mode == 'both' then
        send_bank_discord(msg)
    end
    if mode == 'telegram' or mode == 'both' then
        send_bank_telegram(msg)
    end
end

local function match_bank_event(clean_text)
    for _, def in ipairs(BANK_EVENT_DEFS) do
        if cfg.notify.bank.events[def.id] then
            local ok
            if def.plain then
                ok = clean_text:find(def.pat, 1, true)
            else
                ok = clean_text:find(def.pat)
            end
            if ok then
                return def.label
            end
        end
    end
    return nil
end

function se.onServerMessage(color, text)
    if cfg.autooff.enabled and cfg.autooff.when_mode == 4 and cfg.autooff.find_text ~= '' then
        if text:find(cfg.autooff.find_text) then
            auto_state.msg_triggered = true
        end
    end
    local clean = text:gsub('{......}', '')
    if cfg.notify.bank and cfg.notify.bank.enabled then
        local bank_label = match_bank_event(clean)
        if bank_label then
            send_bank_notify(('[Банк: %s]\n%s'):format(bank_label, clean))
        end
    end

    if not cfg.notify.enabled or #cfg.notify.phrases == 0 then return end
    for _, phrase in ipairs(cfg.notify.phrases) do
        if phrase ~= '' and text:find(phrase) then
            send_notify(clean)
            return
        end
    end
end

function se.onPlayerStreamIn(playerId)
    if cfg.autooff.enabled and cfg.autooff.when_mode == 6 and cfg.autooff.find_text ~= '' then
        if sampGetPlayerNickname(playerId) == cfg.autooff.find_text then
            auto_state.nick_triggered = true
        end
    end
end

function onReceivePacket(id)
    if cfg.autooff.enabled and cfg.autooff.when_mode == 5 and id == 32 then
        auto_state.packet_triggered = true
    end
end

--- Перехват /cmd до сервера: иначе первый раз команда «теряется», со второго — «неизвестная команда».
function se.onSendCommand(command)
    if type(command) ~= 'string' or command == '' then return end
    local first = command:match('^%s*(%S+)')
    if not first then return end
    local key = first:lower()

    if key == '/buhoimenu' then
        window[0] = not window[0]
        return false
    end
    if key == '/offme' then
        cfg.ui.active_section = 'autooff'
        window[0] = true
        return false
    end
    if key == '/online' then
        cfg.ui.active_section = 'online'
        window[0] = true
        return false
    end
    if key == '/bt' then
        cfg.climate.lock_time = not cfg.climate.lock_time
        save_cfg()
        return false
    end
    if key == '/bw' then
        cfg.climate.lock_weather = not cfg.climate.lock_weather
        save_cfg()
        return false
    end
    if key == '/st' then
        local arg = command:match('^%S+%s+(.+)$')
        if arg then
            arg = arg:match('^%s*(.-)%s*$')
            set_time(arg)
        end
        return false
    end
    if key == '/sw' then
        local arg = command:match('^%S+%s+(.+)$')
        if arg then
            arg = arg:match('^%s*(.-)%s*$')
            set_weather(arg)
        end
        return false
    end
end

function se.onSetWeather(id)
    actual_world.weather = id
    if cfg.climate.lock_weather then return false end
end

function se.onSetPlayerTime(hour, min)
    actual_world.time = hour
    if cfg.climate.lock_time then return false end
end

function se.onSetWorldTime(hour)
    actual_world.time = hour
    if cfg.climate.lock_time then return false end
end

function se.onSetInterior(interior)
    local in_world = (interior == 0)
    if cfg.climate.lock_time then
        set_time(in_world and cfg.climate.time_value or actual_world.time, true)
    end
    if cfg.climate.lock_weather then
        set_weather(in_world and cfg.climate.weather_value or actual_world.weather, true)
    end
end

function set_time(hour, no_save)
    hour = tonumber(hour)
    if not hour or hour < 0 or hour > 23 then return end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, hour)
    raknetEmulRpcReceiveBitStream(94, bs)
    raknetDeleteBitStream(bs)
    if not no_save then
        cfg.climate.time_value = hour
        save_cfg()
    end
end

function set_weather(id, no_save)
    id = tonumber(id)
    if not id or id < 0 or id > 45 then return end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, id)
    raknetEmulRpcReceiveBitStream(152, bs)
    raknetDeleteBitStream(bs)
    if not no_save then
        cfg.climate.weather_value = id
        save_cfg()
    end
end

local function run_autooff_action()
    if cfg.autooff.what_mode == 1 then
        os.execute('shutdown /s /t 5')
    elseif cfg.autooff.what_mode == 2 then
        ffi.C.ExitProcess(0)
    elseif cfg.autooff.what_mode == 3 then
        deleteChar(1)
    elseif cfg.autooff.what_mode == 4 then
        sampProcessChatInput(cfg.autooff.text)
    elseif cfg.autooff.what_mode == 5 then
        sampAddChatMessage(cfg.autooff.text, -1)
    elseif cfg.autooff.what_mode == 6 then
        local ip, port = sampGetCurrentServerAddress()
        wait(1000)
        sampConnectToServer(ip, port)
    end
end

local function pick_mode(current, target)
    if current ~= target then
        return target
    end
    return 0
end

local function init_inputs()
    webhook_input = imgui.new.char[2048](cfg.notify.webhook)
    tg_token_input = imgui.new.char[512](cfg.notify.telegram_bot_token)
    tg_chat_input = imgui.new.char[256](cfg.notify.telegram_chat_id)
    auto_text_input = imgui.new.char[512](cfg.autooff.text or '')
    find_text_input = imgui.new.char[512](cfg.autooff.find_text or '')
    find_nick_input = imgui.new.char[64](cfg.autooff.find_nick or '')
    chk_timer_show_clock[0] = cfg.timer.show_clock
    chk_timer_ses_online[0] = cfg.timer.ses_online
    chk_timer_ses_afk[0] = cfg.timer.ses_afk
    chk_timer_ses_full[0] = cfg.timer.ses_full
    chk_timer_day_online[0] = cfg.timer.day_online
    chk_timer_day_afk[0] = cfg.timer.day_afk
    chk_timer_day_full[0] = cfg.timer.day_full
    chk_timer_week_online[0] = cfg.timer.week_online
    chk_timer_week_afk[0] = cfg.timer.week_afk
    chk_timer_week_full[0] = cfg.timer.week_full
    chk_timer_enabled[0] = cfg.timer.enabled
    chk_climate_lock_time[0] = cfg.climate.lock_time
    chk_climate_lock_weather[0] = cfg.climate.lock_weather
    chk_notify_enabled[0] = cfg.notify.enabled
    chk_notify_bank_enabled[0] = cfg.notify.bank and cfg.notify.bank.enabled or false
    bank_webhook_input = imgui.new.char[2048](cfg.notify.bank and cfg.notify.bank.webhook or '')
    bank_tg_token_input = imgui.new.char[512](cfg.notify.bank and cfg.notify.bank.telegram_bot_token or '')
    bank_tg_chat_input = imgui.new.char[256](cfg.notify.bank and cfg.notify.bank.telegram_chat_id or '')
    for _, def in ipairs(BANK_EVENT_DEFS) do
        if bank_event_chks[def.id] == nil then
            bank_event_chks[def.id] = imgui.new.bool(false)
        end
        bank_event_chks[def.id][0] = cfg.notify.bank.events[def.id] == true
    end
end

local function colored_select_button(label, selected, size)
    if selected then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.80, 0.25, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.90, 0.30, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.15, 0.70, 0.20, 1.00))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.98, 0.26, 0.26, 0.40))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.98, 0.26, 0.26, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.98, 0.08, 0.08, 1.00))
    end
    local pressed = imgui.Button(label, size)
    imgui.PopStyleColor(3)
    return pressed
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local c = style.Colors
    style.WindowPadding = imgui.ImVec2(8, 8)
    style.FramePadding = imgui.ImVec2(6, 6)
    style.ItemSpacing = imgui.ImVec2(7, 6)
    style.WindowRounding = 10
    style.FrameRounding = 8
    style.ChildRounding = 8
    style.ScrollbarRounding = 8
    style.GrabRounding = 8
    c[imgui.Col.WindowBg] = imgui.ImVec4(0.07, 0.08, 0.11, 0.97)
    c[imgui.Col.ChildBg] = imgui.ImVec4(0.10, 0.11, 0.15, 0.94)
    c[imgui.Col.Border] = imgui.ImVec4(0.28, 0.40, 0.65, 0.35)
    c[imgui.Col.Button] = imgui.ImVec4(0.20, 0.28, 0.42, 0.80)
    c[imgui.Col.ButtonHovered] = imgui.ImVec4(0.24, 0.40, 0.64, 0.95)
    c[imgui.Col.ButtonActive] = imgui.ImVec4(0.18, 0.52, 0.86, 0.98)
    c[imgui.Col.Header] = imgui.ImVec4(0.20, 0.34, 0.58, 0.70)
    c[imgui.Col.HeaderHovered] = imgui.ImVec4(0.25, 0.46, 0.76, 0.90)
    c[imgui.Col.HeaderActive] = imgui.ImVec4(0.17, 0.52, 0.90, 1.00)
    c[imgui.Col.Separator] = imgui.ImVec4(0.24, 0.37, 0.60, 0.45)
end)

local function draw_nav_button(id, title, subtitle)
    local active = cfg.ui.active_section == id
    if active then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.56, 0.94, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.66, 1.00, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.16, 0.50, 0.86, 1.00))
    end
    local pressed = imgui.Button(u8(title .. '##nav_' .. id), imgui.ImVec2(158, 30))
    if active then imgui.PopStyleColor(3) end
    if pressed then cfg.ui.active_section = id end
    imgui.SetCursorPosY(imgui.GetCursorPosY() - 2)
    if active then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.75, 0.89, 1.00, 1.00))
    else
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.62, 0.70, 0.82, 0.95))
    end
    imgui.TextWrapped(u8(subtitle))
    imgui.PopStyleColor()
    imgui.Separator()
end

local buhoi_imgui_frame = {}
buhoi_imgui_frame.sub = imgui.OnFrame(function()
    local sub = buhoi_imgui_frame.sub
    if sub then
        sub.HideCursor = (not window[0]) and cfg.timer.enabled
    end
    return window[0] or cfg.timer.enabled
end, function()
    draw_timer_overlay()
    if not window[0] then return end
    imgui.SetNextWindowSize(imgui.ImVec2(800, 580), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'##BuhoiMenu', window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)

    local tint = 0.5 + 0.5 * math.sin(os.clock() * 1.6)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.58 + 0.22 * tint, 0.82 + 0.14 * tint, 1.00, 1.00))
    imgui.Text(u8'Buhoi Menu')
    imgui.PopStyleColor()
    imgui.SameLine()
    imgui.TextDisabled(u8'| by Buhoi')
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetWindowWidth() - 28)
    if imgui.Button(u8'X##close_menu', imgui.ImVec2(20, 20)) then
        window[0] = false
    end
    imgui.Separator()

    if imgui.BeginChild('##sidebar', imgui.ImVec2(175, 0), true) then
        imgui.Text(u8'Разделы')
        imgui.Separator()
        draw_nav_button('main', 'Главная', 'Быстрый обзор и статус скрипта')
        draw_nav_button('online', 'Онлайн', 'Сессия, день и неделя по времени')
        draw_nav_button('climate', 'Климат', 'Время, погода и заморозка мира')
        draw_nav_button('notify', 'Уведомления', 'Discord и Telegram триггеры')
        draw_nav_button('autooff', 'OFFme', 'Автовыход, действия и сценарии')
        imgui.EndChild()
    end
    imgui.SameLine()
    if imgui.BeginChild('##content', imgui.ImVec2(0, 0), true) then

    if cfg.ui.active_section == 'main' then
        imgui.Text(u8'Команда: /buhoimenu')
        imgui.Text(u8('Сессия online: ' .. as_clock(online.session_online)))
        imgui.Text(u8('Сессия full: ' .. as_clock(online.session_full)))
        imgui.Text(u8('Режим уведомлений: ' .. cfg.notify.delivery_mode))
        imgui.Separator()
        imgui.Text(u8('Локальная версия: ' .. get_local_script_version()))
        imgui.Text(u8('Версия из GitHub: ' .. (updater.remote_version ~= '' and updater.remote_version or 'не проверена')))
        imgui.TextWrapped(u8('Статус: ' .. updater.status))
        if updater.busy then
            imgui.Text(u8'Операция выполняется...')
        else
            if imgui.Button(u8'Проверить обновление', imgui.ImVec2(230, 28)) then
                check_updates_chat_only()
            end
            imgui.SameLine()
            if imgui.Button(u8'Обновить', imgui.ImVec2(230, 28)) then
                run_script_update()
            end
        end
        if updater.update_info ~= '' then
            imgui.Separator()
            imgui.TextWrapped(u8('Что изменено: ' .. updater.update_info))
        end
    elseif cfg.ui.active_section == 'online' then
        imgui.Text(u8'TimerOnline')
        if imgui.BeginChild('##timer_left', imgui.ImVec2(250, 320), true) then
            if imgui.Checkbox(u8'Текущее дата и время', chk_timer_show_clock) then cfg.timer.show_clock = chk_timer_show_clock[0]; save_cfg() end
            if imgui.Checkbox(u8'Онлайн сессию', chk_timer_ses_online) then cfg.timer.ses_online = chk_timer_ses_online[0]; save_cfg() end
            if imgui.Checkbox(u8'AFK за сессию', chk_timer_ses_afk) then cfg.timer.ses_afk = chk_timer_ses_afk[0]; save_cfg() end
            if imgui.Checkbox(u8'Общий за сессию', chk_timer_ses_full) then cfg.timer.ses_full = chk_timer_ses_full[0]; save_cfg() end
            if imgui.Checkbox(u8'Онлайн за день', chk_timer_day_online) then cfg.timer.day_online = chk_timer_day_online[0]; save_cfg() end
            if imgui.Checkbox(u8'АФК за день', chk_timer_day_afk) then cfg.timer.day_afk = chk_timer_day_afk[0]; save_cfg() end
            if imgui.Checkbox(u8'Общий за день', chk_timer_day_full) then cfg.timer.day_full = chk_timer_day_full[0]; save_cfg() end
            if imgui.Checkbox(u8'Онлайн за неделю', chk_timer_week_online) then cfg.timer.week_online = chk_timer_week_online[0]; save_cfg() end
            if imgui.Checkbox(u8'АФК за неделю', chk_timer_week_afk) then cfg.timer.week_afk = chk_timer_week_afk[0]; save_cfg() end
            if imgui.Checkbox(u8'Общий за неделю', chk_timer_week_full) then cfg.timer.week_full = chk_timer_week_full[0]; save_cfg() end
            imgui.EndChild()
        end
        imgui.SameLine()
        if imgui.BeginChild('##timer_right', imgui.ImVec2(0, 320), true) then
            if imgui.Checkbox(u8'Включить таймер', chk_timer_enabled) then
                cfg.timer.enabled = chk_timer_enabled[0]
                save_cfg()
            end
            local pr = imgui.new.int(cfg.timer.round)
            if imgui.SliderInt(u8'Скругление', pr, 0, 16) then cfg.timer.round = pr[0]; save_cfg() end
            if imgui.Button(u8'Местоположение (SPACE сохранить)', imgui.ImVec2(-1, 24)) then
                pick_timer_position()
            end
            local ip, port = sampGetCurrentServerAddress()
            local cur = ip .. ':' .. tostring(port)
            if cfg.timer.server == cur then
                if imgui.Button(u8'Снять основной сервер', imgui.ImVec2(-1, 24)) then
                    cfg.timer.server = ''
                    save_cfg()
                end
            else
                if imgui.Button(u8'Сделать этот сервер основным', imgui.ImVec2(-1, 24)) then
                    cfg.timer.server = cur
                    save_cfg()
                end
            end
            imgui.TextWrapped(u8'Если сервер задан, таймер будет считаться только на нем.')
            imgui.EndChild()
        end
        imgui.Separator()
        imgui.Text(u8('Сессия online: ' .. as_clock(online.session_online)))
        imgui.Text(u8('Сессия afk: ' .. as_clock(online.session_afk)))
        imgui.Text(u8('Сессия full: ' .. as_clock(online.session_full)))
        imgui.Separator()
        imgui.Text(u8('День online: ' .. as_clock(online.day_online)))
        imgui.Text(u8('День afk: ' .. as_clock(online.day_afk)))
        imgui.Text(u8('День full: ' .. as_clock(online.day_full)))
        imgui.Separator()
        imgui.Text(u8('Неделя online: ' .. as_clock(online.week_online)))
        imgui.Text(u8('Неделя afk: ' .. as_clock(online.week_afk)))
        imgui.Text(u8('Неделя full: ' .. as_clock(online.week_full)))
        imgui.Separator()
        imgui.Text(u8('По дням недели (Пн-Вс):'))
        for i = 1, 7 do
            local is_today = (i == get_weekday_index())
            if is_today then
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.30, 0.85, 0.35, 1.00))
            end
            imgui.Text(u8(('%s | Online: %s | AFK: %s | Full: %s'):format(
                weekdays_ru[i],
                as_clock(online.week_days_online[i]),
                as_clock(online.week_days_afk[i]),
                as_clock(online.week_days_full[i])
            )))
            if is_today then
                imgui.PopStyleColor()
            end
        end
    elseif cfg.ui.active_section == 'climate' then
        imgui.Text(u8'Управление временем и погодой')
        local t = imgui.new.int(cfg.climate.time_value)
        local w = imgui.new.int(cfg.climate.weather_value)
        if imgui.SliderInt(u8'Час', t, 0, 23) then
            cfg.climate.time_value = t[0]
            set_time(cfg.climate.time_value)
        end
        if imgui.SliderInt(u8'Погода', w, 0, 45) then
            cfg.climate.weather_value = w[0]
            set_weather(cfg.climate.weather_value)
        end
        if imgui.Checkbox(u8'Заморозить время', chk_climate_lock_time) then
            cfg.climate.lock_time = chk_climate_lock_time[0]
            save_cfg()
        end
        if imgui.Checkbox(u8'Заморозить погоду', chk_climate_lock_weather) then
            cfg.climate.lock_weather = chk_climate_lock_weather[0]
            save_cfg()
        end
        if imgui.Button(u8'Сохранить климат') then save_cfg() end
    elseif cfg.ui.active_section == 'notify' then
        imgui.Text(u8'Discord / Telegram уведомления')
        if imgui.Checkbox(u8'Включено', chk_notify_enabled) then
            cfg.notify.enabled = chk_notify_enabled[0]
            save_cfg()
        end
        imgui.Text(u8'Режим:')
        imgui.SameLine()
        if imgui.Button(u8(cfg.notify.delivery_mode .. '##mode')) then
            if cfg.notify.delivery_mode == 'discord' then
                cfg.notify.delivery_mode = 'telegram'
            elseif cfg.notify.delivery_mode == 'telegram' then
                cfg.notify.delivery_mode = 'both'
            else
                cfg.notify.delivery_mode = 'discord'
            end
            save_cfg()
        end

        local cred_w = imgui.GetContentRegionAvail().x / 1.75
        imgui.PushItemWidth(cred_w)
        if imgui.InputText(u8'Webhook', webhook_input, 2048) then
            cfg.notify.webhook = u8:decode(ffi.string(webhook_input))
            save_cfg()
        end
        if imgui.InputText(u8'TG token', tg_token_input, 512) then
            cfg.notify.telegram_bot_token = u8:decode(ffi.string(tg_token_input))
            save_cfg()
        end
        if imgui.InputText(u8'TG chat id', tg_chat_input, 256) then
            cfg.notify.telegram_chat_id = u8:decode(ffi.string(tg_chat_input))
            save_cfg()
        end
        imgui.PopItemWidth()
        imgui.Separator()
        imgui.TextWrapped(u8'Банковские взаимодействия: отдельный webhook/Telegram. Отмечайте типы сообщений — они уходят только в канал ниже, не в общий.')
        if imgui.Checkbox(u8'Банковские уведомления', chk_notify_bank_enabled) then
            cfg.notify.bank.enabled = chk_notify_bank_enabled[0]
            save_cfg()
        end
        if imgui.BeginChild('##bank_events', imgui.ImVec2(0, 168), true) then
            for _, def in ipairs(BANK_EVENT_DEFS) do
                local chk = bank_event_chks[def.id]
                if chk and imgui.Checkbox(u8(def.label .. '##' .. def.id), chk) then
                    cfg.notify.bank.events[def.id] = chk[0]
                    save_cfg()
                end
            end
            imgui.EndChild()
        end
        imgui.Text(u8'Куда слать банк (отдельно от фраз):')
        imgui.SameLine()
        if imgui.Button(u8((cfg.notify.bank.delivery_mode or 'discord') .. '##bank_mode')) then
            if cfg.notify.bank.delivery_mode == 'discord' then
                cfg.notify.bank.delivery_mode = 'telegram'
            elseif cfg.notify.bank.delivery_mode == 'telegram' then
                cfg.notify.bank.delivery_mode = 'both'
            else
                cfg.notify.bank.delivery_mode = 'discord'
            end
            save_cfg()
        end
        local bank_w = imgui.GetContentRegionAvail().x / 1.75
        imgui.PushItemWidth(bank_w)
        if imgui.InputText(u8'Банк: Webhook', bank_webhook_input, 2048) then
            cfg.notify.bank.webhook = u8:decode(ffi.string(bank_webhook_input))
            save_cfg()
        end
        if imgui.InputText(u8'Банк: TG token', bank_tg_token_input, 512) then
            cfg.notify.bank.telegram_bot_token = u8:decode(ffi.string(bank_tg_token_input))
            save_cfg()
        end
        if imgui.InputText(u8'Банк: TG chat id', bank_tg_chat_input, 256) then
            cfg.notify.bank.telegram_chat_id = u8:decode(ffi.string(bank_tg_chat_input))
            save_cfg()
        end
        imgui.PopItemWidth()
        imgui.Separator()
        if imgui.InputText(u8'Новая фраза', phrase_input, 256) then end
        if imgui.Button(u8'Добавить фразу') then
            local phrase = u8:decode(ffi.string(phrase_input))
            if phrase ~= '' then
                table.insert(cfg.notify.phrases, phrase)
                phrase_input = imgui.new.char[256]('')
                save_cfg()
            end
        end
        for i, phrase in ipairs(cfg.notify.phrases) do
            imgui.Text(u8(phrase))
            imgui.SameLine()
            if imgui.Button(u8('Удалить##p' .. i)) then
                table.remove(cfg.notify.phrases, i)
                save_cfg()
                break
            end
        end
    elseif cfg.ui.active_section == 'autooff' then
        imgui.Text(u8'OFFme')

        local offme_child_flags = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
        if imgui.BeginChild('##when_col', imgui.ImVec2(242, 214), true, offme_child_flags) then
            imgui.SetCursorPosX(95)
            imgui.Text(u8'Когда')
            imgui.Separator()
            if colored_select_button(u8'Через время##w1', cfg.autooff.when_mode == 1, imgui.ImVec2(230, 24)) then cfg.autooff.when_mode = pick_mode(cfg.autooff.when_mode, 1); save_cfg() end
            if colored_select_button(u8'В опред. время##w2', cfg.autooff.when_mode == 2, imgui.ImVec2(230, 24)) then cfg.autooff.when_mode = pick_mode(cfg.autooff.when_mode, 2); save_cfg() end
            if colored_select_button(u8'После ПейДея##w3', cfg.autooff.when_mode == 3, imgui.ImVec2(230, 24)) then cfg.autooff.when_mode = pick_mode(cfg.autooff.when_mode, 3); save_cfg() end
            if colored_select_button(u8'После опред. сообщения в чат##w4', cfg.autooff.when_mode == 4, imgui.ImVec2(230, 24)) then cfg.autooff.when_mode = pick_mode(cfg.autooff.when_mode, 4); save_cfg() end
            if colored_select_button(u8'При потере соединения с сервером##w5', cfg.autooff.when_mode == 5, imgui.ImVec2(230, 24)) then cfg.autooff.when_mode = pick_mode(cfg.autooff.when_mode, 5); save_cfg() end
            if colored_select_button(u8'При опред. игроке в зоне стрима##w6', cfg.autooff.when_mode == 6, imgui.ImVec2(230, 24)) then cfg.autooff.when_mode = pick_mode(cfg.autooff.when_mode, 6); save_cfg() end
            imgui.EndChild()
        end
        imgui.SameLine()
        if imgui.BeginChild('##what_col', imgui.ImVec2(242, 214), true, offme_child_flags) then
            imgui.SetCursorPosX(70)
            imgui.Text(u8'Что сделать')
            imgui.Separator()
            if colored_select_button(u8'Выключить ПК##a1', cfg.autooff.what_mode == 1, imgui.ImVec2(230, 24)) then cfg.autooff.what_mode = pick_mode(cfg.autooff.what_mode, 1); save_cfg() end
            if colored_select_button(u8'Выйти из игры##a2', cfg.autooff.what_mode == 2, imgui.ImVec2(230, 24)) then cfg.autooff.what_mode = pick_mode(cfg.autooff.what_mode, 2); save_cfg() end
            if colored_select_button(u8'Крашнуть игру##a3', cfg.autooff.what_mode == 3, imgui.ImVec2(230, 24)) then cfg.autooff.what_mode = pick_mode(cfg.autooff.what_mode, 3); save_cfg() end
            if colored_select_button(u8'Написать в чат (видно всем)##a4', cfg.autooff.what_mode == 4, imgui.ImVec2(230, 24)) then cfg.autooff.what_mode = pick_mode(cfg.autooff.what_mode, 4); save_cfg() end
            if colored_select_button(u8'Уведомление в чат (видно только вам)##a5', cfg.autooff.what_mode == 5, imgui.ImVec2(230, 24)) then cfg.autooff.what_mode = pick_mode(cfg.autooff.what_mode, 5); save_cfg() end
            if colored_select_button(u8'Перезайти на сервер##a6', cfg.autooff.what_mode == 6, imgui.ImVec2(230, 24)) then cfg.autooff.what_mode = pick_mode(cfg.autooff.what_mode, 6); save_cfg() end
            imgui.EndChild()
        end

        imgui.Separator()
        if cfg.autooff.when_mode == 1 or cfg.autooff.when_mode == 2 then
            local h = imgui.new.int(cfg.autooff.hour)
            local m = imgui.new.int(cfg.autooff.min)
            local s = imgui.new.int(cfg.autooff.sec)
            imgui.Text(u8'Настройки времени')
            imgui.Separator()
            if imgui.SliderInt(u8'Часы', h, 0, 23) then cfg.autooff.hour = h[0]; save_cfg() end
            if imgui.SliderInt(u8'Минуты', m, 0, 59) then cfg.autooff.min = m[0]; save_cfg() end
            if imgui.SliderInt(u8'Секунды', s, 0, 59) then cfg.autooff.sec = s[0]; save_cfg() end
            if imgui.Button(u8'Сброс времени', imgui.ImVec2(230, 24)) then
                cfg.autooff.hour = 0
                cfg.autooff.min = 0
                cfg.autooff.sec = 0
                save_cfg()
            end
        end
        if cfg.autooff.when_mode == 4 or cfg.autooff.when_mode == 6 then
            imgui.Text(cfg.autooff.when_mode == 6 and u8'Введите ник' or u8'Введите сообщение')
            imgui.Separator()
            if imgui.InputText(u8'##textt', find_text_input, 512) then
                cfg.autooff.find_text = u8:decode(ffi.string(find_text_input))
                cfg.autooff.find_nick = cfg.autooff.find_text
                save_cfg()
            end
            imgui.Separator()
            imgui.TextWrapped(cfg.autooff.when_mode == 6 and u8'Введите ник формата:\nNick_Name' or u8'Функция чувствительна к регистру\n\nВ случае большого текста, рекомендуется применять регулярки')
        end
        if cfg.autooff.what_mode == 4 or cfg.autooff.what_mode == 5 then
            imgui.Text(u8'Введите текст')
            if imgui.InputText(u8'##texttt', auto_text_input, 512) then
                cfg.autooff.text = u8:decode(ffi.string(auto_text_input))
                save_cfg()
            end
        end

        if cfg.autooff.what_mode == 4 or cfg.autooff.what_mode == 5 then
            if imgui.Button(cfg.autooff.repeat_enabled and u8'Повтор: ВКЛ' or u8'Повтор: ВЫКЛ', imgui.ImVec2(120, 24)) then
                cfg.autooff.repeat_enabled = not cfg.autooff.repeat_enabled
                save_cfg()
            end
        else
            if cfg.autooff.repeat_enabled then
                cfg.autooff.repeat_enabled = false
                save_cfg()
            end
        end
        if cfg.autooff.repeat_enabled and (cfg.autooff.what_mode == 4 or cfg.autooff.what_mode == 5) then
            local rh = imgui.new.int(cfg.autooff.repeat_hour)
            local rm = imgui.new.int(cfg.autooff.repeat_min)
            local rs = imgui.new.int(cfg.autooff.repeat_sec)
            if imgui.SliderInt(u8'Часы', rh, 0, 23) then cfg.autooff.repeat_hour = rh[0]; save_cfg() end
            if imgui.SliderInt(u8'Минуты', rm, 0, 59) then cfg.autooff.repeat_min = rm[0]; save_cfg() end
            if imgui.SliderInt(u8'Секунды', rs, 0, 59) then cfg.autooff.repeat_sec = rs[0]; save_cfg() end
        end
        if imgui.Button(cfg.autooff.enabled and u8'Включено' or u8'Выключено', imgui.ImVec2(488, 24)) then
            cfg.autooff.enabled = not cfg.autooff.enabled
            autooff_fired = false
            auto_state.enabled_since = os.time()
            auto_state.next_allowed_ts = 0
            auto_state.msg_triggered = false
            auto_state.packet_triggered = false
            auto_state.nick_triggered = false
            save_cfg()
        end
    end

    imgui.EndChild()
    end
    imgui.End()
end)

local function update_online()
    while true do
        wait(1000)
        now_time = os.date('%H:%M:%S')
        local ip, port = sampGetCurrentServerAddress()
        local cur = ip .. ':' .. tostring(port)
        local server_ok = (cfg.timer.server == '' or cfg.timer.server == cur)
        if not server_ok then
            online.connect_time = online.connect_time + 1
            online.start_time = online.start_time + 1
            goto continue
        end
        if sampGetGamestate() == 3 then
            local day = get_weekday_index()
            online.session_online = online.session_online + 1
            online.session_full = os.time() - online.start_time
            online.session_afk = online.session_full - online.session_online
            online.day_online = online.day_online + 1
            online.day_full = online.day_full + 1
            online.day_afk = online.day_full - online.day_online
            online.week_online = online.week_online + 1
            online.week_full = online.week_full + 1
            online.week_afk = online.week_full - online.week_online
            online.week_days_online[day] = online.week_days_online[day] + 1
            online.week_days_full[day] = online.week_days_full[day] + 1
            online.week_days_afk[day] = online.week_days_full[day] - online.week_days_online[day]
            online.connect_time = 0
        else
            online.connect_time = online.connect_time + 1
            online.start_time = online.start_time + 1
        end
        ::continue::
    end
end

local function update_autooff()
    while true do
        wait(200)
        if cfg.autooff.enabled and cfg.autooff.when_mode > 0 and cfg.autooff.what_mode > 0 then
            local now = os.time()
            if now >= auto_state.next_allowed_ts then
                local triggered = false
                if cfg.autooff.when_mode == 1 then
                    local target = cfg.autooff.hour * 3600 + cfg.autooff.min * 60 + cfg.autooff.sec
                    triggered = target > 0 and (now - auto_state.enabled_since) >= target
                elseif cfg.autooff.when_mode == 2 then
                    local mark = os.date('%Y%m%d%H%M%S')
                    local h = tonumber(os.date('%H'))
                    local m = tonumber(os.date('%M'))
                    local s = tonumber(os.date('%S'))
                    triggered = (h == cfg.autooff.hour and m == cfg.autooff.min and s == cfg.autooff.sec and auto_state.last_clock_mark ~= mark)
                    if triggered then auto_state.last_clock_mark = mark end
                elseif cfg.autooff.when_mode == 3 then
                    local hour_mark = os.date('%Y%m%d%H')
                    local m = tonumber(os.date('%M'))
                    local s = tonumber(os.date('%S'))
                    triggered = (m == 1 and s == 0 and auto_state.last_hour_mark ~= hour_mark)
                    if triggered then auto_state.last_hour_mark = hour_mark end
                elseif cfg.autooff.when_mode == 4 then
                    triggered = auto_state.msg_triggered
                    auto_state.msg_triggered = false
                elseif cfg.autooff.when_mode == 5 then
                    triggered = auto_state.packet_triggered
                    auto_state.packet_triggered = false
                elseif cfg.autooff.when_mode == 6 then
                    triggered = auto_state.nick_triggered
                    auto_state.nick_triggered = false
                end

                if triggered then
                    run_autooff_action()
                    autooff_fired = true
                    if cfg.autooff.repeat_enabled then
                        local repeat_sec = cfg.autooff.repeat_hour * 3600 + cfg.autooff.repeat_min * 60 + cfg.autooff.repeat_sec
                        auto_state.next_allowed_ts = now + math.max(repeat_sec, 1)
                        auto_state.enabled_since = now
                    else
                        cfg.autooff.enabled = false
                        save_cfg()
                    end
                end
            end
        end
    end
end

function main()
    while not isSampLoaded() do wait(100) end
    while not isSampfuncsLoaded() do wait(100) end
    while not isSampAvailable() do wait(100) end
    load_cfg()
    init_inputs()
    auto_state.enabled_since = os.time()
    auto_state.next_allowed_ts = 0

    sampAddChatMessage('[BuhoiMenu] /buhoimenu — меню (команды через onSendCommand)', 0x00C8FF)

    lua_thread.create(update_online)
    lua_thread.create(update_autooff)

    while true do
        imgui.ShowCursor = window[0]
        imgui.Process = window[0] or cfg.timer.enabled
        wait(0)
    end
end
