--- Настройки раздела документации: проверка и умолчания.
---
--- Настройки проверяются целиком при заведении раздела: раздел заводят
--- при подъёме узла, а первый посетитель приходит через час. Незнакомый
--- ключ — тоже отказ: опечатка `hiden` иначе молча открыла бы скрытые
--- документы.
---
--- Проверка отдаёт текст, а не бросает: фасад бросает его, виня строку,
--- которая завела раздел, а роль — словом без места, которое уходит
--- оператору в alerts конфигурации.

local external = require('tnt.external')
local must = require('tnt.must')

local fail = require('tnt.must.fail').raise

local frame = require('tnt.docs.frame')

local Module = {}

--- Начало адресов раздела.
Module.PREFIX = '/docs'

--- Название раздела: главная, 404 и заголовок вкладки.
Module.TITLE = 'Документация'

--- Название группы для страниц, которых нет ни в одной группе.
Module.REST = 'Прочее'

--- Сколько секунд издание раздела не сверяется с диском.
Module.RECHECK = 1

--- Имя модуля, рядом с которым лежат шаблоны пакета.
Module.ANCHOR = 'tnt.docs'

--- Участок адреса, занятый видом раздела: свод с таким именем
--- разминулся бы с его файлами.
Module.RESERVED = 'assets'

--- Начало адресов: косая черта, участки из букв, цифр, дефиса
--- и подчёркивания, без косой черты в конце.
local PREFIX = '^/[%w_%-/]*[%w_%-]$'

--- Имя свода и сводной страницы плана — один участок адреса.
local SEGMENT = '^[%w_%-]+$'

--- План страницы: о чём она будет, чего не хватает, чем закрывается.
local PLANNED = {
    about = '?not_empty',
    missing = '?not_empty',
    tasks = { '?array_of', 'not_empty' },
    note = '?not_empty',
}

--- Описание настроек для `must.options`.
local SHAPE = {
    directory = '?not_empty',
    roots = {
        '?array_of',
        'options',
        { section = { 'matches', SEGMENT }, directory = 'not_empty', hidden = { '?array_of', 'not_empty' } },
    },
    prefix = { '?matches', PREFIX },
    title = '?not_empty',
    start = { '?matches', '^/' },
    menu = '?not_empty',
    groups = {
        '?array_of',
        'options',
        { title = 'not_empty', section = { '?matches', SEGMENT }, pages = { 'array_of', 'not_empty' } },
    },
    rest = '?not_empty',
    hidden = { '?array_of', 'not_empty' },
    plan = { '?options', { page = { '?matches', SEGMENT }, pages = '?table' } },
    suggestions = { '?array_of', 'options', frame.ITEM },
    card = '?callable',
    frame = { '?options', frame.SHAPE },
    recheck = '?non_negative',
    warm = '?boolean',
    views = '?not_empty',
}

---@class TntDocsRoot Свод: каталог разметки под своим участком адреса
---@field section string|nil Участок адреса; у раздела из одного каталога — пусто
---@field directory string
---@field hidden table<string, boolean> Скрытые имена множеством

---@class TntDocsPlanned План ненаписанной страницы
---@field about string|nil О чём будет рассказано
---@field missing string|nil Чего не хватает в наборе
---@field tasks string[]|nil Номера задач, которыми страница закрывается
---@field note string|nil Словесная часть «чем закрывается»

---@class TntDocsSuggestion Подсказка пустого окна поиска
---@field icon string|nil
---@field title string
---@field note string|nil
---@field href string

---@class TntDocsOptions Настройки раздела
---@field directory string|nil Каталог разметки: адреса `<начало>/<имя>`
---@field roots { section: string, directory: string, hidden: string[]|nil }[]|nil Своды: адреса `<начало>/<свод>/<имя>`
---@field prefix string|nil Начало адресов раздела; по умолчанию `/docs`
---@field title string|nil Название раздела
---@field start string|nil Куда ведёт начало раздела; нет — главная с карточками страниц
---@field menu string|nil Файл меню: разделы и страницы по порядку, план
---@field groups TntDocsDeclaredGroup[]|nil Группы навигации по порядку — после разделов меню
---@field rest string|nil Название группы для страниц вне групп
---@field hidden string[]|nil Имена страниц каталога `directory`, которых на сайте нет
---@field plan { page: string|nil, pages: table<string, TntDocsPlanned>|nil }|nil Сводная страница и план страниц
---@field suggestions TntDocsSuggestion[]|nil Подсказки пустого окна поиска
---@field card (fun(name: string, section: string|nil): TntDocsCard|nil)|nil Карточка пакета по имени страницы
---@field frame TntDocsFrameOptions|nil Рамка сайта: марка, шапка, подвал
---@field recheck number|nil Сколько секунд издание не сверяется с диском
---@field warm boolean|nil Прогревать ли раздел в фоне при подключении
---@field views string|nil Каталог шаблонов; по умолчанию — шаблоны пакета

---@class TntDocsCard Карточка пакета на странице документа
---@field name string|nil Имя пакета
---@field install string|nil Команда установки
---@field repository string|nil Адрес репозитория

---@class TntDocsSettings Проверенные настройки с умолчаниями
---@field roots TntDocsRoot[]
---@field sectioned boolean Своды ли это: адреса страниц — «свод/имя»
---@field prefix string
---@field title string
---@field start string|nil
---@field menu string|nil
---@field groups TntDocsDeclaredGroup[]
---@field rest string
---@field plan { page: string|nil, pages: table<string, TntDocsPlanned> }
---@field suggestions TntDocsSuggestion[]
---@field card (fun(name: string, section: string|nil): TntDocsCard|nil)|nil
---@field frame TntDocsFrame
---@field recheck number
---@field warm boolean
---@field views string

