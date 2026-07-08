local imgui = require('mimgui')

local M = {}

function M.apply()
    local style = imgui.GetStyle()
    local c = style.Colors
    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(8, 6)
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.WindowRounding = 10
    style.ChildRounding = 8
    style.FrameRounding = 8
    style.PopupRounding = 8

    c[imgui.Col.Text] = imgui.ImVec4(0.95, 0.94, 0.98, 1.0)
    c[imgui.Col.WindowBg] = imgui.ImVec4(0.07, 0.06, 0.11, 0.94)
    c[imgui.Col.ChildBg] = imgui.ImVec4(0.10, 0.08, 0.15, 0.92)
    c[imgui.Col.Border] = imgui.ImVec4(0.28, 0.18, 0.42, 0.55)
    c[imgui.Col.FrameBg] = imgui.ImVec4(0.14, 0.10, 0.22, 0.95)
    c[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.20, 0.14, 0.32, 0.98)
    c[imgui.Col.Button] = imgui.ImVec4(0.45, 0.22, 0.72, 0.55)
    c[imgui.Col.ButtonHovered] = imgui.ImVec4(0.55, 0.30, 0.82, 0.75)
    c[imgui.Col.ButtonActive] = imgui.ImVec4(0.62, 0.38, 0.90, 0.90)
    c[imgui.Col.Header] = imgui.ImVec4(0.18, 0.12, 0.30, 0.90)
    c[imgui.Col.CheckMark] = imgui.ImVec4(0.75, 0.55, 1.00, 1.00)
    c[imgui.Col.Separator] = imgui.ImVec4(0.30, 0.20, 0.45, 0.50)
end

return M
