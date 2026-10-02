--- Слова текста для указателя раздела: куски текста и их ключи.
---
--- Ключ — основа слова от `tnt-morphology` без стоп-слов: по запросу
--- «шаблоны» находится и «шаблон», и «шаблонов». Морфология разбирает
--- текст знак за знаком, и свод документов целиком она разбирала бы
--- секунды на каждом подъёме узла. Но слова в своде повторяются: из
--- шестисот тысяч кусков различных меньше ста тысяч, а слов — меньше
--- тридцати. Поэтому ключи помнятся: кусок разбирается на слова один раз,
--- слово приводится к основе один раз.
---
--- **Кусок** — текст между пробелами и знаками препинания ASCII.
--- Разбивает его образец, а не морфология: ему нужны места кусков в тексте,
--- по ним отрывок поиска ставит отметки. Внутри куска слова ищет уже
--- морфология — «шаблон—страница» с тире без пробелов даёт два ключа,
--- а отмечается кусок целиком.
---
--- Запрос посетителя помнить нельзя: память росла бы с каждым новым
--- запросом. Его ключи считаются заново, тем же правилом (`query`).

local morphology = require('tnt.morphology')

local Module = {}

--- Кусок текста с местом: начало, сам кусок и место за ним. Знак
--- и «ещё сколько-то» вместо `+`: у повтора `+` мутанты `*` и `-`
--- отдавали бы те же куски вместе с пустыми.
local PIECE = '()([^%s%p][^%s%p]*)()'

---@class TntDocsWords Ключи кусков текста с памятью о разобранном
---@field pieces table<string, string[]> Кусок → его ключи
---@field words table<string, string|false> Слово → ключ; `false` — стоп-слово
local Words = {}
Words.__index = Words

--- Заводит слова с пустой памятью.
---@return TntDocsWords
function Module.new()
    return setmetatable({ pieces = {}, words = {} }, Words)
end

--- Ключ слова; стоп-слово ключа не даёт.
---@param self TntDocsWords
---@param word string Слово, разобранное морфологией
---@param remember boolean
---@return string|false
local function key_of(self, word, remember)
    local key = self.words[word]

    if key == nil then
        key = morphology.tokens(word)[1] or false

        if remember then
            self.words[word] = key
        end
    end

    return key
end

--- Ключи куска по порядку слов в нём.
---@param piece string
---@param remember boolean|nil Запомнить разобранное: только для текста свода
---@return string[]
function Words:keys(piece, remember)
    local keys = self.pieces[piece]

    if keys ~= nil then
        return keys
    end

    keys = {}

    for _, word in ipairs(morphology.words(piece)) do
        local key = key_of(self, word, remember == true)

        if key then
            table.insert(keys, key)
        end
    end

    if remember then
        self.pieces[piece] = keys
    end

    return keys
end

--- Обходит куски текста: где кусок начинается, где кончается и его ключи.
---@param text string
---@param visit fun(from: integer, to: integer, keys: string[])
---@param remember boolean|nil
function Words:each(text, visit, remember)
    -- Места кусков образец отдаёт числами: это захваты `()`.
    local pieces = text:gmatch(PIECE) --[[@as fun(): integer, string, integer]]

    for from, piece, after in pieces do
        visit(from, after - 1, self:keys(piece, remember))
    end
end

--- Сколько раз стоит каждый ключ текста и сколько ключей в нём всего.
---
--- Текст — из свода, и разобранное запоминается.
---@param text string
---@return table<string, integer> counts
---@return integer total
function Words:counts(text)
    local counts, total = {}, 0

    self:each(text, function(_, _, keys)
        for _, key in ipairs(keys) do
            counts[key] = (counts[key] or 0) + 1
            total = total + 1
        end
    end, true)

    return counts, total
end

--- Ключи запроса без повторов, по порядку: повтор слова ничего не ищет.
---@param text string
---@return string[]
function Words:query(text)
    local seen, keys = {}, {}

    self:each(text, function(_, _, found)
        for _, key in ipairs(found) do
            if not seen[key] then
                seen[key] = true
                table.insert(keys, key)
            end
        end
    end)

    return keys
end

return Module
