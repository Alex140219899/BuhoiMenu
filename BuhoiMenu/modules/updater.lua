local paths = require('paths')
local util = require('util')

local M = {}

M.UPDATE_MANIFEST_URL = 'https://raw.githubusercontent.com/Alex140219899/BuhoiMenu/main/BuhoiUpdate.json'
M.UPDATE_MANIFEST_URL_JS = 'https://cdn.jsdelivr.net/gh/Alex140219899/BuhoiMenu@main/BuhoiUpdate.json'
M.UPDATE_SCRIPT_URL_JS = 'https://cdn.jsdelivr.net/gh/Alex140219899/BuhoiMenu@main/BuhoiMenu.lua'
M.DATA_BASE_URL = 'https://raw.githubusercontent.com/Alex140219899/BuhoiMenu/main/BuhoiMenu/'
M.DATA_BASE_URL_JS = 'https://cdn.jsdelivr.net/gh/Alex140219899/BuhoiMenu@main/BuhoiMenu/'

M.state = {
    busy = false,
    need_script = false,
    need_data = false,
    remote_script_ver = '',
    remote_data_ver = '',
    changelog_script = '',
    changelog_data = '',
    script_url = '',
    data_base_url = '',
    data_files = {},
    status = 'Автообновление при запуске включено.',
    pending_check = false,
    pending_update = false,
    worker_started = false
}

local last_manifest_cache = nil

local function read_local_data_version()
    local f = io.open(paths.get_data_version_path(), 'r')
    if not f then return '' end
    local v = util.version_trim(f:read('*a') or '')
    f:close()
    return v
end

local function write_local_data_version(v)
    paths.ensure_data_dir()
    local f = io.open(paths.get_data_version_path(), 'w')
    if not f then return end
    f:write(tostring(v or ''))
    f:close()
end

local function download_url_to_file_sync(dest, url, timeout_sec)
    if type(downloadUrlToFile) ~= 'function' then return false end
    local ml = package.loaded['moonloader'] or require('moonloader')
    local st = ml.download_status
    local done, ok = false, false
    pcall(function()
        downloadUrlToFile(url, dest, function(_, status)
            if status == st.STATUS_ENDDOWNLOADDATA then done, ok = true, true
            elseif st.STATUS_ENDDOWNLOADERR and status == st.STATUS_ENDDOWNLOADERR then done, ok = true, false end
        end)
    end)
    local elapsed, limit = 0, math.floor((timeout_sec or 60) * 10)
    while not done and elapsed < limit do wait(100); elapsed = elapsed + 1 end
    return ok and util.file_exists(dest)
end

