--- Страница раздела из разметки: шапка, описание, текст, оглавление
--- и разделы для указателя.
---
--- Разбирает разметку `tnt-markdown` конвейером пакета с тремя шагами
--- раздела:
---
---   * первым — заголовок документа уходит в шапку страницы
---     (`title_of` и `without_first_heading`): раньше якорей, иначе
---     заголовок второго уровня в начале документа занял бы якорь своего
---     тёзки ниже;
---   * последними — ссылки (`markdown.links`): ссылка на соседний
---     документ становится адресом его страницы, а ссылка, которой на сайте
---     некуда вести, остаётся текстом без ссылки (`resolver`).
---
--- **Описание** — первый абзац документа после заголовка, голым текстом:
--- его показывает карточка страницы на главной. Блок кода и врезка
--- описанием не бывают — берётся первый абзац текста. Длинный обрезается
--- по границе слова. Для мета-тегов страницы главнее описание из шапки
--- документа (`description:`): его пишут для поисковика нарочно.
---
--- **Оглавление** — заголовки h2 и h3: h4 — подпись внутри раздела,
--- и от неё колонка превращается в лестницу, по которой разделы страницы
--- уже не видны с одного взгляда.
---
--- **Разделы** — заголовки h2–h4 с текстом под ними (`markdown.sections_of`)
--- и вступление: текст до первого заголовка, раздел без якоря с заголовком
--- страницы. По вступлению находится сама страница — по словам её
--- заголовка и первых абзацев.

local utf8 = require('utf8')

local markdown = require('tnt.markdown')

local Module = {}

--- Сколько знаков описания показывает карточка.
Module.DESCRIPTION = 200

--- До какого уровня заголовки идут в оглавление.
Module.OUTLINE_LEVEL = 3

--- Адрес ссылки, которую надо снять: такой адрес правило ставит ссылке,
--- которой на сайте некуда вести, а следующий шаг её узнаёт.
local UNLINKED = 'tnt.docs.unlinked'

--- Заголовок, с которого начинается вступление: разделы пакет разметки
--- читает от заголовка, а у текста до первого заголовка его нет.
--- Собран разбором записи, а не таблицей с уровнем: уровень вступлению
--- не важен, и число в таблице было бы правкой, которой никто не видит.
local INTRODUCTION = assert(markdown.parse('## вступление', { modify = {} }))[1]

---@class TntDocsSection Раздел страницы для указателя
---@field anchor string Якорь раздела; у вступления — пустая строка
---@field title string Заголовок раздела без разметки
---@field text string Текст раздела без разметки

---@class TntDocsPage Страница, собранная из разметки
---@field name string Имя страницы: имя файла без `.md`
---@field title string Заголовок: `title` шапки документа, иначе первый заголовок, иначе имя
---@field description string Первый абзац текста голым текстом; нет абзаца — пусто
---@field summary string Описание для мета-тегов: из шапки документа, иначе первый абзац
---@field outline TntMarkdownHeading[] Оглавление: заголовки h2–h3 с якорями
---@field body string HTML страницы без заголовка — его рисует шапка
---@field sections TntDocsSection[] Вступление и разделы страницы
---@field source string Разметка, из которой страница собрана

--- Голый текст вкраплений: тем же правилом, каким пакет разметки
--- читает заголовок страницы.
---@param inline table[]
---@return string
local function plain(inline)
    return markdown.title_of({ { kind = 'heading', inline = inline } }) --[[@as string]]
end

--- Строка не длиннее предела; обрезанная кончается целым словом и знаком
--- пропуска.
---@param text string
---@param limit integer
---@return string
function Module.shortened(text, limit)
    local size = utf8.len(text) or #text

    if size <= limit then
        return text
    end

    -- Срез от начала — отрицательным номером: у единицы мутанты 0 и 1-1
    -- дали бы ту же строку. Знаком больше — чтобы увидеть, кончается ли
    -- на пределе целое слово: тогда за ним стоит пробел.
    local head = utf8.sub(text, -size, limit + 1)
    local whole = head:match('^(.*%S)%s') or utf8.sub(text, -size, limit)

    return whole .. '…'
end

--- Описание: первый абзац верхнего уровня.
---@param tree table[]
---@return string
local function described(tree)
    for _, node in ipairs(tree) do
        if node.kind == 'paragraph' then
            -- Строки абзаца карточка показывает одной строкой.
            return Module.shortened((plain(node.inline):gsub('%s+', ' ')), Module.DESCRIPTION)
        end
    end

    return ''
end

--- Вступление: блоки до первого заголовка, текстом раздела.
---@param tree table[]
---@param title string
---@return TntDocsSection
local function introduction(tree, title)
    local blocks = { INTRODUCTION }

    for _, node in ipairs(tree) do
        if node.kind == 'heading' then
            break
        end

        table.insert(blocks, node)
    end

    -- Раздел ровно один: заголовок, с которого он начинается, поставлен выше.
    local section = markdown.sections_of(blocks)[1] --[[@as TntMarkdownSection]]

    return { anchor = '', title = title, text = section.text }
