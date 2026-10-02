--- Рамка сайта вокруг раздела: марка, пункты шапки, ссылки наружу
--- и подвал.
---
---     frame = {
---         brand = 'skein',
---         home = '/',
---         menu = {
---             { title = 'Главная', href = '/' },
---             { title = 'Документация', href = '/docs' },
---             { title = 'Больше', columns = { { { icon = 'box', title = 'Ядро', href = '/about#kernel' } } } },
---         },
---         links = { { title = 'Исходники', href = 'https://example.org/src' } },
---         footer = { note = 'Стоит на `tnt-*`.', columns = { { title = 'Разделы', links = { … } } } },
---     }
---
--- Раздел рисует страницу целиком — с шапкой и подвалом сайта, — а адресов
--- сайта не знает: куда ведут марка, пункты шапки и ссылки подвала,
--- решает приложение. Без настроек рамка — марка с названием раздела,
--- переключатель темы и кнопка «Наверх».
---
--- Пункт шапки отмечается открытым на своей странице и на всём, что под
--- ней: читатель на `/docs/router` стоит в разделе `/docs`. Ссылка
--- наружу — адрес со схемой — открывается в новой вкладке. Абзац подвала
--- пишется разметкой (`tnt-markdown`): код и ссылки в нём — без своего
--- языка разметки рамки.

local markdown = require('tnt.markdown')

local Module = {}

--- Язык страниц по умолчанию.
Module.LOCALE = 'ru'

--- Значки, которые умеет рисовать рамка (`partials/icon`).
Module.ICONS = {
    'logo',
    'menu',
    'book',
    'box',
    'code',
    'search',
    'route',
    'database',
    'bolt',
    'terminal',
    'mail',
    'clock',
    'shield-check',
    'arrow-right',
    'angle-up',
    'circle-fill',
    'theme-light',
    'theme-dark',
    'theme-auto',
}

--- Пункт выпадающего меню и подсказка окна поиска: значок, название,
--- подпись и адрес.
Module.ITEM = {
    icon = { '?one_of', Module.ICONS },
    title = 'not_empty',
    note = '?not_empty',
    href = 'not_empty',
}

--- Ссылка: название и адрес; значок — у ссылки справа в шапке, которая
--- на узком экране показывается им.
local LINK = { title = 'not_empty', href = 'not_empty', icon = { '?one_of', Module.ICONS } }

--- Описание настроек рамки для `must.options`.
Module.SHAPE = {
    brand = '?not_empty',
    home = '?not_empty',
    description = '?not_empty',
    url = { '?matches', '^https?://.*[^/]$' },
    image = '?not_empty',
    locale = '?not_empty',
    menu = {
        '?array_of',
        'options',
        { title = 'not_empty', href = '?not_empty', columns = { '?array_of', 'array_of', 'options', Module.ITEM } },
    },
    links = { '?array_of', 'options', LINK },
    footer = {
        '?options',
        {
            note = '?not_empty',
            columns = { '?array_of', 'options', { title = 'not_empty', links = { 'array_of', 'options', LINK } } },
            signature = '?not_empty',
        },
    },
}

---@class TntDocsFrameItem Пункт выпадающего меню
---@field icon string|nil
---@field title string
---@field note string|nil
---@field href string

---@class TntDocsFrameLink Ссылка шапки или подвала
---@field title string
---@field href string
---@field icon string|nil
---@field external boolean|nil Адрес наружу: открывается в новой вкладке

---@class TntDocsFrameEntry Пункт шапки: ссылка либо выпадающее меню
---@field title string
---@field href string|nil
---@field columns TntDocsFrameItem[][]|nil
---@field external boolean|nil
---@field active boolean|nil Открыт ли пункт на этой странице

---@class TntDocsFrameColumn Колонка подвала
---@field title string
---@field links TntDocsFrameLink[]

