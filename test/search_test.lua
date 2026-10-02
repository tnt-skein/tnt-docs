--- Проверки поиска по изданию: формы слова, все слова и хоть одно,
--- пределы запроса и выдачи, отрывки и адреса разделов.

local json = require('json')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local library_of = helper.part('library')
local search = helper.part('search')

local g = t.group('tnt.docs.search')

g.before_all(function()
    g.dir = helper.directory({
        ['guide.md'] = helper.GUIDE,
        ['install.md'] = helper.INSTALL,
        ['cluster.md'] = '# Кластер\n\nУзлы кластера и шаблоны конфигурации.\n\n## Узлы\n\nКластер из узлов.',
    })

    local shelf = library_of.new({
        roots = { { directory = g.dir, hidden = {} } },
        prefix = '/docs',
        groups = {},
        rest = 'Прочее',
        plan = { pages = {} },
        recheck = 0,
        address = helper.address,
    })

    g.edition = assert(shelf:edition())
end)

g.after_all(function()
    helper.remove(g.dir)
end)

--- Адреса попаданий выдачи по порядку.
---@param results TntDocsResults
---@return string[]
local function urls_of(results)
    local urls = {}

    for _, item in ipairs(results.items) do
        table.insert(urls, item.url)
    end

    return urls
end

g.test_a_query_is_a_trimmed_string = function()
    t.assert_equals(search.text('  шаблоны \n'), 'шаблоны')
    t.assert_equals(search.text(nil), '')
    -- Повторённое поле приходит списком — такого запроса форма не шлёт.
    t.assert_equals(search.text({ 'a', 'b' }), '')
end

g.test_another_form_of_a_word_finds_the_word = function()
    local results = assert(search.run(g.edition, 'шаблонов', 10))

    t.assert_equals(results.query, 'шаблонов')
    t.assert_equals(results.partial, false)
    t.assert_equals(results.total, #results.items)
    t.assert_items_equals(urls_of(results), {
        '/docs/guide',
        '/docs/guide#шаблоны',
        '/docs/guide#каталог',
        '/docs/cluster',
    })
end

g.test_a_hit_names_its_page_section_and_snippet = function()
    local results = assert(search.run(g.edition, 'каталог шаблонов', 10))

    t.assert_equals(results.items, {
        {
            title = 'Руководство tnt',
            section = 'Каталог',
            url = '/docs/guide#каталог',
            snippet = '<mark>Каталог</mark> <mark>шаблонов</mark> лежит рядом.',
        },
    })

    -- У вступления раздела нет: его заголовок — заголовок страницы.
    local intro = assert(search.run(g.edition, 'конфигурации', 10))

    t.assert_equals(intro.items[1].section, nil)
    t.assert_equals(intro.items[1].title, 'Кластер')
    t.assert_equals(intro.items[1].url, '/docs/cluster')
end

g.test_all_the_words_go_first_and_any_of_them_after = function()
    local together = assert(search.run(g.edition, 'узлы кластера', 10))

    t.assert_equals(together.partial, false)
    t.assert_items_equals(urls_of(together), { '/docs/cluster', '/docs/cluster#узлы' })

    -- Вместе этих слов нет нигде — тогда хоть одно, с пометкой.
    local apart = assert(search.run(g.edition, 'установка кластера', 10))

    t.assert_equals(apart.partial, true)
    -- «Установку» во вступлении руководства находит та же основа.
    t.assert_items_equals(urls_of(apart), { '/docs/install', '/docs/guide', '/docs/cluster', '/docs/cluster#узлы' })

    -- Хоть одно слово нашлось ровно в одном разделе — тоже с пометкой.
    local single = assert(search.run(g.edition, 'конфигурации нигде', 10))

    t.assert_equals(single.partial, true)
    t.assert_equals(urls_of(single), { '/docs/cluster' })

    -- Одно слово, которого нет, — пусто без пометки: искать порознь нечего.
    local none = assert(search.run(g.edition, 'нигде', 10))

    t.assert_equals({ none.total, none.partial }, { 0, false })

    -- Ни одно из слов — тоже пусто и без пометки.
    local neither = assert(search.run(g.edition, 'нигде никогда', 10))

    t.assert_equals({ neither.total, neither.partial }, { 0, false })
end

g.test_a_snippet_is_cut_to_its_length = function()
    t.assert_equals(search.SNIPPET, 180)

    local edition = table.copy(g.edition)
    local place = g.edition.sections['cluster#']
    local text = ('слово '):rep(40) .. 'конфигурации ' .. ('слово '):rep(40)

    edition.sections = { ['cluster#'] = { page = place.page, url = place.url, section = { anchor = '', text = text } } }

    local snippet = assert(search.run(edition, 'конфигурации', 10)).items[1].snippet
    local shown = snippet:gsub('</?mark>', '')

    -- Окно — целые слова вокруг совпадения, не длиннее предела.
    t.assert_equals(
        shown,
        '…' .. ('слово '):rep(14) .. 'конфигурации' .. (' слово'):rep(14) .. '…'
    )
end

g.test_the_hits_beyond_the_limit_are_counted_but_not_given = function()
    local results = assert(search.run(g.edition, 'шаблонов', 2))

    t.assert_equals(#results.items, 2)
    t.assert_equals(results.total, 4)
end

g.test_an_empty_query_finds_nothing_and_is_a_json_list = function()
    local results = assert(search.run(g.edition, '', 10))

    t.assert_equals({ results.total, results.partial }, { 0, false })
    t.assert_equals(json.encode(results.items), '[]')
end

g.test_a_query_longer_than_the_limit_is_a_refusal = function()
    t.assert_equals(search.QUERY_LENGTH, 200)

    -- Предел — в знаках, а не в байтах: кириллица идёт по два байта.
    t.assert(search.run(g.edition, ('я'):rep(200), 10))

    local results, refusal = search.run(g.edition, ('я'):rep(201), 10)

    t.assert_equals(results, nil)
    t.assert_equals(refusal, { status = 400, message = 'запрос длиннее 200 знаков' })

    -- Битая строка меряется байтами.
    t.assert(search.run(g.edition, ('\xff'):rep(200), 10))
    t.assert_equals(select(2, search.run(g.edition, ('\xff'):rep(201), 10)).status, 400)
end

g.test_a_section_the_edition_does_not_know_is_not_given = function()
    -- Указатель общий у изданий, и пока собирается следующее, в нём есть
    -- разделы, которых в этом издании ещё нет.
    local edition = table.copy(g.edition)

    edition.sections = table.copy(g.edition.sections)
    edition.sections['cluster#'] = nil

    local results = assert(search.run(edition, 'конфигурации', 10))

    t.assert_equals(results.items, {})
    t.assert_equals(results.total, 0)
end
