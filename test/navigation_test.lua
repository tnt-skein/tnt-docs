--- Проверки навигации: разделы меню и группы приложения, заглушки,
--- сводная страница, страницы вне групп, соседи и план.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local navigation = helper.part('navigation')

local g = t.group('tnt.docs.navigation')

--- Страница с заголовком и описанием от адреса.
---@param slug string
---@return table
local function page(slug)
    return { name = slug, title = 'Страница ' .. slug, description = 'про ' .. slug }
end

--- Что нужно навигации: страницы по адресам и всё прочее по умолчанию.
---@param slugs string[]
---@param options table|nil Поверх умолчаний
---@return TntDocsNavigationInput
local function input(slugs, options)
    local pages, documents = {}, {}

    for _, slug in ipairs(slugs) do
        pages[slug] = page(slug)
        documents[slug] = true
    end

    local given = {
        pages = pages,
        documents = documents,
        hidden = {},
        menu = {},
        groups = {},
        rest = 'Прочее',
        plan = { pages = {} },
        address = helper.address,
    }

    for key, value in pairs(options or {}) do
        given[key] = value
    end

    return given
end

--- Пункт навигации страницы, которая есть.
---@param slug string
---@param group string
---@param title string|nil Название из меню
---@return table
local function entry(slug, group, title)
    return {
        slug = slug,
        title = title or 'Страница ' .. slug,
        description = 'про ' .. slug,
        address = helper.address(slug),
        kind = 'page',
        written = true,
        state = 'ready',
        state_title = 'есть',
        planned = false,
        tasks = {},
        group = group,
    }
end

--- Навигация по пяти страницам и трём группам.
---@return TntDocsNavigation
local function built()
    return navigation.build(input({ 'a', 'b', 'c', 'd', 'e' }, {
        groups = {
            { title = 'Первая', pages = { 'b', 'gone', 'a' } },
            -- Страница во второй группе уже стоит в первой: место у неё одно.
            { title = 'Вторая', pages = { 'a', 'c' } },
            -- Группа, где нет ни одной страницы, не показывается.
            { title = 'Пустая', pages = { 'gone' } },
        },
    }))
end

--- Адреса пунктов списка.
---@param entries TntDocsEntry[]
---@return string[]
local function slugs_of(entries)
    local slugs = {}

    for _, item in ipairs(entries) do
        table.insert(slugs, item.slug)
    end

    return slugs
end

g.test_the_groups_hold_the_pages_that_are_there_in_their_order = function()
    t.assert_equals(built().groups, {
        { title = 'Первая', entries = { entry('b', 'Первая'), entry('a', 'Первая') } },
        { title = 'Вторая', entries = { entry('c', 'Вторая') } },
        -- Страницы вне групп — последней группой, по порядку адресов.
        { title = 'Прочее', entries = { entry('d', 'Прочее'), entry('e', 'Прочее') } },
    })
end

g.test_the_order_goes_through_the_groups = function()
    local nav = built()

    t.assert_equals(slugs_of(nav.order), { 'b', 'a', 'c', 'd', 'e' })
    t.assert_equals(nav.places.c.position, 3)
    t.assert_is(nav.places.c.group, nav.groups[2])
    t.assert_is(nav.places.c.entry, nav.order[3])
    t.assert_equals(nav.plan, nil)
end

g.test_the_neighbours_follow_the_order_across_groups = function()
    local nav = built()

    t.assert_equals({ navigation.neighbours(nav, 'b') }, { nil, entry('a', 'Первая') })
    -- Последняя страница группы ведёт к первой странице следующей.
    t.assert_equals({ navigation.neighbours(nav, 'a') }, { entry('b', 'Первая'), entry('c', 'Вторая') })
    t.assert_equals({ navigation.neighbours(nav, 'e') }, { entry('d', 'Прочее'), nil })
    t.assert_equals({ navigation.neighbours(nav, 'gone') }, { nil, nil })
end

g.test_the_entry_of_a_page = function()
    local nav = built()

    t.assert_is(navigation.entry_of(nav, 'd'), assert(nav.groups[3]).entries[1])
    t.assert_equals(navigation.entry_of(nav, 'gone'), nil)
end

g.test_without_pages_outside_the_groups_there_is_no_rest = function()
    local nav = navigation.build(input({ 'a' }, { groups = { { title = 'Одна', pages = { 'a' } } } }))

    t.assert_equals(nav.groups, { { title = 'Одна', entries = { entry('a', 'Одна') } } })
end

g.test_without_groups_every_page_is_in_the_rest = function()
    local nav = navigation.build(input({ 'b', 'a' }, { rest = 'Все' }))

    t.assert_equals(nav.groups, { { title = 'Все', entries = { entry('a', 'Все'), entry('b', 'Все') } } })
