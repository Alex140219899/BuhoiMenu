local effil = require('effil')
local config = require('config')
local util = require('util')

local M = {}

local function async_http_request(method, url, args, resolve, reject)
    local request_thread = effil.thread(function(m, u, a, monet)
        local requests = require('requests')
        local payload = monet and effil.dump(a) or a
        local ok, response = pcall(requests.request, m, u, payload)
        if ok then response.json, response.xml = nil, nil; return true, response end
        return false, response
    end)(method, url, args, util.is_monet_loader())
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end
    lua_thread.create(function()
        while true do
            local status, err = request_thread:status()
            if err then return reject(err) end
            if status == 'completed' then
                local ok, resp = request_thread:get()
                return (ok and resolve or reject)(resp)
            elseif status == 'canceled' then return reject('canceled') end
            wait(0)
        end
    end)
end

local function send_discord(webhook, msg, color)
    if webhook == '' then return end
    local ok, data = pcall(encodeJson, {
        content = nil, embeds = { { description = msg, color = color or 16744062 } }, attachments = {}
    })
    if not ok then return end
    async_http_request('POST', webhook, { headers = { ['content-type'] = 'application/json' }, data = util.u8(data) })
end

local function send_telegram(token, chat_id, msg)
    if token == '' or chat_id == '' then return end
    local ok, data = pcall(encodeJson, { chat_id = chat_id, text = msg, disable_web_page_preview = true })
    if not ok then return end
    async_http_request('POST', 'https://api.telegram.org/bot' .. token .. '/sendMessage',
        { headers = { ['content-type'] = 'application/json' }, data = util.u8(data) })
end

function M.send_notify(msg)
    if not config.cfg.notify.enabled then return end
    local n = config.cfg.notify
    if n.delivery_mode == 'discord' or n.delivery_mode == 'both' then send_discord(n.webhook, msg) end
    if n.delivery_mode == 'telegram' or n.delivery_mode == 'both' then send_telegram(n.telegram_bot_token, n.telegram_chat_id, msg) end
end

function M.on_server_message(text)
    if not config.cfg.notify.enabled or #config.cfg.notify.phrases == 0 then return end
    local clean = text:gsub('{......}', '')
    for _, phrase in ipairs(config.cfg.notify.phrases) do
        if phrase ~= '' and text:find(phrase) then M.send_notify(clean); return end
    end
end

return M
