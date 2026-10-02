--- Навигация раздела: группы страниц, соседи по порядку и место страницы.
---
--- Группы и порядок в них задаёт приложение — файлом меню и группами
--- настроек: какие страницы рядом и что читать за чем, знает только оно.
--- Разделы меню идут первыми, группы настроек — за ними. Здесь — что
--- из объявленного есть:
---
---   * пункт меню, за которым файла нет, остаётся в меню заглушкой «скоро»:
---     меню — это план, и у пункта есть название, которое можно показать;
---   * имя в группе настроек, за которым файла нет (нет файла, скрыт),
---     пропускается: удалённый документ не ломает сайт, а ссылка в колонке
---     не уводит в отказ;
---   * скрытый документ не стоит нигде — ни в меню, ни в группе;
---   * страница, названная дважды, стоит там, где названа первой: у неё одно
---     место, иначе «назад» и «вперёд» ходили бы по кругу;
---   * страница, которой нет нигде, стоит в последней группе с названием
---     `rest` по порядку адресов. Новый документ так виден на сайте сразу,
---     а то, что ему не нашлось места, видно тоже — на виду, а не потерей.
---
--- Соседи — по сквозному порядку групп, мимо заглушек: последняя страница
--- группы ведёт к первой странице следующей, а «вперёд» не упирается
--- в обещание.

local menu = require('tnt.docs.menu')

local Module = {}

--- Название сводной страницы плана, если меню её не называет.
Module.PLAN = 'Что впереди'

--- Состояние возможности словом: его видят меню, заглушка и план.
---@type table<string, string>
Module.STATES = {
    ready = 'есть',
    later = 'позже',
    partial = 'частично',
}

---@class TntDocsEntry Пункт навигации
---@field slug string Адрес страницы после начала раздела
---@field title string
---@field description string Первый абзац документа; у заглушки и плана пусто
---@field address string
---@field kind string `page` — документ, `upcoming` — заглушка, `plan` — сводная страница
---@field written boolean Есть ли у пункта страница: документ либо план
---@field state string Готовность возможности: `ready`, `later`, `partial`
---@field state_title string Она же словом
---@field planned boolean Есть ли у страницы план: такая стоит на сводной странице
---@field about string|nil О чём будет страница — из плана
---@field missing string|nil Чего не хватает в наборе — из плана
---@field tasks string[] Номера задач, которыми страница закрывается, — из плана
---@field note string|nil Словесная часть «чем закрывается» — из плана
---@field group string|nil Название группы; у сводной страницы, которой меню не называет, — пусто

---@class TntDocsGroup Группа страниц
---@field title string
---@field entries TntDocsEntry[]

---@class TntDocsSpot Место пункта в навигации
---@field group TntDocsGroup
---@field entry TntDocsEntry
---@field position integer|nil Место в сквозном порядке; у заглушки — пусто

---@class TntDocsNavigation
---@field groups TntDocsGroup[] Группы с хоть одним пунктом, по порядку
---@field order TntDocsEntry[] Страницы сквозным порядком, без заглушек
---@field places table<string, TntDocsSpot> Адрес → группа и место
---@field plan TntDocsEntry|nil Сводная страница плана, если она есть

---@class TntDocsDeclaredGroup Группа, объявленная приложением
---@field title string
---@field section string|nil Свод, в котором лежат страницы группы
---@field pages string[]

---@class TntDocsNavigationInput Из чего собирается навигация
---@field pages table<string, TntDocsPage> Страницы по адресу; документа с адресом сводной страницы среди них нет
---@field documents table<string, boolean> Документы по адресу — и собранные, и с отказом
---@field hidden table<string, boolean> Скрытые документы по адресу
---@field menu TntDocsMenuGroup[] Разделы файла меню
---@field groups TntDocsDeclaredGroup[] Группы настроек
---@field rest string Название группы для страниц вне групп
---@field plan { page: string|nil, pages: table<string, TntDocsPlanned> }
---@field address fun(slug: string): string Адрес страницы

--- Пункт навигации.
---@param input TntDocsNavigationInput
---@param slug string
---@param title string
---@param kind string
---@param state string
---@return TntDocsEntry
local function entry_of(input, slug, title, kind, state)
    local page = input.pages[slug]
    local planned = input.plan.pages[slug]
    local plan = planned or {}

    return {
        slug = slug,
        title = title,
        description = page and page.description or '',
        address = input.address(slug),
        kind = kind,
        written = kind ~= 'upcoming',
        state = state,
        state_title = Module.STATES[state],
        planned = planned ~= nil,
        about = plan.about,
        missing = plan.missing,
        tasks = plan.tasks or {},
        note = plan.note,
    }
end

