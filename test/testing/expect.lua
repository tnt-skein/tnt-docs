--- Утверждения об ответе: код, заголовок, тип содержимого, тело, JSON
--- по пути, кусок разметки, перенаправление.
---
--- Ответ приложения — таблица `{ status, headers, body }`, и проверять её
--- полями руками значит писать в каждой проверке одно и то же:
--- `t.assert_equals(answer.status, 200)`, `t.assert_equals(answer.headers
--- ['content-type'], …)`, разбор тела `json.decode` с `pcall`. Здесь это
--- сказано один раз, а отказ называет запрос, на который отвечали, —
--- иначе в наборе из двух десятков проверок «expected 200, got 404»
--- не говорит ничего.
---
---     local page = client.get('/about')
---
---     page.status(200).content_type('html').sees('<h1>О приложении</h1>')
---
--- Утверждения возвращают себя же: проверка ответа читается одной
--- строкой, а не столбиком из пяти.

local json = require('json')
local t = require('luatest')

local Module = {}

--- Короткие имена типов содержимого: то, чем подписывает ответы роутер.
---
--- Именем, а не строкой целиком: `charset` в подписи обязателен —
--- без него браузер читает JSON в кодировке страницы, — и переписывать
--- его в каждой проверке значит однажды написать иначе и не заметить.
Module.TYPES = {
    json = 'application/json; charset=utf-8',
    text = 'text/plain; charset=utf-8',
    html = 'text/html; charset=utf-8',
}

--- С какого кода ответ считается перенаправлением и по какой.
---
--- Весь класс 3xx, а не перечень: 303 после формы, 307 и 308 с
--- сохранением способа — такие же перенаправления, как 302, и проверка
--- с перечнем отвергала бы их по незнанию.
Module.MOVED_FROM = 300
Module.MOVED_TO = 399

--- Значение заголовка ответа.
---
--- Имя приводится к нижнему регистру: роутер хранит заголовки так, и
--- проверка, написавшая `Content-Type`, не должна получать пустоту.
---@param response table
---@param name string
---@return any
local function header_of(response, name)
    return (response.headers or {})[tostring(name):lower()]
end

--- Значение по пути вида `data.items.1.name`.
---
--- Участок пробуется и строкой, и числом: в JSON список приезжает
--- таблицей с числовыми ключами, а путь пишется одной строкой.
---@param data any
---@param path string
---@return any
local function dug(data, path)
    local value = data

    for segment in (tostring(path) .. '.'):gmatch('([^%.]*)%.') do
        if type(value) ~= 'table' then
            return nil
        end

        local found = value[segment]

        if found == nil then
            found = value[tonumber(segment)]
        end

        value = found
    end

    return value
end

---@class TntTestingExpect Утверждения об одном ответе
---@field response table Ответ как есть: status, headers, body
---@field status fun(code: integer): TntTestingExpect Код ответа
---@field header fun(name: string, value: any|nil): TntTestingExpect Заголовок; без значения — что он есть
---@field content_type fun(kind: string): TntTestingExpect Тип содержимого: json, text, html либо строка целиком
---@field body fun(text: string): TntTestingExpect Тело целиком
---@field sees fun(fragment: string): TntTestingExpect Кусок разметки или текста в теле
---@field data fun(): any Тело, разобранное как JSON
---@field json fun(path: string, value: any): TntTestingExpect Значение в теле по пути `a.b.1`
---@field redirect fun(location: string, code: integer|nil): TntTestingExpect Перенаправление туда

--- Утверждения об ответе.
---
--- Второй аргумент — чем назвать ответ в отказе: клиент кладёт туда
--- «GET /about», и по отказу видно, какой из двух десятков запросов
--- ответил не так.
---@param response table Ответ `{ status, headers, body }`
---@param about string|nil Чем назвать ответ в отказе; по умолчанию «ответ»
---@return TntTestingExpect
function Module.of(response, about)
    if type(response) ~= 'table' then
        error(
            ('утверждать можно об ответе-таблице, а не о %s'):format(type(response))
        )
    end

    local named = about or 'ответ'
    local decoded
    local expect = {}

    expect.response = response

    function expect.status(code)
        t.assert_equals(response.status, code, ('%s: код ответа'):format(named))

        return expect
    end

    function expect.header(name, value)
        local got = header_of(response, name)

        if value == nil then
            t.assert_not_equals(got, nil, ('%s: заголовка %s нет'):format(named, name))

            return expect
        end

        t.assert_equals(got, value, ('%s: заголовок %s'):format(named, name))

        return expect
    end

    function expect.content_type(kind)
        return expect.header('content-type', Module.TYPES[kind] or kind)
    end

    function expect.body(text)
        t.assert_equals(response.body, text, ('%s: тело'):format(named))

        return expect
    end

    function expect.sees(fragment)
        t.assert_str_contains(
            tostring(response.body),
            fragment,
            false,
            ('%s: в теле нет «%s»'):format(named, fragment)
        )

        return expect
    end

    function expect.data()
        -- Разбирается один раз на ответ: проверка спрашивает по полю,
        -- а разбор мегабайтного тела на каждое поле — работа впустую.
        if decoded == nil then
            local ok, parsed = pcall(json.decode, tostring(response.body))

            if not ok then
                t.fail(('%s: тело не разобрано как JSON: %s'):format(named, tostring(parsed)))
            end

            decoded = { value = parsed }
        end

        return decoded.value
    end

    function expect.json(path, value)
        t.assert_equals(dug(expect.data(), path), value, ('%s: %s в теле'):format(named, path))

        return expect
    end

    function expect.redirect(location, code)
        if code ~= nil then
            expect.status(code)
        else
            local status = response.status

            t.assert(
                type(status) == 'number' and status >= Module.MOVED_FROM and status <= Module.MOVED_TO,
                ('%s: код %s — не перенаправление'):format(named, tostring(status))
            )
        end

        return expect.header('location', location)
    end

    return expect
end

return Module