---@class TntDocsFrameOptions Настройки рамки
---@field brand string|nil Имя сайта: шапка, подвал, вкладка; по умолчанию — название раздела
---@field home string|nil Куда ведёт марка; по умолчанию — начало раздела
---@field description string|nil Описание сайта: подвал и мета-теги
---@field url string|nil Внешний адрес сайта без косой черты в конце: адрес и картинка предпросмотра
---@field image string|nil Картинка предпросмотра: путь от корня сайта
---@field locale string|nil Язык страниц
---@field menu TntDocsFrameEntry[]|nil Пункты шапки по порядку
---@field links TntDocsFrameLink[]|nil Ссылки справа в шапке
---@field footer { note: string|nil, columns: TntDocsFrameColumn[]|nil, signature: string|nil }|nil

---@class TntDocsFrame Рамка с умолчаниями
---@field brand string
---@field home string
---@field description string|nil
---@field url string|nil
---@field image string|nil
---@field locale string
---@field menu TntDocsFrameEntry[]
---@field links TntDocsFrameLink[]
---@field note string|nil Абзац подвала — HTML
---@field columns TntDocsFrameColumn[]
---@field signature string|nil

--- Ведёт ли адрес наружу: схема (`https:`, `mailto:`) либо узел (`//`).
---@param href string
---@return boolean
function Module.external(href)
    return href:find('^%a[%w+.-]*:') ~= nil or href:startswith('//')
end

--- Что не так с пунктами шапки сверх описания: у пункта ровно одно —
--- адрес либо колонки меню.
---@param frame TntDocsFrameOptions
---@param name string
---@return string|nil
function Module.explain(frame, name)
    for index, entry in ipairs(frame.menu or {}) do
        if (entry.href == nil) == (entry.columns == nil) then
            return ('%s.menu[%d] — ссылка href либо меню columns, ровно одно'):format(
                name,
                index
            )
        end
    end

    return nil
end

--- Ссылки с отметкой «наружу».
---@param links TntDocsFrameLink[]
---@return TntDocsFrameLink[]
local function marked(links)
    local result = {}

    for _, link in ipairs(links) do
        table.insert(
            result,
            { title = link.title, href = link.href, icon = link.icon, external = Module.external(link.href) }
        )
    end

    return result
end

--- Рамка с умолчаниями. Настройки проверены раньше.
---@param frame TntDocsFrameOptions|nil
---@param title string Название раздела
---@param home string Начало раздела
---@return TntDocsFrame
function Module.read(frame, title, home)
    frame = frame or {}

    local footer = frame.footer or {}
    local columns = {}

    for _, column in ipairs(footer.columns or {}) do
        table.insert(columns, { title = column.title, links = marked(column.links) })
    end

    return {
        brand = frame.brand or title,
        home = frame.home or home,
        description = frame.description,
        url = frame.url,
        image = frame.image,
        locale = frame.locale or Module.LOCALE,
        menu = frame.menu or {},
        links = marked(frame.links or {}),
        -- Абзац разбирается один раз, при заведении: он один на все
        -- страницы и от запроса не зависит.
        note = footer.note and markdown.render(footer.note, { modify = {} }),
        columns = columns,
        signature = footer.signature,
    }
end

--- Открыт ли пункт на странице: адрес тот же либо страница под ним.
---
--- Корень сайта открыт только на самом корне: под ним — `//…`, а такого
--- пути у страницы не бывает.
---@param href string
---@param path string
---@return boolean
local function opened(href, path)
    return path == href or path:startswith(href .. '/')
end

--- Пункты шапки для страницы: с отметкой открытого и ссылок наружу.
---@param frame TntDocsFrame
---@param path string Путь запроса
---@return TntDocsFrameEntry[]
function Module.menu_at(frame, path)
    local entries = {}

    for _, entry in ipairs(frame.menu) do
        local href = entry.href

        table.insert(entries, {
            title = entry.title,
            href = href,
            columns = entry.columns,
            external = href ~= nil and Module.external(href),
            active = href ~= nil and opened(href, path),
        })
    end

    return entries
end

return Module
