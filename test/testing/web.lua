--- Клиент проверок: запрос к маршрутам приложения без сокета.
---
--- Запрос у нас — таблица, и конвейер роутера зовётся напрямую
--- (`tnt.router`, `dispatch`). Поэтому проверка приложения не поднимает
--- ни порта, ни сервера: она пишет «GET /about» и смотрит на ответ.
--- Написанный руками, такой запрос всякий раз выходит чуть другим —
--- у одного заголовки заглавными, у другого нет `content-length`, у
--- третьего форма склеена без экранирования, — и проверки перестают
--- проверять одно и то же.
---
---     local client = testing.client(router, { sessions = manager })
---
---     client.login({ user = 42 })                       -- вход без формы
---     client.get('/customers/7').status(200).json('id', 7)
---     client.post('/customers', { form = { name = 'Аня' } }).redirect('/customers/7')
---
--- Куки клиент держит сам: ответ поставил — следующий запрос принёс.
--- Отбора по домену, пути и `Secure` здесь нет нарочно: у запроса из
--- проверки нет ни схемы, ни узла, и настоящий отбор (`tnt.cookie.jar`)
--- отсеял бы все куки приложения — они ставятся с `Secure`. Срок куки
--- меряется стенными часами: дату сервер называет датой, и мерять её
--- нечем другим, а «сейчас» приходит как внешняя зависимость — проверке нужна граница.

local json = require('json')

local cookies = require('tnt.cookie.parse')
local request_of = require('tnt.router.request')
local external = require('tnt.external')

local expect = require('tnt.testing.expect')

local Module = {}

--- Средство снаружи: стенные часы для срока куки.
---
--- Срок сервер называет датой, и мерять его нечем, кроме такой же даты.
--- Внешней зависимостью — чтобы проверка могла назначить «сейчас» и увидеть границу:
--- кука, кончающаяся ровно в этот миг, уже не отправляется.
local source = external.install(Module, { now = os.time })

