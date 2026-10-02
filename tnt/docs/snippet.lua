--- Отрывок текста раздела вокруг совпадения, с отметками.
---
--- Окно — целые куски текста (`tnt.docs.words`) вокруг первого куска
--- с ключом запроса: растёт по куску влево и вправо попеременно, пока
--- влезает в длину. Отмечается кусок целиком — слово с совпавшей основой
--- видно сразу, какой бы формы оно ни было: по запросу «шаблоны»
--- отмечается и «шаблон», и «шаблонами».
---
--- Совпадения в тексте может не быть: раздел нашёлся по заголовку. Тогда
--- отрывок — начало текста, без отметок.
---
--- Отрывок — HTML: текст экранирован, отметки вставлены как есть.
--- Переводы строк между блоками раздела становятся пробелами: отрывок
--- читается одной строкой выдачи.

local utf8 = require('utf8')

local template = require('tnt.template')

local Module = {}

--- Отметки совпадения.
Module.OPEN = '<mark>'
Module.CLOSE = '</mark>'

--- Знак пропуска на краю отрывка, когда текст идёт дальше.
Module.MORE = '…'

---@class TntDocsPiece Кусок текста в отрывке
---@field from integer
---@field to integer
---@field hit boolean Стоит ли в куске ключ запроса

--- Длина строки в знаках; битый UTF-8 меряется байтами.
---@param text string
---@return integer
local function size_of(text)
    return utf8.len(text) or #text
end

--- Куски текста и номер первого с совпадением.
---@param text string
---@param wanted table<string, boolean> Ключи запроса
---@param words TntDocsWords
---@return TntDocsPiece[] pieces
---@return integer|nil anchor
local function pieces_of(text, wanted, words)
    local pieces = {}
    local anchor = nil

    words:each(text, function(from, to, keys)
        local hit = false

        for _, key in ipairs(keys) do
            hit = hit or wanted[key] == true
        end

        table.insert(pieces, { from = from, to = to, hit = hit })
        anchor = anchor or (hit and #pieces or nil)
    end)

    return pieces, anchor
end

--- Границы окна: целые куски вокруг первого совпадения, пока влезают.
---@param text string
---@param pieces TntDocsPiece[]
---@param anchor integer
---@param length integer
---@return integer first
---@return integer last
local function window(text, pieces, anchor, length)
    local first, last = anchor, anchor

    --- Влезает ли кусок от первого до последнего.
    local function fits(from, to)
        return size_of(text:sub(pieces[from].from, pieces[to].to)) <= length
    end

    local grown = true

    while grown do
        grown = false

        if first > 1 and fits(first - 1, last) then
            first = first - 1
            grown = true
        end

        if last < #pieces and fits(first, last + 1) then
            last = last + 1
            grown = true
        end
    end

    return first, last
end

--- Промежуток между кусками одной строкой: пробелы сжаты в один.
---@param gap string
---@return string
local function spaced(gap)
    return template.escape((gap:gsub('%s+', ' ')))
end

--- Отрывок с отметками.
---@param text string Текст раздела
---@param wanted table<string, boolean> Ключи запроса
---@param words TntDocsWords
---@param length integer Сколько знаков в отрывке
---@return string
function Module.cut(text, wanted, words, length)
    local pieces, anchor = pieces_of(text, wanted, words)

    if pieces[1] == nil then
        return ''
    end

    local first, last = window(text, pieces, anchor or 1, length)
    local out = {}

    if first > 1 then
        local before = pieces[first - 1] --[[@as TntDocsPiece]]
        local opening = pieces[first] --[[@as TntDocsPiece]]
        -- Знак препинания перед окном — скобка, кавычка — остаётся при нём.
        local mark = text:sub(before.to + 1, opening.from - 1):match('%S*$') --[[@as string]]

        table.insert(out, Module.MORE .. spaced(mark))
    end

    for index = first, last do
        local piece = pieces[index] --[[@as TntDocsPiece]]
        local shown = template.escape(text:sub(piece.from, piece.to))

        if index > first then
            local previous = pieces[index - 1] --[[@as TntDocsPiece]]

            table.insert(out, spaced(text:sub(previous.to + 1, piece.from - 1)))
        end

        if piece.hit then
            shown = Module.OPEN .. shown .. Module.CLOSE
        end

        table.insert(out, shown)
    end

    -- Хвост окна — знак препинания за последним куском, без пробелов.
    local closing = pieces[last] --[[@as TntDocsPiece]]
    local after = pieces[last + 1]
    local tail = text:sub(closing.to + 1, after and after.from - 1 or #text):match('^%S*') --[[@as string]]

    table.insert(out, spaced(tail))

    if after ~= nil then
        table.insert(out, Module.MORE)
    end

    return table.concat(out)
end

return Module
