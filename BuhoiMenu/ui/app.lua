local imgui = require('mimgui')
local config = require('config')
local util = require('util')
local theme = require('theme')

local section_main = require('sections/main')
local section_online = require('sections/online')
local section_climate = require('sections/climate')
local section_notify = require('sections/notify')
local section_autooff = require('sections/autooff')

local M = {}
M.window = imgui.new.bool(false)

local NAV = {
    { group = 'Основное', items = { { id = 'main', title = 'Главная' } } },
    { group = 'Игрок', items = { { id = 'online', title = 'Онлайн' }, { id = 'autooff', title = 'OFFme' } } },
    { group = 'Мир', items = { { id = 'climate', title = 'Климат' } } },
    { group = 'Связь', items = { { id = 'notify', title = 'Уведомления' } } },
}

local SECTIONS = {
    main = section_main.draw,
    online = section_online.draw,
    climate = section_climate.draw,
    notify = section_notify.draw,
    autooff = section_autooff.draw,
}

function M.init_inputs()
    section_online.init_inputs()
    section_climate.init_inputs()
    section_notify.init_inputs()
    section_autooff.init_inputs()
end

function M.setup()
    imgui.OnInitialize(function()
        imgui.GetIO().IniFilename = nil
        imgui.SwitchContext()
        theme.apply()
    end)

    local frame = {}
    frame.sub = imgui.OnFrame(function()
        local sub = frame.sub
        if sub then sub.HideCursor = (not M.window[0]) and config.cfg.timer.enabled end
        return M.window[0] or config.cfg.timer.enabled
    end, function()
        section_online.draw_timer_overlay()
        if not M.window[0] then return end

        imgui.SetNextWindowSize(imgui.ImVec2(860, 560), imgui.Cond.FirstUseEver)
        imgui.Begin(util.u8'Buhoi Menu##main', M.window,
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)

        imgui.Text(util.u8('Buhoi Menu v' .. util.get_local_script_version()))
        imgui.SameLine()
        imgui.SetCursorPosX(imgui.GetWindowWidth() - 30)
        if imgui.Button(util.u8'X##close', imgui.ImVec2(22, 22)) then M.window[0] = false end
        imgui.Separator()

        if imgui.BeginChild('##sidebar', imgui.ImVec2(170, 0), true) then
            for _, group in ipairs(NAV) do
                imgui.TextDisabled(util.u8(group.group))
                for _, item in ipairs(group.items) do
                    local active = config.cfg.ui.active_section == item.id
                    if active then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.22, 0.72, 0.90)) end
                    if imgui.Button(util.u8(item.title .. '##nav_' .. item.id), imgui.ImVec2(-1, 30)) then
                        config.cfg.ui.active_section = item.id
                    end
                    if active then imgui.PopStyleColor() end
                end
                imgui.Spacing()
            end
            imgui.EndChild()
        end

        imgui.SameLine()
        if imgui.BeginChild('##content', imgui.ImVec2(0, 0), true) then
            local draw_fn = SECTIONS[config.cfg.ui.active_section]
            if draw_fn then
                if config.cfg.ui.active_section == 'online' then draw_fn(M.window) else draw_fn() end
            end
            imgui.EndChild()
        end
        imgui.End()
    end)
end

return M