end

--- Снимает ссылки, помеченные правилом адресов: текст остаётся на месте.
---@param inline table[]
---@return table[]
local function unlinked(inline)
    local kept = {}

    for _, node in ipairs(inline) do
        if node.kind == 'link' and node.href == UNLINKED then
            for _, inner in ipairs(unlinked(node.inline)) do
                table.insert(kept, inner)
            end
        else
            if node.inline ~= nil then
                node.inline = unlinked(node.inline)
            end

            table.insert(kept, node)
        end
    end

    return kept
end

--- Ячейки строки таблицы без помеченных ссылок.
---@param cells table[][]
---@return table[][]
local function unlinked_cells(cells)
    local kept = {}

    for index, cell in ipairs(cells) do
        kept[index] = unlinked(cell)
    end

    return kept
end

--- Шаг конвейера: помеченные ссылки — текстом.
---
--- Ссылки стоят в вкраплениях абзацев и заголовков и в ячейках таблиц —
--- там же, где их находит `markdown.links`; вглубь списков и врезок идёт
--- `markdown.walk`.
---@param blocks table[]
---@return table[]
local function unwrap(blocks)
    return markdown.walk(blocks, function(node)
        if node.inline ~= nil then
            node.inline = unlinked(node.inline)
        end

        if node.head ~= nil then
            node.head = unlinked_cells(node.head)

            for index, row in ipairs(node.rows) do
                node.rows[index] = unlinked_cells(row)
            end
        end

        return node
    end)
end

--- Ведёт ли адрес туда, где перевод ему не нужен: внешний адрес, адрес
--- от корня сайта и якорь на этой же странице.
---@param href string
---@return boolean
local function settled(href)
    return href:find('^%a[%w+.-]*:') ~= nil or href:startswith('/') or href:startswith('#')
end

--- Правило адресов: ссылка на соседний документ — адрес его страницы.
---
--- Ссылка относительная — путь от каталога документа: `views.md`
--- в своде, `../packages/router.md` — в соседний свод. Ведёт она
--- к документу на сайте — это адрес его страницы с тем же якорем. Ведёт
--- к документу, которого на сайте нет (скрыт, удалён), к файлу
--- репозитория (`../../routes/web.lua`) или выше корня сводов — ссылка
--- снимается: сайт отдаёт документы, а не файлы, и ссылка в отказ 404
--- хуже простого текста. Хвост после `.md` — только якорь:
--- `install.md?raw=1` — не ссылка на страницу.
---@param section string|nil Свод документа; у раздела из одного каталога — пусто
---@param address fun(slug: string): string|nil Адрес страницы по адресу в разделе; страницы нет — пусто
---@return fun(href: string): string|nil
function Module.resolver(section, address)
    return function(href)
        if settled(href) then
            return nil
        end

        local path, anchor = href:match('^([^#]*)(.*)$')
        local name = path:match('^(.+)%.md$')

        if name == nil then
            return UNLINKED
        end

        local parts = { section }

        for part in name:gmatch('[^/]+') do
            if part == '..' then
                if parts[1] == nil then
                    return UNLINKED
                end

                table.remove(parts)
            elseif part ~= '.' then
                table.insert(parts, part)
            end
        end

        local found = address(table.concat(parts, '/'))

        if found == nil then
            return UNLINKED
        end

        return found .. anchor
    end
end

--- Оглавление: заголовки не глубже `OUTLINE_LEVEL`.
---@param headings TntMarkdownHeading[]
---@return TntMarkdownHeading[]
local function shallow(headings)
    local listed = {}

    for _, heading in ipairs(headings) do
        if heading.level <= Module.OUTLINE_LEVEL then
            table.insert(listed, heading)
        end
    end

    return listed
end

--- Собирает страницу из разметки.
---@param name string Адрес страницы после начала раздела
---@param source string
---@param rewrite fun(href: string): string|nil Правило адресов (`resolver`)
---@return TntDocsPage|nil page
---@return table|nil err Отказ разбора: разметка больше предела
function Module.render(name, source, rewrite)
    local title = nil
    local pipeline = markdown.modifications()

    table.insert(pipeline, 1, function(blocks)
        title = markdown.title_of(blocks)

        return markdown.without_first_heading(blocks)
    end)

    table.insert(pipeline, markdown.links(rewrite))
    table.insert(pipeline, unwrap)

    local tree, meta = markdown.parse(source, { modify = pipeline })

    if tree == nil then
        return nil, meta
    end

    local heading = meta.title or title or name
    local description = described(tree)
    local sections = { introduction(tree, heading) }

    for _, section in ipairs(markdown.sections_of(tree)) do
        table.insert(sections, { anchor = section.anchor, title = section.title, text = section.text })
    end

    return {
        name = name,
        title = heading,
        description = description,
        summary = meta.description or description,
        outline = shallow(markdown.outline_of(tree)),
        body = markdown.to_html(tree),
        sections = sections,
        source = source,
    }
end

return Module