--- Где лежит модуль пакета.
---
--- `package.search` — расширение Tarantool: оно знает и `package.path`,
--- и дерево `.rocks`, то есть находит пакет и в дереве разработки,
--- и установленным.
---@param name string
---@return string|nil
local function search(name)
    return package.search(name)
end

--- Средства снаружи: поиск модуля.
local source = external.install(Module, { search = search })

--- Каталог шаблонов пакета: рядом с модулем `tnt.docs`.
---
--- Шаблоны едут роком вместе с кодом, и путь до них ни к рабочему
--- каталогу узла, ни к именам модулей отношения не имеет: где лежит
--- `tnt/docs.lua`, там же лежит и `tnt/docs/views`.
---@return string
function Module.views()
    local anchor = source().search(Module.ANCHOR)

    if anchor == nil then
        fail(
            ('пакет %s не найден загрузчиком: шаблонов страниц негде взять'):format(
                Module.ANCHOR
            )
        )
    end

    ---@cast anchor string
    return (anchor:gsub('%.lua$', '/views'))
end

--- Что не так со сводами: имена повторяются либо заняты видом раздела.
---@param roots table[]
---@param name string
---@return string|nil
local function explain_roots(roots, name)
    if roots[1] == nil then
        return ('%s.roots — хотя бы один свод'):format(name)
    end

    local seen = {}

    for index, root in ipairs(roots) do
        local where = ('%s.roots[%d].section'):format(name, index)

        if root.section == Module.RESERVED then
            return ('%s «%s» занят видом раздела'):format(where, root.section)
        end

        if seen[root.section] then
            return ('%s «%s» уже назван'):format(where, root.section)
        end

        seen[root.section] = true
    end

    return nil
end

--- Что не так с группами: свод у группы бывает, только когда своды есть,
--- и только из названных.
---@param options TntDocsOptions
---@param name string
---@return string|nil
local function explain_groups(options, name)
    local known = {}

    for _, root in ipairs(options.roots or {}) do
        known[root.section] = true
    end

    for index, group in ipairs(options.groups or {}) do
        local section = group.section

        if section ~= nil and not known[section] then
            return ('%s.groups[%d].section «%s» — такого свода нет'):format(name, index, section)
        end
    end

    return nil
end

--- Что не так с планом страниц: ключ — адрес страницы, значение — план.
---@param pages table
---@param name string
---@return string|nil
local function explain_plan(pages, name)
    for slug, planned in pairs(pages) do
        if type(slug) ~= 'string' then
            return ('%s.plan.pages — адрес страницы ключом, а не %s'):format(name, type(slug))
        end

        local complaint = must.explain.options(planned, ('%s.plan.pages[«%s»]'):format(name, slug), PLANNED)

        if complaint ~= nil then
            return complaint
        end
    end

    return nil
end

--- Что не так с настройками; всё так — пусто.
---@param options any
---@return string|nil
function Module.explain(options)
    local name = 'настройки раздела'
    local complaint = must.explain.options(options, name, SHAPE)

    if complaint ~= nil then
        return complaint
    end

    ---@cast options TntDocsOptions
    if (options.directory == nil) == (options.roots == nil) then
        return ('%s: разметка — каталог directory либо своды roots, ровно одно'):format(
            name
        )
    end

    if options.roots ~= nil and options.hidden ~= nil then
        return ('%s.hidden — у каталога directory; скрытые документы свода — roots[…].hidden'):format(
            name
        )
    end

    return (options.roots and explain_roots(options.roots, name))
        or explain_groups(options, name)
        or explain_plan((options.plan or {}).pages or {}, name)
        or frame.explain(options.frame or {}, name .. '.frame')
end

--- Множество имён.
---@param names string[]|nil
---@return table<string, boolean>
local function set_of(names)
    local set = {}

    for _, name in ipairs(names or {}) do
        set[name] = true
    end

    return set
end

--- Своды с умолчаниями: каталог `directory` — свод без участка адреса.
---@param options TntDocsOptions
---@return TntDocsRoot[]
local function roots_of(options)
    if options.directory ~= nil then
        return { { directory = options.directory, hidden = set_of(options.hidden) } }
    end

    local roots = {}

    ---@cast options.roots -nil
    for _, root in ipairs(options.roots) do
        table.insert(roots, { section = root.section, directory = root.directory, hidden = set_of(root.hidden) })
    end

    return roots
end

--- Настройки с умолчаниями. Проверены они раньше — `explain`.
---@param options TntDocsOptions
---@return TntDocsSettings
function Module.read(options)
    local prefix = options.prefix or Module.PREFIX
    local title = options.title or Module.TITLE
    local plan = options.plan or {}

    return {
        roots = roots_of(options),
        sectioned = options.roots ~= nil,
        prefix = prefix,
        title = title,
        start = options.start,
        menu = options.menu,
        groups = options.groups or {},
        rest = options.rest or Module.REST,
        plan = { page = plan.page, pages = plan.pages or {} },
        suggestions = options.suggestions or {},
        card = options.card,
        frame = frame.read(options.frame, title, prefix),
        recheck = options.recheck or Module.RECHECK,
        warm = options.warm ~= false,
        views = options.views or Module.views(),
    }
end

return Module
