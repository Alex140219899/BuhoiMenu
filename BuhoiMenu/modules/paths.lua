local M = {}

M.DATA_DIR_NAME = 'BuhoiMenu'
M.data_dir_ready = false

function M.get_worked_dir()
    return (_G.BUHOI_WORKED_DIR or getWorkingDirectory()):gsub('\\', '/')
end

function M.get_data_dir()
    return (M.get_worked_dir() .. '/' .. M.DATA_DIR_NAME):gsub('\\', '/')
end

function M.ensure_data_dir()
    if M.data_dir_ready then return end
    M.data_dir_ready = true
    local d = M.get_data_dir()
    if type(createDirectory) == 'function' then
        pcall(createDirectory, d)
    else
        pcall(function()
            local ml = package.loaded['moonloader'] or require('moonloader')
            if ml and type(ml.createDirectory) == 'function' then
                ml.createDirectory(d)
            end
        end)
    end
end

function M.ensure_dir_for_file(path)
    M.ensure_data_dir()
    local rel = path:gsub('\\', '/'):match('/BuhoiMenu/(.+)$')
    if not rel then return end
    local sub = rel:match('^(.+)/[^/]+$')
    if not sub then return end
    local acc = M.get_data_dir()
    for part in sub:gmatch('[^/]+') do
        acc = acc .. '/' .. part
        if type(createDirectory) == 'function' then
            pcall(createDirectory, acc)
        end
    end
end

function M.init_package_path()
    M.ensure_data_dir()
    local base = M.get_data_dir() .. '/'
    package.path = base .. '?.lua;'
        .. base .. 'modules/?.lua;'
        .. base .. 'ui/?.lua;'
        .. base .. 'ui/sections/?.lua;'
        .. package.path
end

function M.get_cfg_path()
    M.ensure_data_dir()
    return M.get_data_dir() .. '/config.json'
end

function M.get_data_version_path()
    M.ensure_data_dir()
    return M.get_data_dir() .. '/.data_version'
end

function M.get_tmp_manifest()
    return M.get_worked_dir() .. '/.buhoi_manifest_tmp.json'
end

function M.get_tmp_script()
    return M.get_worked_dir() .. '/.buhoi_new.lua'
end

function M.get_tmp_data_file(name)
    return M.get_worked_dir() .. '/.buhoi_tmp_' .. (name or 'file'):gsub('[/\\]', '_')
end

return M