--- Способы, у которых свой вызов.
---
--- Кладутся в клиент перебором, а не по одной функции на способ: разница
--- между ними — одно слово, и написанные по отдельности они разъехались
--- бы на первой же правке сборки запроса.
Module.METHODS = { 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS' }

--- Чем клиент подписывает тело, собранное им самим.
Module.JSON_TYPE = 'application/json; charset=utf-8'
Module.FORM_TYPE = 'application/x-www-form-urlencoded'

--- Поля таблицей в строку запроса — тем же сборщиком, что у роутера.
---
--- Свой сборщик разошёлся бы с разбором на первом же знаке: пробел,
--- кириллица и «+» в значении кодируются не как придётся, а так, как их
--- потом прочтёт приложение. Отсюда же и порядок полей по именам: без
--- него один и тот же набор даёт разные адреса от запуска к запуску,
--- а по адресу сверяют ответ и запись в журнале.
local encoded = request_of.build_query

--- Запрос в том виде, в каком его принимает `http.server`.
---
--- Нужен там, где приложение собрано ядром: роутер там подключён
--- к серверу, и весь разбор тела — пределы, срок, форма — живёт
--- в подключении. Сокета при этом всё равно нет: тело отдаётся из
--- строки, а не из соединения.
---
--- Чтение идёт дальше с того места, где кончилось прежнее, как из
--- сокета: многочастное тело роутер читает кусками, и форма с файлом
--- больше куска, отданная каждый раз с начала, приходила бы ему
--- испорченной. Прочитанное целиком отвечает пустой строкой — так
--- отвечает и сокет, которому больше нечего отдать.
---@param httpd table Сервер с обработчиком в `options.handler`
---@return fun(input: table): table
local function through_server(httpd)
    return function(input)
        local body = input.body or ''
        local taken = 0

        return httpd.options.handler(httpd, {
            method = input.method,
            path_raw = input.path,
            path = input.path,
            query = input.query,
            headers = input.headers,
            read = function(_, length)
                local part = body:sub(taken + 1, taken + length)

                taken = taken + #part

                return part
            end,
        })
    end
end

--- Куда клиент относит запрос.
---
--- Три вида: роутер (`dispatch`), сервер, к которому роутер подключён
--- (`options.handler`), и своя функция — ею подставляют узел, на котором
--- поднято приложение. Незнакомое — ошибка проверки, а не отказ: клиенту,
--- которому не дали куда ходить, отвечать нечем.
---@param target any
---@return fun(input: table): table
local function dispatcher_of(target)
    if type(target) == 'function' then
        return target
    end

    if type(target) == 'table' then
        if type(target.dispatch) == 'function' then
            return target.dispatch
        end

        if type(target.options) == 'table' and type(target.options.handler) == 'function' then
            return through_server(target)
        end
    end

    error(
        'клиенту проверок нужен роутер, сервер http.server либо функция конвейера'
    )
end

--- Кончилась ли кука: так сервер просит её забыть.
---@param cookie table Разобранный `Set-Cookie`
---@return boolean
local function expired(cookie)
    if cookie.max_age ~= nil and cookie.max_age <= 0 then
        return true
    end

    return cookie.expires ~= nil and cookie.expires <= source().now()
end

--- Запоминает куки из ответа.
---
--- Значение бывает и списком: слой сессии не затирает чужой `Set-Cookie`,
--- а складывает их рядом.
---@param jar table<string, string>
---@param value any Значение заголовка `set-cookie`
local function remember(jar, value)
    if value == nil then
        return
    end

    local list = type(value) == 'table' and value or { value }

    for _, text in ipairs(list) do
        local cookie = cookies.set_cookie(text)

        -- Неразобранное пропускается молча, как у браузера: одна кривая
        -- кука не должна ронять проверку, которая её даже не просила.
        if cookie ~= nil then
            jar[cookie.name] = not expired(cookie) and cookie.value or nil
        end
    end
end

--- Значение заголовка `Cookie` из банки и кук самого запроса.
---@param jar table<string, string>
---@param extra table<string, any>|nil
---@return string|nil
local function carried(jar, extra)
    local sent = {}

    for name, value in pairs(jar) do
        sent[name] = value
    end

    for name, value in pairs(extra or {}) do
        sent[name] = value
    end

    local names = {}

    for name in pairs(sent) do
        table.insert(names, name)
    end

    table.sort(names)

    if names[1] == nil then
        return nil
    end

    local written = {}

    for _, name in ipairs(names) do
        table.insert(written, ('%s=%s'):format(name, sent[name]))
    end

    return table.concat(written, '; ')
end

---@class TntTestingClientOptions
---@field headers table<string, any>|nil Заголовки всех запросов клиента
---@field sessions TntSessionManager|nil Менеджер сессий — для входа под пользователем

---@class TntTestingRequest
---@field headers table<string, any>|nil Заголовки только этого запроса
---@field query table<string, any>|nil Поля строки запроса
---@field body string|table|nil Тело: строка как есть, таблица — JSON
---@field form table<string, any>|nil Поля формы браузера; с телом вместе не даются
---@field cookies table<string, any>|nil Куки только этого запроса

---@class TntTestingClient Клиент проверок
---@field get fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field post fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field put fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field patch fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field delete fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field head fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field options fun(path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field send fun(method: string, path: string, opts: TntTestingRequest|nil): TntTestingExpect
---@field header fun(name: string, value: any) Заголовок всех следующих запросов; пусто — убрать
---@field cookie fun(name: string, value: any) Кука в банке; пусто — убрать
---@field cookies fun(): table<string, string> Что лежит в банке
---@field forget fun() Забыть куки: это и есть выход
---@field login fun(values: table): TntSession Вход под пользователем без формы

--- Заводит клиент.
---@param target any Роутер, сервер `http.server` либо функция конвейера
---@param opts TntTestingClientOptions|nil
---@return TntTestingClient
function Module.new(target, opts)
    local settings = opts or {}
    local dispatch = dispatcher_of(target)
    local jar = {}
    local always = {}

    -- `any`, а не `table`: способы кладутся в клиент по имени из списка,
    -- и объявленного вида он набирает только к концу сборки.
    ---@type any
    local client = {}

    for name, value in pairs(settings.headers or {}) do
        always[tostring(name):lower()] = tostring(value)
    end

    --- Заголовки запроса: постоянные, поверх — свои, поверх — собранные.
    ---@param given TntTestingRequest
    ---@return table<string, string>
    local function headers_of(given)
        local headers = {}

        for name, value in pairs(always) do
            headers[name] = value
        end

        for name, value in pairs(given.headers or {}) do
            headers[tostring(name):lower()] = tostring(value)
        end

        return headers
    end

    --- Тело запроса и подпись к нему.
    ---
    --- Таблица в `body` — это JSON, `form` — форма браузера. Названная
    --- проверкой подпись остаётся: так проверяют, что приложение делает
    --- с телом, подписанным не так, как оно собрано.
    ---@param given TntTestingRequest
    ---@param headers table<string, string>
    ---@return string|nil
    local function body_of(given, headers)
        local body = given.body

        if given.form ~= nil then
            if body ~= nil then
                error('запросу дали и тело, и форму: что-то одно')
            end

            headers['content-type'] = headers['content-type'] or Module.FORM_TYPE
            body = encoded(given.form)
        elseif type(body) == 'table' then
            headers['content-type'] = headers['content-type'] or Module.JSON_TYPE
            body = json.encode(body)
        end

        if body ~= nil then
            -- Длину называет клиент, как назвал бы её браузер: без неё
            -- подключение роутера к серверу тела не читает вовсе.
            headers['content-length'] = headers['content-length'] or tostring(#body)
        end

        return body
    end

    function client.send(method, path, asked)
        local given = asked or {}
        local headers = headers_of(given)
        local body = body_of(given, headers)
        local cookie = carried(jar, given.cookies)

        if cookie ~= nil then
            headers['cookie'] = headers['cookie'] or cookie
        end

        local response = dispatch({
            method = method,
            path = path,
            query = given.query ~= nil and encoded(given.query) or '',
            headers = headers,
            body = body,
        })

        if type(response) ~= 'table' then
            error(('%s %s: конвейер вернул не ответ, а %s'):format(method, path, type(response)))
        end

        remember(jar, (response.headers or {})['set-cookie'])

        return expect.of(response, ('%s %s'):format(method, path))
    end

    function client.header(name, value)
        always[tostring(name):lower()] = value ~= nil and tostring(value) or nil
    end

    function client.cookie(name, value)
        jar[name] = value ~= nil and tostring(value) or nil
    end

    function client.cookies()
        local shown = {}

        for name, value in pairs(jar) do
            shown[name] = value
        end

        return shown
    end

    function client.forget()
        jar = {}
    end

    --- Вход под пользователем: сессия кладётся в хранилище, кука — в банку.
    ---
    --- Формы входа проверка не проходит: у неё свой пароль, своя вёрстка
    --- и свои отказы, и проверка страницы за входом не должна ломаться
    --- от правки формы. Пустая сессия никуда не пишется (`tnt.session`),
    --- поэтому значения обязательны: иначе вход прошёл бы молча и без куки.
    ---@param values table Что положить в сессию: например `{ user = 42 }`
    ---@return TntSession
    function client.login(values)
        if settings.sessions == nil then
            error(
                'вход под пользователем: клиенту нужен менеджер сессий — testing.client(…, { sessions = … })'
            )
        end

        if type(values) ~= 'table' or next(values) == nil then
            error(
                'вход под пользователем: скажите, что положить в сессию, например { user = 42 }'
            )
        end

        local session, err = settings.sessions:start(nil)

        if session == nil then
            error(
                ('вход под пользователем: сессия не заведена: %s'):format(
                    tostring(err)
                )
            )
        end

        for key, value in pairs(values) do
            session:put(key, value)
        end

        local header, broken = settings.sessions:commit(session)

        if header == nil then
            error(
                ('вход под пользователем: сессия не сохранена: %s'):format(
                    tostring(broken)
                )
            )
        end

        remember(jar, header)

        return session
    end

    for _, method in ipairs(Module.METHODS) do
        client[method:lower()] = function(path, asked)
            return client.send(method, path, asked)
        end
    end

    return client --[[@as TntTestingClient]]
end

return Module