local function build_urls(jsdelivr_static, manifest_url, version_tag)
    local list = {}
    local base = util.version_trim(manifest_url)
    if base ~= '' then
        list[#list + 1] = base .. (base:find('?', 1, true) and '&' or '?') .. 'v=' .. util.version_trim(version_tag)
        list[#list + 1] = util.url_cache_bust(base)
        list[#list + 1] = base
    end
    local js = util.version_trim(jsdelivr_static)
    if js ~= '' then
        list[#list + 1] = js .. (js:find('?', 1, true) and '&' or '?') .. 'v=' .. util.version_trim(version_tag)
        list[#list + 1] = util.url_cache_bust(js)
        list[#list + 1] = js
    end
    local seen, out = {}, {}
    for _, u in ipairs(list) do
        if u ~= '' and not seen[u] then seen[u] = true; out[#out + 1] = u end
    end
    return out
end

local function fetch_update_manifest()
    local urls = build_urls(M.UPDATE_MANIFEST_URL_JS, M.UPDATE_MANIFEST_URL, '')
    if M.UPDATE_MANIFEST_URL:find('/main/', 1, true) then
        urls[#urls + 1] = util.url_cache_bust(M.UPDATE_MANIFEST_URL:gsub('/main/', '/master/', 1))
    end
    local last_err = ''
    for _, url in ipairs(urls) do
        local tmp = paths.get_tmp_manifest()
        if util.file_exists(tmp) then pcall(os.remove, tmp) end
        if download_url_to_file_sync(tmp, url, 45) then
            local f = io.open(tmp, 'r')
            if f then
                local raw = f:read('*a') or ''
                f:close()
                pcall(os.remove, tmp)
                local ok, data = pcall(decodeJson, raw)
                if ok and type(data) == 'table' and data.current_version then
                    last_manifest_cache = data
                    return data, nil
                end
                last_err = 'Ошибка разбора BuhoiUpdate.json'
            end
        end
    end
    if last_err == '' then last_err = 'Не удалось скачать BuhoiUpdate.json' end
    return nil, last_err
end

local function manifest_script_needs_update(m)
    return util.compare_versions(m.current_version, util.get_local_script_version()) > 0
end

local function manifest_data_needs_update(m)
    local remote = util.version_trim(m.data_version)
    if remote == '' then return false end
    local local_v = read_local_data_version()
    if local_v == '' then return true end
    return tonumber(remote) and tonumber(local_v) and tonumber(remote) > tonumber(local_v)
end

local function apply_manifest(m)
    if not m then return end
    M.state.need_script = manifest_script_needs_update(m)
    M.state.need_data = manifest_data_needs_update(m)
    M.state.remote_script_ver = util.version_trim(m.current_version)
    M.state.remote_data_ver = util.version_trim(m.data_version)
    M.state.changelog_script = type(m.update_info) == 'string' and m.update_info or ''
    M.state.changelog_data = type(m.data_info) == 'string' and m.data_info or ''
    M.state.script_url = type(m.update_url) == 'string' and m.update_url or ''
    M.state.data_base_url = type(m.data_base_url) == 'string' and m.data_base_url ~= '' and m.data_base_url or M.DATA_BASE_URL
    M.state.data_files = type(m.data_files) == 'table' and m.data_files or {}
end

local function try_reload_script()
    _G.BUHOIMENU_LOADED = nil
    pcall(function()
        local ts = thisScript and thisScript()
        if ts and type(ts.reload) == 'function' then ts:reload(); return end
    end)
    pcall(function()
        local ml = package.loaded['moonloader'] or require('moonloader')
        if ml and type(ml.reload_script) == 'function' and thisScript and thisScript().path then
            ml.reload_script(thisScript().path)
        end
    end)
    if type(reloadScript) == 'function' then pcall(reloadScript) end
end

function M.download_data_files(manifest, silent)
    manifest = manifest or last_manifest_cache
    if not manifest then return false, 'нет манифеста' end
    local files = type(manifest.data_files) == 'table' and manifest.data_files or M.state.data_files
    if #files == 0 then return false, 'список data_files пуст' end
    local base = type(manifest.data_base_url) == 'string' and manifest.data_base_url ~= '' and manifest.data_base_url or M.DATA_BASE_URL
    local ok_count = 0
    for _, rel in ipairs(files) do
        rel = tostring(rel):gsub('\\', '/')
        if rel ~= '' and not rel:find('%.%.') then
            local dest = paths.get_data_dir() .. '/' .. rel
            paths.ensure_dir_for_file(dest)
            local tmp = paths.get_tmp_data_file(rel)
            if util.file_exists(tmp) then pcall(os.remove, tmp) end
            local urls = build_urls(M.DATA_BASE_URL_JS .. rel, base .. rel, manifest.data_version or '')
            local dl_ok = false
            for _, url in ipairs(urls) do
                if download_url_to_file_sync(tmp, url, 90) then dl_ok = true; break end
            end
            if dl_ok then
                if util.copy_file(tmp, dest) then ok_count = ok_count + 1 end
                pcall(os.remove, tmp)
            end
        end
    end
    if ok_count > 0 and manifest.data_version then
        write_local_data_version(manifest.data_version)
    end
    if ok_count == #files then
        if not silent then util.chat_add_utf8('[BuhoiMenu] Модули обновлены (' .. ok_count .. ' файлов).', 0x66CCFF) end
        return true
    end
    return false, 'скачано ' .. ok_count .. ' из ' .. #files
end

local function download_script()
    local url = M.state.script_url
    if url == '' then
        util.chat_add_utf8('[BuhoiMenu] В манифесте нет update_url.', 0x66CCFF)
        return false
    end
    local sp = thisScript().path
    if not sp or sp == '' then return false end
    local tmp = paths.get_tmp_script()
    if util.file_exists(tmp) then pcall(os.remove, tmp) end
    local urls = build_urls(M.UPDATE_SCRIPT_URL_JS, url, M.state.remote_script_ver)
    local dl_ok = false
    for _, u in ipairs(urls) do
        if download_url_to_file_sync(tmp, u, 120) then dl_ok = true; break end
    end
    if not dl_ok then
        util.chat_add_utf8('[BuhoiMenu] Ошибка скачивания BuhoiMenu.lua', 0x66CCFF)
        return false
    end
    local fin = io.open(tmp, 'rb')
    if not fin then return false end
    local body = fin:read('*a') or ''
    fin:close()
    local target = tostring(sp)
    local fout = io.open(target, 'wb') or io.open(target:gsub('/', '\\'), 'wb')
    if not fout then
        util.chat_add_utf8('[BuhoiMenu] Не удалось записать BuhoiMenu.lua', 0x66CCFF)
        return false
    end
    fout:write(body)
    if fout.flush then pcall(fout.flush, fout) end
    fout:close()
    pcall(os.remove, tmp)
    util.chat_add_utf8('[BuhoiMenu] Обновлено до v' .. M.state.remote_script_ver .. '. Перезагружаем...', 0x66CCFF)
    if M.state.changelog_script ~= '' then
        util.chat_add_utf8('[BuhoiMenu] ' .. M.state.changelog_script, 0x66CCFF)
    end
    wait(900)
    try_reload_script()
    return true
end

function M.ensure_modules_present()
    local marker = paths.get_data_dir() .. '/init.lua'
    if util.file_exists(marker) then return true end
    local m, err = fetch_update_manifest()
    if not m then return false, err end
    return M.download_data_files(m, true)
end

function M.check_updates_chat_only()
    if M.state.busy or M.state.pending_check or M.state.pending_update then
        M.state.status = 'Подождите, операция уже выполняется.'
        return
    end
    M.state.pending_check = true
end

function M.run_github_update()
    if M.state.busy or M.state.pending_check or M.state.pending_update then
        M.state.status = 'Подождите, операция уже выполняется.'
        return
    end
    M.state.pending_update = true
end

function M.run_script_update()
    M.run_github_update()
end

local function do_check_updates()
    M.state.busy = true
    local m, err = fetch_update_manifest()
    if not m then
        M.state.status = 'Ошибка: ' .. tostring(err)
        util.chat_add_utf8('[BuhoiMenu] ' .. M.state.status, 0x66CCFF)
        M.state.busy = false
        return
    end
    apply_manifest(m)
    if not M.state.need_script and not M.state.need_data then
        M.state.status = 'Обновлений нет. У вас актуальная версия.'
        util.chat_add_utf8('[BuhoiMenu] ' .. M.state.status, 0x66CCFF)
    else
        if M.state.need_script then
            M.state.status = 'Доступно обновление скрипта: v' .. M.state.remote_script_ver
            util.chat_add_utf8('[BuhoiMenu] ' .. M.state.status, 0x66CCFF)
            if M.state.changelog_script ~= '' then util.chat_add_utf8('[BuhoiMenu] ' .. M.state.changelog_script, 0x66CCFF) end
        end
        if M.state.need_data then
            util.chat_add_utf8('[BuhoiMenu] Доступно обновление модулей (data v' .. M.state.remote_data_ver .. ').', 0x66CCFF)
            if M.state.changelog_data ~= '' then util.chat_add_utf8('[BuhoiMenu] ' .. M.state.changelog_data, 0x66CCFF) end
        end
    end
    M.state.busy = false
end

local function do_github_update()
    M.state.busy = true
    local m, err = fetch_update_manifest()
    if not m then
        M.state.status = 'Ошибка: ' .. tostring(err)
        util.chat_add_utf8('[BuhoiMenu] ' .. M.state.status, 0x66CCFF)
        M.state.busy = false
        return
    end
    apply_manifest(m)
    if not M.state.need_script and not M.state.need_data then
        M.state.status = 'Обновлений нет. У вас актуальная версия.'
        util.chat_add_utf8('[BuhoiMenu] ' .. M.state.status, 0x66CCFF)
        M.state.busy = false
        return
    end
    if M.state.need_data then
        M.download_data_files(m)
        M.state.need_data = false
        paths.init_package_path()
        package.loaded['init'] = nil
    end
    if M.state.need_script then
        download_script()
    end
    M.state.busy = false
end

function M.start_worker()
    if M.state.worker_started or not lua_thread or not lua_thread.create then return end
    M.state.worker_started = true
    lua_thread.create(function()
        wait(500)
        while true do
            wait(200)
            if not M.state.busy then
                if M.state.pending_check then
                    M.state.pending_check = false
                    pcall(do_check_updates)
                elseif M.state.pending_update then
                    M.state.pending_update = false
                    pcall(do_github_update)
                end
            end
        end
    end)
end

return M
