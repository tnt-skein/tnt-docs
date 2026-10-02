--- Указатель раздела в памяти: разделы страниц по ключам слов.
---
--- Раздел — заголовок и текст под ним (`markdown.sections`). В указатель
--- он ложится двумя полями: ключи текста со счётом и ключи заголовка.
--- Указатель живёт в памяти процесса и строится заново на каждом подъёме:
--- источник правды — разметка на диске, и хранить второй экземпляр её
--- слов незачем.
---
--- **Оценка** — BM25 по тексту и прибавка за ключ в заголовке, обе
--- на обратную частоту ключа:
---
---     idf    = ln(1 + (N − df + 0,5) / (df + 0,5))
---     текст  = tf · (K1 + 1) / (tf + K1 · (1 − B + B · длина / средняя длина))
---     оценка = Σ по ключам запроса idf · (текст + TITLE, если ключ в заголовке)
---
--- Число вхождений насыщается: раздел, где слово стоит двадцать раз,
--- не впятеро ближе к запросу, чем раздел с четырьмя. Длина раздела
--- в счёт входит: в коротком разделе слово значит больше, чем в длинном.
--- Заголовок весит отдельно и много — раздел, названный словом запроса,
--- обычно и есть то, что ищут.
---
--- **Отбор** — `all`: в разделе обязаны стоять все ключи запроса (в тексте
--- либо в заголовке); `any` — хоть один. Порядок — по убыванию оценки,
--- при равной — по опознавателю: страница выдачи выглядит одинаково
--- от запроса к запросу.

local Module = {}

--- Насыщение числа вхождений.
Module.K1 = 1.2

--- Сколько длина раздела весит в оценке: 0 — нисколько, 1 — целиком.
Module.B = 0.75

--- Прибавка за ключ в заголовке раздела, в долях обратной частоты.
Module.TITLE = 2

--- Все ключи запроса либо хоть один.
Module.ALL = 'all'
Module.ANY = 'any'

---@class TntDocsHit Попадание: раздел и его оценка
---@field id string Опознаватель раздела
---@field score number Оценка: больше — ближе к запросу

---@class TntDocsFinder Указатель разделов
---@field words TntDocsWords
---@field body table<string, table<string, integer>> Ключ → раздел → сколько раз ключ в тексте
---@field heading table<string, table<string, boolean>> Ключ → разделы, где ключ в заголовке
---@field documents table<string, { keys: table<string, string>, length: integer }> Раздел → его ключи и длина текста
---@field count integer Сколько разделов
---@field length integer Сколько ключей во всех текстах
local Finder = {}
Finder.__index = Finder

--- Заводит пустой указатель.
---@param words TntDocsWords
---@return TntDocsFinder
function Module.new(words)
    return setmetatable({ words = words, body = {}, heading = {}, documents = {}, count = 0, length = 0 }, Finder)
end

--- Список разделов ключа; нет его — заводится.
---@param map table
---@param key string
---@return table
local function postings(map, key)
    local list = map[key]

    if list == nil then
        list = {}
        map[key] = list
    end

    return list
end

--- Убирает раздел из списка ключа, а пустой список — из указателя.
---@param map table
---@param key string
---@param id string
local function forget(map, key, id)
    local list = map[key]

    if list ~= nil then
        list[id] = nil

        if next(list) == nil then
            map[key] = nil
        end
    end
end

--- Убирает раздел из указателя; раздела нет — нечего и убирать.
---@param id string
function Finder:remove(id)
    local document = self.documents[id]

    if document == nil then
        return
    end

    for key in pairs(document.keys) do
        forget(self.body, key, id)
        forget(self.heading, key, id)
    end

    self.documents[id] = nil
    self.count = self.count - 1
    self.length = self.length - document.length
end

--- Кладёт раздел в указатель; прежний под тем же опознавателем уходит.
---@param id string
---@param title string Заголовок раздела
---@param text string Текст раздела
function Finder:put(id, title, text)
    self:remove(id)

    local body, length = self.words:counts(text)
    local heading = self.words:counts(title)
    -- Множество ключей раздела: значение — сам ключ, а не признак. Признак
    -- `true` здесь никто не читает, и его мутант `false` был бы неотличим.
    local keys = {}

    for key, count in pairs(body) do
        postings(self.body, key)[id] = count
        keys[key] = key
    end

    for key in pairs(heading) do
        postings(self.heading, key)[id] = true
        keys[key] = key
    end

    self.documents[id] = { keys = keys, length = length }
    self.count = self.count + 1
    self.length = self.length + length
end

--- Попадания по убыванию оценки, а при равной — по опознавателю.
---
--- Сортируются оценки сами по себе и опознаватели внутри одной оценки
--- сами по себе, оба раза сравнением по умолчанию. Функция сравнения
--- с двумя ключами сравнивала бы в ветке «оценки равны» заведомо разные
--- опознаватели, и `<` там от `<=` не отличить.
---@param scores table<string, number>
---@return TntDocsHit[]
local function ordered(scores)
    local groups, levels = {}, {}

    for id, score in pairs(scores) do
        local group = groups[score]

        if group == nil then
            group = {}
            groups[score] = group
            table.insert(levels, score)
        end

        table.insert(group, id)
    end

    table.sort(levels)

    local hits = {}

    for level = #levels, 1, -1 do
        local score = levels[level]
        local group = groups[score]

        table.sort(group)

        for _, id in ipairs(group) do
            table.insert(hits, { id = id, score = score })
        end
    end

    return hits
end

--- Разделы, где стоит ключ: в тексте либо в заголовке.
---@param body table<string, integer>
---@param heading table<string, boolean>
---@return string[]
local function holders(body, heading)
    local ids = {}

    for id in pairs(body) do
        table.insert(ids, id)
    end

    for id in pairs(heading) do
        if body[id] == nil then
            table.insert(ids, id)
        end
    end

    return ids
end

--- Вклад ключа текста в оценку раздела.
---@param self TntDocsFinder
---@param tf integer Сколько раз ключ стоит в тексте
---@param length integer Длина текста раздела в ключах
---@return number
local function weighed(self, tf, length)
    -- Ключа в тексте нет — нет и вклада. Без этой ветки свод из одних
    -- заголовков делил бы ноль на ноль средней длины.
    if tf == 0 then
        return 0
    end

    local average = self.length / self.count
    local norm = 1 - Module.B + Module.B * length / average

    return tf * (Module.K1 + 1) / (tf + Module.K1 * norm)
end

--- Разделы по ключам запроса.
---@param keys string[] Ключи запроса без повторов
---@param match string `all` либо `any`
---@return TntDocsHit[]
function Finder:search(keys, match)
    local scores, met = {}, {}

    for _, key in ipairs(keys) do
        local body, heading = self.body[key] or {}, self.heading[key] or {}
        local ids = holders(body, heading)
        local idf = math.log(1 + (self.count - #ids + 0.5) / (#ids + 0.5))

        for _, id in ipairs(ids) do
            local weight = weighed(self, body[id] or 0, self.documents[id].length)

            if heading[id] then
                weight = weight + Module.TITLE
            end

            scores[id] = (scores[id] or 0) + idf * weight
            met[id] = (met[id] or 0) + 1
        end
    end

    if match == Module.ALL then
        for id in pairs(met) do
            if met[id] < #keys then
                scores[id] = nil
            end
        end
    end

    return ordered(scores)
end

return Module
