local imgui = require('mimgui')
local util = require('util')

local M = {}

function M.section_title(text)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.80, 0.70, 0.95, 1.0))
    imgui.Text(util.u8(text))
    imgui.PopStyleColor()
    imgui.Separator()
end

function M.colored_select_button(label, selected, size)
    if selected then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.22, 0.72, 0.85))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55, 0.30, 0.82, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.62, 0.38, 0.90, 1.00))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.14, 0.10, 0.22, 0.80))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.22, 0.14, 0.34, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.18, 0.45, 0.95))
    end
    local pressed = imgui.Button(label, size)
    imgui.PopStyleColor(3)
    return pressed
end

function M.combo_delivery_mode(current)
    local modes, labels = { 'discord', 'telegram', 'both' }, { 'Discord', 'Telegram', 'Оба' }
    local idx = 1
    for i, m in ipairs(modes) do if m == current then idx = i break end end
    if imgui.BeginCombo(util.u8'Режим##delivery', util.u8(labels[idx])) then
        for i, m in ipairs(modes) do
            if imgui.Selectable(util.u8(labels[i]), idx == i) then return m end
        end
        imgui.EndCombo()
    end
    return nil
end

return M
