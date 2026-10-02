--- Файл меню раздела: разделы и страницы по порядку чтения, с планом.
---
---     ## Основы
---
---     - [Маршруты](/docs/framework/routing)
---     - [Тело запроса](/docs/framework/uploads) {позже}
---     - [Генерация ссылок](/docs/framework/urls) {частично}
---
---     local groups, err = menu.parse(source, '/docs')
---
--- Раздел меню — заголовок второго уровня, страница — пункт списка
--- со ссылкой на её адрес. Уровней ровно два: читателю важно, о чём
--- страница, а не в каком каталоге лежит её файл.
---
--- Меню показывает весь план, а не только написанное: пункт, за которым
--- файла ещё нет, остаётся в меню и открывается заглушкой. Фигурные
--- скобки после ссылки — готовность **возможности**, о которой страница:
--- `{позже}` — её ещё нет, `{частично}` — есть не целиком, без метки —
--- есть. Незнакомая метка — отказ, а не «есть»: опечатка в меню иначе
--- молча соврала бы о готовности.
---
--- Разбирается то же дерево блоков, из которого рисуются страницы: своего
--- разбора разметки у меню нет, и лишняя строка в файле не становится
--- лишним пунктом. Пункт со ссылкой мимо раздела (внешний адрес, другой
--- раздел сайта) в меню не попадает: у меню раздела нет места для ссылок
--- наружу.

local markdown = require('tnt.markdown')

local Module = {}

--- Метка состояния в меню — ключ состояния страницы.
Module.MARKS = {
    ['позже'] = 'later',
    ['частично'] = 'partial',
}

--- Состояние пункта без метки.
Module.READY = 'ready'

--- Адрес страницы после начала раздела: имя либо свод и имя.
local SLUG = '^[%w_%-]+$'
local SECTIONED = '^[%w_%-]+/[%w_%-]+$'

--- Метка в хвосте пункта: слово в фигурных скобках.
local MARK = '{%s*([^}%s]+)%s*}'

---@class TntDocsMenuItem Пункт файла меню
---@field title string Название страницы
---@field slug string Адрес страницы после начала раздела
---@field state string Готовность возможности: `ready`, `later` либо `partial`

---@class TntDocsMenuGroup Раздел файла меню
---@field title string
---@field items TntDocsMenuItem[]

--- Голый текст вкраплений: тем же правилом, каким пакет разметки читает
--- заголовок страницы.
---@param inline table[]
---@return string
local function plain(inline)
    return markdown.title_of({ { kind = 'heading', inline = inline } }) --[[@as string]]
end

--- Ссылка пункта и хвост за ней.
---@param paragraph table
---@return table|nil link
---@return table[] tail
local function link_of(paragraph)
    local link, tail = nil, {}

    for _, node in ipairs(paragraph.inline) do
        if link ~= nil then
            table.insert(tail, node)
        elseif node.kind == 'link' then
            link = node
        end
    end

    return link, tail
end

--- Адрес страницы после начала раздела; ссылка мимо раздела — пусто.
---@param href string
---@param prefix string
---@return string|nil
local function slug_of(href, prefix)
    if not href:startswith(prefix .. '/') then
        return nil
    end

    local slug = href:sub(#prefix + 2)

    if slug:find(SLUG) == nil and slug:find(SECTIONED) == nil then
        return nil
    end

    return slug
end

--- Пункт меню из блоков пункта списка; не пункт — пусто.
---@param blocks table[]
---@param prefix string
---@return TntDocsMenuItem|nil item
---@return string|nil mark Незнакомая метка
local function item_of(blocks, prefix)
    local paragraph = blocks[1]

    if paragraph == nil or paragraph.kind ~= 'paragraph' then
        return nil
    end

    local link, tail = link_of(paragraph)
    local slug = link and slug_of(link.href, prefix)

    if slug == nil then
        return nil
    end

    ---@cast link table
    local mark = plain(tail):match(MARK)
    local state = mark and Module.MARKS[mark]

    if mark ~= nil and state == nil then
        return nil, mark
    end

    return { title = plain(link.inline), slug = slug, state = state or Module.READY }
end

--- Разбирает файл меню: разделы и пункты в них по порядку.
---
--- Пункт до первого раздела в меню не попадает: ему не в чем стоять.
---@param source string Разметка меню
---@param prefix string Начало адресов раздела
---@return TntDocsMenuGroup[]|nil groups
---@return string|nil err Незнакомая метка либо разметка больше предела
function Module.parse(source, prefix)
    local tree, err = markdown.parse(source, { modify = {} })

    if tree == nil then
        return nil, ('меню не разобрано: %s'):format(tostring(err))
    end

    local groups = {}

    ---@type TntDocsMenuGroup|nil
    local group = nil

    for _, block in ipairs(tree) do
        if block.kind == 'heading' and block.level == 2 then
            group = { title = plain(block.inline), items = {} }
            table.insert(groups, group)
        elseif block.kind == 'list' and group ~= nil then
            for _, entry in ipairs(block.items) do
                local item, mark = item_of(entry.blocks, prefix)

                if mark ~= nil then
                    return nil,
                        ('в меню метка {%s} неизвестна: есть {позже} и {частично}'):format(
                            mark
                        )
                end

                if item ~= nil then
                    table.insert(group.items, item)
                end
            end
        end
    end

    return groups
end

return Module
