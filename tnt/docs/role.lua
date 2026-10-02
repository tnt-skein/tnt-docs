--- Роль раздела документации: свой сервер на своём порту.
---
---     roles: [tnt.docs.role]
---     roles_cfg:
---       tnt.docs.role:
---         listen: 127.0.0.1:8088
---         directory: docs
---         groups:
---           - { title: Начало, pages: [install, usage] }
---         hidden: [drafts]
---         options: app.docs     # модуль с настройками, которых не написать в YAML
---
--- Раздел — не часть приложения, а второй жилец узла, и порт у него
--- свой: подключение роутера подменяет обработчик сервера целиком,
--- и раздел на сервере приложения затёр бы его маршруты. Узлу роль
--- не нужна ни `box`, ни кластер: ядро зовёт её после подъёма, а она
--- читает разметку с диска.
---
--- Настройки раздела (`tnt.docs`) пишутся рядом с `listen` как есть.
--- Обратный вызов — карточку пакета — в YAML не написать, поэтому
--- `options` называет модуль приложения: его таблица ложится под
--- настройки из конфигурации, и написанное в конфигурации главнее.
---
--- Повторное применение с тем же `listen` подключает новый раздел
--- к прежнему серверу — порт не закрывается ни на миг; с другим `listen`
--- прежний сервер закрывается, и встаёт новый.

local server = require('http.server')

local docs = require('tnt.docs')
local settings = require('tnt.docs.settings')

local fail = require('tnt.must.fail').raise
local log = require('tnt.log').new('tnt.docs')

local role = {}

--- Узел, который слушает роль, когда `listen` — один порт: раздел
--- выходит в сеть только за обратным прокси.
role.HOST = '127.0.0.1'

--- Срок простоя соединения, секунд: без него соединение, шлющее
--- заголовки по байту, держало бы файбер бессрочно.
role.IDLE_TIMEOUT = 60

--- Наибольший номер порта.
local MAX_PORT = 65535

--- Ключи роли, которых у раздела нет.
---@type table<string, boolean>
local OWN = { listen = true, options = true }

---@class TntDocsRunning Поднятый сервер роли
---@field httpd table
---@field listen string

---@type TntDocsRunning|nil
local running = nil

--- Узел и порт из `listen`: порт числом либо строка `узел:порт`.
---@param listen any
---@return string|nil host
---@return any port Порт либо слово отказа
local function endpoint(listen)
    ---@type string|nil, any
    local host, port = role.HOST, listen

    if type(listen) == 'string' then
        host, port = listen:match('^(.*):(%d%d*)$')
        port = tonumber(port)
    end

    if type(port) ~= 'number' or port % 1 ~= 0 or port < 1 or port > MAX_PORT or host == '' then
        return nil,
            ('listen — порт от 1 до %d либо «узел:порт», а не %s'):format(
                MAX_PORT,
                tostring(listen)
            )
    end

    return host, port
end

--- Настройки раздела: таблица модуля `options`, поверх неё — конфигурация.
---@param cfg table
---@return TntDocsOptions
local function options_of(cfg)
    ---@type any
    local options = {}

    if cfg.options ~= nil then
        local ok, extra = pcall(require, cfg.options)

        if not ok or type(extra) ~= 'table' then
            fail(
                ('options — модуль с таблицей настроек раздела, а «%s» не загрузился в таблицу: %s'):format(
                    tostring(cfg.options),
                    tostring(extra)
                )
            )
        end

        for key, value in pairs(extra) do
            options[key] = value
        end
    end

    for key, value in pairs(cfg) do
        if not OWN[key] then
            options[key] = value
        end
    end

    return options
end

--- Отвергает настройки, которые нельзя применить.
---
--- Проверка отдельно от применения: конфигурация кластера одна на всех,
--- и узел, заметивший в ней ошибку раньше остальных, отказывает всей
--- раскатке. Отказ — словом без места: его читает оператор в alerts.
---@param cfg any
function role.validate(cfg)
    if type(cfg) ~= 'table' then
        fail(('роль tnt.docs.role настраивается таблицей, а не %s'):format(type(cfg)))
    end

    local host, problem = endpoint(cfg.listen)

    if host == nil then
        fail(problem)
    end

    local complaint = settings.explain(options_of(cfg))

    if complaint ~= nil then
        fail(complaint)
    end
end

--- Поднимает раздел на его порту.
---@param cfg table
function role.apply(cfg)
    role.validate(cfg)

    local host, port = endpoint(cfg.listen)
    local listen = ('%s:%d'):format(host, port)

    if running ~= nil and running.listen ~= listen then
        role.stop()
    end

    local fresh = running == nil

    if fresh then
        running = {
            httpd = server.new(host, port, {
                -- Строку запроса сервер иначе писал бы мимо журнала узла
                -- уровнем info.
                log_requests = false,
                idle_timeout = role.IDLE_TIMEOUT,
            }),
            listen = listen,
        }
    end

    ---@cast running TntDocsRunning
    docs.new(options_of(cfg)).attach(running.httpd)

    if fresh then
        running.httpd:start()
    end

    log.info('раздел документации слушает', { listen = listen, directory = cfg.directory })
end

--- Закрывает сервер роли.
function role.stop()
    if running ~= nil then
        running.httpd:stop()
        running = nil
    end
end

return role
