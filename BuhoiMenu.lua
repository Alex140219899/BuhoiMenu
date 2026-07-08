script_name('BuhoiMenu')
script_author('Buhoi')
script_description('Unified menu: timer, climate, notify, auto off')
script_version('2.0.0')

--- Точка входа в moonloader/. Все модули и настройки — в moonloader/BuhoiMenu/ (как VigMenu/VigMenu).
local DATA_DIR_NAME = 'BuhoiMenu'

local function get_worked_dir()
    return getWorkingDirectory():gsub('\\', '/')
end

local function ensure_data_dir()
    local d = get_worked_dir() .. '/' .. DATA_DIR_NAME
    if type(createDirectory) == 'function' then
        pcall(createDirectory, d)
    else
        pcall(function()
            local ml = package.loaded['moonloader'] or require('moonloader')
            if ml and type(ml.createDirectory) == 'function' then ml.createDirectory(d) end
        end)
    end
    return d
end

local function setup_package_path()
    local base = ensure_data_dir() .. '/'
    package.path = base .. '?.lua;'
        .. base .. 'modules/?.lua;'
        .. base .. 'ui/?.lua;'
        .. base .. 'ui/sections/?.lua;'
        .. package.path
end

function main()
    while not isSampLoaded() do wait(100) end
    while not isSampfuncsLoaded() do wait(100) end
    while not isSampAvailable() do wait(100) end

    _G.BUHOI_WORKED_DIR = get_worked_dir()
    _G.BUHOI_DATA_DIR_NAME = DATA_DIR_NAME
    setup_package_path()

    local paths = require('paths')
    paths.init_package_path()

    local updater = require('updater')
    local ok_modules = updater.ensure_modules_present()
    if not ok_modules then
        print('[BuhoiMenu] Не удалось загрузить модули. Проверьте интернет и BuhoiUpdate.json')
        return
    end

    paths.init_package_path()
    require('init').run()
end