--- Род пункта меню: сводная страница, документ либо заглушка.
---@param input TntDocsNavigationInput
---@param slug string
---@return string
local function kind_of(input, slug)
    if slug == input.plan.page then
        return 'plan'
    end

    return input.documents[slug] and 'page' or 'upcoming'
end

--- Разделы файла меню группами.
---@param input TntDocsNavigationInput
---@param placed table<string, boolean>
---@return TntDocsGroup[]
local function from_menu(input, placed)
    local groups = {}

    for _, declared in ipairs(input.menu) do
        local entries = {}

        for _, item in ipairs(declared.items) do
            if not placed[item.slug] and not input.hidden[item.slug] then
                placed[item.slug] = true
                table.insert(entries, entry_of(input, item.slug, item.title, kind_of(input, item.slug), item.state))
            end
        end

        table.insert(groups, { title = declared.title, entries = entries })
    end

    return groups
end

--- Группы настроек: только страницы, которые есть.
---@param input TntDocsNavigationInput
---@param placed table<string, boolean>
---@return TntDocsGroup[]
local function from_groups(input, placed)
    local groups = {}

    for _, declared in ipairs(input.groups) do
        local entries = {}

        for _, name in ipairs(declared.pages) do
            local slug = declared.section and declared.section .. '/' .. name or name
            local page = input.pages[slug]

            if page ~= nil and not placed[slug] then
                placed[slug] = true
                table.insert(entries, entry_of(input, slug, page.title, 'page', menu.READY))
            end
        end

        table.insert(groups, { title = declared.title, entries = entries })
    end

    return groups
end

--- Страницы вне групп по порядку адресов.
---@param input TntDocsNavigationInput
---@param placed table<string, boolean>
---@return TntDocsGroup
local function rest_of(input, placed)
    local left = {}

    for slug in pairs(input.pages) do
        if not placed[slug] then
            table.insert(left, slug)
        end
    end

    table.sort(left)

    local entries = {}

    for _, slug in ipairs(left) do
        table.insert(entries, entry_of(input, slug, input.pages[slug].title, 'page', menu.READY))
    end

    return { title = input.rest, entries = entries }
end

--- Сводная страница, которой меню не называет: адрес у неё есть, места
--- в группах нет.
---@param input TntDocsNavigationInput
---@return TntDocsEntry|nil
local function plan_of(input)
    local page = input.plan.page

    return page and entry_of(input, page, Module.PLAN, 'plan', menu.READY)
end

--- Собирает навигацию по страницам, которые есть.
---@param input TntDocsNavigationInput
---@return TntDocsNavigation
function Module.build(input)
    local placed = {}
    local groups = from_menu(input, placed)

    for _, group in ipairs(from_groups(input, placed)) do
        table.insert(groups, group)
    end

    table.insert(groups, rest_of(input, placed))

    local navigation = { groups = {}, order = {}, places = {}, plan = plan_of(input) }

    for _, group in ipairs(groups) do
        if group.entries[1] ~= nil then
            table.insert(navigation.groups, group)
        end

        for _, entry in ipairs(group.entries) do
            local position = nil

            entry.group = group.title

            if entry.written then
                table.insert(navigation.order, entry)
                position = #navigation.order
            end

            if entry.kind == 'plan' then
                navigation.plan = entry
            end

            navigation.places[entry.slug] = { group = group, entry = entry, position = position }
        end
    end

    return navigation
end

--- Соседи страницы по сквозному порядку: предыдущая и следующая.
---@param navigation TntDocsNavigation
---@param slug string
---@return TntDocsEntry|nil previous
---@return TntDocsEntry|nil following
function Module.neighbours(navigation, slug)
    local place = navigation.places[slug]
    local position = place and place.position

    if position == nil then
        return nil
    end

    return navigation.order[position - 1], navigation.order[position + 1]
end

--- Пункт навигации по адресу; нет его — пусто.
---@param navigation TntDocsNavigation
---@param slug string
---@return TntDocsEntry|nil
function Module.entry_of(navigation, slug)
    local place = navigation.places[slug]

    return place and place.entry
end

--- Пункты плана по порядку меню: страницы со своим планом и все, которых
--- ещё нет, — и сколько из них уже написано.
---
--- Документы, о которых плана нет — документы пакетов, — в план
--- не входят: «чем закрывается страница» про них сказать нечего.
---@param navigation TntDocsNavigation
---@return TntDocsEntry[] items
---@return integer written
function Module.planned(navigation)
    local items, written = {}, 0

    for _, group in ipairs(navigation.groups) do
        for _, entry in ipairs(group.entries) do
            if entry.planned or not entry.written then
                table.insert(items, entry)

                if entry.written then
                    written = written + 1
                end
            end
        end
    end

    return items, written
end

return Module