end

g.test_a_group_of_a_section_names_its_pages_inside_it = function()
    local nav = navigation.build(input({ 'packages/router', 'framework/views' }, {
        groups = { { title = 'Пакеты', section = 'packages', pages = { 'router', 'views' } } },
    }))

    t.assert_equals(slugs_of(assert(nav.groups[1]).entries), { 'packages/router' })
    t.assert_equals(slugs_of(assert(nav.groups[2]).entries), { 'framework/views' })
end

--- Меню: страница, заглушка, сводная страница, повтор и скрытый.
---@return TntDocsMenuGroup[]
local function menu()
    return {
        {
            title = 'Пролог',
            items = {
                { title = 'Обзор', slug = 'a', state = 'ready' },
                { title = 'Что нового', slug = 'later', state = 'later' },
                { title = 'Что впереди', slug = 'plan', state = 'ready' },
            },
        },
        {
            title = 'Основы',
            items = {
                -- Названная дважды страница стоит там, где названа первой.
                { title = 'Обзор ещё раз', slug = 'a', state = 'ready' },
                { title = 'Частично', slug = 'b', state = 'partial' },
                { title = 'Скрытый', slug = 'secret', state = 'ready' },
                { title = 'Сломан', slug = 'broken', state = 'ready' },
            },
        },
    }
end

g.test_the_menu_goes_first_with_its_titles_and_states = function()
    local given = input({ 'a', 'b', 'c' }, {
        menu = menu(),
        hidden = { secret = true },
        groups = { { title = 'Группа', pages = { 'c', 'a' } } },
        plan = { page = 'plan', pages = { later = { about = 'новое', tasks = { 'x1' } } } },
    })

    given.documents.broken = true

    local nav = navigation.build(given)
    local prologue = assert(nav.groups[1])

    t.assert_equals(slugs_of(prologue.entries), { 'a', 'later', 'plan' })

    local overview, later, plan = unpack(prologue.entries)

    t.assert_equals(overview.title, 'Обзор')
    t.assert_equals(overview.description, 'про a')
    t.assert_equals(later.kind, 'upcoming')
    t.assert_equals(later.written, false)
    t.assert_equals(later.description, '')
    t.assert_equals({ later.state, later.state_title, later.planned }, { 'later', 'позже', true })
    t.assert_equals({ later.about, later.missing, later.tasks, later.note }, { 'новое', nil, { 'x1' }, nil })
    t.assert_equals({ plan.kind, plan.written, plan.title }, { 'plan', true, 'Что впереди' })
    t.assert_is(nav.plan, plan)

    local basics = assert(nav.groups[2])

    -- Скрытого нет и в меню; документ с отказом — страница, а не заглушка.
    t.assert_equals(slugs_of(basics.entries), { 'b', 'broken' })
    t.assert_equals({ basics.entries[1].state_title, basics.entries[2].kind }, { 'частично', 'page' })
    t.assert_equals(slugs_of(assert(nav.groups[3]).entries), { 'c' })
    t.assert_equals(nav.groups[4], nil)
    -- Заглушка в сквозной порядок не входит, сводная страница входит.
    t.assert_equals(slugs_of(nav.order), { 'a', 'plan', 'b', 'broken', 'c' })
    t.assert_equals({ navigation.neighbours(nav, 'later') }, { nil, nil })
    t.assert_equals(nav.places.later.group, prologue)
end

g.test_a_plan_the_menu_does_not_name_still_has_an_entry = function()
    local nav = navigation.build(input({ 'a' }, { plan = { page = 'plan', pages = {} } }))
    local plan = assert(nav.plan)

    t.assert_equals(
        { plan.slug, plan.title, plan.address, plan.kind },
        { 'plan', 'Что впереди', '/docs/plan', 'plan' }
    )
    t.assert_equals(plan.group, nil)
    t.assert_equals(navigation.PLAN, 'Что впереди')
end

g.test_the_plan_holds_the_planned_and_the_unwritten_in_the_order_of_the_menu = function()
    local nav = navigation.build(input({ 'a', 'b', 'c' }, {
        menu = menu(),
        hidden = { secret = true },
        plan = {
            page = 'plan',
            pages = {
                a = { note = 'готово' },
                plan = { note = 'эта страница' },
                later = { about = 'новое' },
            },
        },
    }))

    local items, written = navigation.planned(nav)

    -- Страница без плана (b) и вне меню (c) в план не входят, а пункт
    -- меню без документа (broken здесь не документ) — входит всегда.
    t.assert_equals(slugs_of(items), { 'a', 'later', 'plan', 'broken' })
    t.assert_equals(written, 2)
end
