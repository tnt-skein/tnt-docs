--- Поиск по разделам издания: запрос посетителя — попадания с отрывками.
---
---     local results, refusal = search.run(edition, 'шаблоны', 20)
---
---     results.items[1].title     --> 'Шаблоны страниц' — заголовок страницы
---     results.items[1].section   --> 'Каталог шаблонов' — раздел; у вступления пусто
---     results.items[1].url       --> '/docs/template#каталог-шаблонов'
---     results.items[1].snippet   --> '…<mark>шаблонов</mark> лежит…' — HTML
---     results.total              --> сколько разделов нашлось всего
---
--- Ищутся все слова запроса разом: раздел, где стоит одно слово из
--- двух, удивил бы каждого, кто набирал два. Не нашлось ничего — ищется
--- хоть одно слово, и выдача помечается `partial`: пустая страница
--- там, где слова по отдельности есть, хуже честной пометки.
---
--- Запрос приходит от посетителя, и его длина — предел: запрос длиннее
--- `QUERY_LENGTH` знаков — отказ 400. Длинный текст — это вставленный
--- по ошибке абзац, а не вопрос, и разбор его морфологией стоил бы узлу
--- времени на каждый запрос.

local utf8 = require('utf8')

local finders = require('tnt.docs.finder')
local snippet = require('tnt.docs.snippet')

local Module = {}

--- Предел длины запроса в знаках.
Module.QUERY_LENGTH = 200

--- Длина отрывка в знаках.
Module.SNIPPET = 180

---@class TntDocsResult Попадание в выдаче
---@field title string Заголовок страницы
---@field section string|nil Заголовок раздела; у вступления страницы пусто
---@field url string Адрес раздела
---@field snippet string Отрывок с отметками — HTML

---@class TntDocsResults Выдача
---@field query string Запрос без пробелов по краям
---@field items TntDocsResult[] Попадания по убыванию оценки
---@field total integer Сколько разделов нашлось всего
---@field partial boolean Нашлись не все слова запроса

--- Запрос из строки адреса: строка без пробелов по краям.
---
--- Повторённое поле (`?q=a&q=b`) приходит списком — такого запроса
--- форма поиска не шлёт, и он читается как пустой.
---@param value any
---@return string
function Module.text(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:strip()
end

--- Попадания по ключам: все ключи, а нет таких — хоть один.
---@param edition TntDocsEdition
---@param keys string[]
---@return TntDocsHit[] hits
---@return boolean partial
local function found(edition, keys)
    local hits = edition.finder:search(keys, finders.ALL)

    -- У запроса из одного слова второй поиск отдаст ту же пустоту:
    -- для одного ключа «все» и «хоть один» — одно и то же.
    if hits[1] == nil then
        hits = edition.finder:search(keys, finders.ANY)

        return hits, hits[1] ~= nil
    end

    return hits, false
end

--- Ищет разделы по запросу.
---@param edition TntDocsEdition
---@param query string Запрос без пробелов по краям (`text`)
---@param limit integer Сколько попаданий отдать
---@return TntDocsResults|nil results
---@return table|nil refusal Отказ 400: запрос длиннее предела
function Module.run(edition, query, limit)
    if (utf8.len(query) or #query) > Module.QUERY_LENGTH then
        return nil,
            { status = 400, message = ('запрос длиннее %d знаков'):format(Module.QUERY_LENGTH) }
    end

    local keys = edition.words:query(query)
    local hits, partial = found(edition, keys)
    local wanted = {}

    for _, key in ipairs(keys) do
        wanted[key] = true
    end

    -- Список, а не таблица: пустая выдача уходит в JSON массивом `[]`,
    -- а не объектом `{}`, и клиенту не надо различать два вида пустоты.
    local items = setmetatable({}, { __serialize = 'array' })
    local total = 0

    for _, hit in ipairs(hits) do
        -- Указатель общий у изданий, и пока собирается следующее, в нём
        -- бывают разделы, которых в этом издании ещё нет: их не показать.
        local place = edition.sections[hit.id]

        if place ~= nil then
            total = total + 1

            if total <= limit then
                table.insert(items, {
                    title = place.page.title,
                    section = place.section.anchor ~= '' and place.section.title or nil,
                    url = place.url,
                    snippet = snippet.cut(place.section.text, wanted, edition.words, Module.SNIPPET),
                })
            end
        end
    end

    return { query = query, items = items, total = total, partial = partial }
end

return Module
