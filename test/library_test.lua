--- Проверки библиотеки раздела: издание по сводам и меню, сборка заново
--- только по правке разметки, отказы документов, ожидание сборки
--- и прогрев в фоне.

local fiber = require('fiber')
local fio = require('fio')
local fun = require('fun')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local library_of = helper.part('library')

local g = t.group('tnt.docs.library')

g.after_each(function()
    library_of._set_source(nil)

    if g.dir ~= nil then
        helper.remove(g.dir)
        g.dir = nil
    end
end)

--- Настройки библиотеки: умолчания проверки, поверх — свои и названные.
---@param own table
---@param options table|nil
---@return TntDocsLibraryOptions
local function settings_of(own, options)
    ---@type any
    local settings = {
        prefix = '/docs',
        rest = 'Прочее',
        plan = { pages = {} },
        recheck = 0,
        address = helper.address,
    }

    for _, layer in ipairs({ own, options or {} }) do
        for key, value in pairs(layer) do
            settings[key] = value
        end
    end

    return settings
end

--- Библиотека над временным каталогом разметки проверки.
---@param files table<string, string|table>
---@param options table|nil Поверх умолчаний проверки
---@return TntDocsLibrary
local function library(files, options)
    g.dir = helper.directory(files)

    return library_of.new(settings_of({
        roots = { { directory = g.dir, hidden = { plan = true } } },
        groups = { { title = 'Начало', pages = { 'install', 'guide' } } },
    }, options))
end

--- Издание; отказа здесь не ждут.
---@param shelf TntDocsLibrary
---@return TntDocsEdition
local function edition_of(shelf)
    local edition, err = shelf:edition()

    t.assert_equals(err, nil)

    return assert(edition)
end

--- Имена страниц или отказов издания по порядку.
---@param map table<string, any>
---@return string[]
local function names_of(map)
    -- Обход таблицы отдаёт пары, а в список ложится первое — имя.
    local names = fun.iter(map):totable()

    table.sort(names)

    return names
end

g.test_an_edition_holds_the_pages_of_the_directory = function()
    local shelf = library({
        ['guide.md'] = helper.GUIDE,
        ['install.md'] = helper.INSTALL,
        -- Скрытая, негодная в адрес, без имени и не разметка — не страницы.
        ['plan.md'] = '# План',
        ['my notes.md'] = '# Заметки',
        ['.md'] = '# Без имени',
        ['notes.txt'] = '# Не разметка',
    })

    local edition = edition_of(shelf)

    t.assert_equals(names_of(edition.pages), { 'guide', 'install' })
    t.assert_equals(edition.failures, {})
    t.assert_equals(edition.pages.guide.title, 'Руководство tnt')
    -- Ссылка на соседа — адрес, на скрытый и несуществующий — текст.
    t.assert_str_contains(
        edition.pages.guide.body,
        '<p>Смотрите <a href="/docs/install#шаги">установку</a>, план и черновик.</p>'
    )
    t.assert_equals(assert(edition.navigation.groups[1]).title, 'Начало')
    t.assert_equals(#edition.navigation.order, 2)
    t.assert_is(edition.finder, shelf.finder)
    t.assert_is(edition.words, shelf.words)
end

g.test_the_sections_of_an_edition_know_their_page_and_address = function()
    local edition = edition_of(library({ ['guide.md'] = helper.GUIDE, ['install.md'] = helper.INSTALL }))

    t.assert_equals(
        names_of(edition.sections),
        { 'guide#', 'guide#каталог', 'guide#шаблоны', 'install#', 'install#шаги' }
    )

    local intro = edition.sections['guide#']

    t.assert_is(intro.page, edition.pages.guide)
    t.assert_is(intro.section, edition.pages.guide.sections[1])
    t.assert_equals(intro.url, '/docs/guide')
    t.assert_equals(edition.sections['install#шаги'].url, '/docs/install#шаги')

    local hits = edition.finder:search(edition.words:query('шаблоны'), 'all')
    local ids = {}

    for _, hit in ipairs(hits) do
        table.insert(ids, hit.id)
    end

    table.sort(ids)
    t.assert_equals(ids, { 'guide#', 'guide#каталог', 'guide#шаблоны' })
end

g.test_a_hidden_document_is_not_even_read = function()
    -- Скрытое имя на месте каталога отказало бы чтением, если бы его читали.
    local edition = edition_of(library({ ['guide.md'] = helper.GUIDE, ['plan.md'] = {} }))

    t.assert_equals(edition.failures, {})
    t.assert_equals(names_of(edition.pages), { 'guide' })
end

g.test_a_page_is_drawn_again_only_when_its_markup_changes = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE, ['install.md'] = helper.INSTALL })
    local first = edition_of(shelf)
    local guide, install = first.pages.guide, first.pages.install

    -- Та же разметка, записанная заново, — та же страница.
    helper.write(fio.pathjoin(g.dir, 'guide.md'), helper.GUIDE)
    t.assert_is(edition_of(shelf).pages.guide, guide)

    -- Правка видна со следующего издания, и разбирается только она.
    helper.write(fio.pathjoin(g.dir, 'guide.md'), '# Новое\n\nПро кластер.')

    local second = edition_of(shelf)

    t.assert_equals(second.pages.guide.title, 'Новое')
    t.assert_is(second.pages.install, install)
    -- Указатель забыл прежние разделы страницы и знает новые.
    t.assert_equals(second.finder:search(second.words:query('шаблоны'), 'all'), {})
    t.assert_equals(assert(second.finder:search(second.words:query('кластер'), 'all')[1]).id, 'guide#')
end

g.test_a_new_or_removed_document_draws_the_links_again = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE, ['install.md'] = helper.INSTALL })
    local before = edition_of(shelf).pages.install

    helper.write(fio.pathjoin(g.dir, 'nowhere.md'), '# Черновик')

    local added = edition_of(shelf)

    t.assert_str_contains(added.pages.guide.body, '<a href="/docs/nowhere">черновик</a>')
    -- Состав другой — пересобраны все страницы, и неизменные тоже.
    t.assert_is_not(added.pages.install, before)
    t.assert_equals(added.pages.install, before)

    t.assert(os.remove(fio.pathjoin(g.dir, 'nowhere.md')))

    local removed = edition_of(shelf)

    t.assert_str_contains(removed.pages.guide.body, 'план и черновик.')
    t.assert_equals(removed.pages.nowhere, nil)
    t.assert_equals(removed.sections['nowhere#'], nil)
    t.assert_equals(shelf.finder.documents['nowhere#'], nil)
    t.assert_equals(shelf.known.nowhere, nil)
end

g.test_the_directory_is_checked_once_in_a_while = function()
    local now = 100

    library_of._set_source({
        now = function()
            return now
        end,
    })

    local shelf = library({ ['guide.md'] = helper.GUIDE }, { recheck = 10 })
    local first = edition_of(shelf)

    helper.write(fio.pathjoin(g.dir, 'guide.md'), '# Новое')

    now = 109
    t.assert_is(edition_of(shelf), first)

    now = 110

    local second = edition_of(shelf)

    t.assert_equals(second.pages.guide.title, 'Новое')
    t.assert_equals(shelf.checked, 110)
end

g.test_a_document_that_can_not_be_read_or_drawn_is_a_failure_of_its_own = function()
    local journal = helper.testing.capture_log()
    local shelf = library({
        ['guide.md'] = helper.GUIDE,
        ['broken.md'] = {},
        ['large.md'] = ('x'):rep(1024 * 1024 + 1),
    })

    local edition = edition_of(shelf)

    journal.release()

    t.assert_equals(names_of(edition.pages), { 'guide' })
    t.assert_equals(names_of(edition.failures), { 'broken', 'large' })
    t.assert_equals(edition.failures.broken.kind, 'failed')
    t.assert_equals(edition.failures.large.kind, 'too_large')
    -- Поломку разбора видно в журнале сразу, а не когда документ откроют.
    t.assert_equals(#journal.find_all('документ не собран'), 1)
    t.assert(journal.logged('name=large'))

    -- Та же разметка второй раз не разбирается и в журнал не пишется.
    local again = helper.testing.capture_log()

    t.assert_equals(edition_of(shelf).failures.large.kind, 'too_large')
    again.release()
    t.assert_equals(again.find_all('документ не собран'), {})
end

g.test_a_document_gone_between_the_search_and_the_read_is_no_page = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE })

    -- Ссылка в никуда: поиск файл находит, а чтение — уже нет.
    t.assert(fio.symlink(fio.pathjoin(g.dir, 'gone'), fio.pathjoin(g.dir, 'ghost.md')))

    local edition = edition_of(shelf)

    t.assert_equals(names_of(edition.pages), { 'guide' })
    t.assert_equals(edition.failures, {})
end

g.test_a_directory_that_is_not_there_refuses_the_edition = function()
    local shelf = library({})
    local directory = fio.pathjoin(g.dir, 'docs')

    assert(shelf.options.roots[1]).directory = directory

    local edition, err = shelf:edition()

    t.assert_equals(edition, nil)
    t.assert_equals(assert(err).kind, 'missing')
    t.assert_is(shelf.failure, err)

    -- Следующее обращение пробует снова, и каталог, появившийся
    -- позже, становится изданием.
    t.assert(fio.mkdir(directory))
    helper.write(fio.pathjoin(directory, 'guide.md'), helper.GUIDE)

    t.assert_equals(names_of(edition_of(shelf).pages), { 'guide' })
    t.assert_equals(shelf.failure, nil)

    -- Пропавший каталог — снова отказ, а прежнее издание остаётся
    -- последним собранным: по нему рисуются страницы отказов.
    local latest = shelf.latest

    t.assert(fio.rmtree(directory))

    local gone, why = shelf:edition()

    t.assert_equals(gone, nil)
    t.assert_equals(assert(why).kind, 'missing')
    t.assert_is(shelf.latest, latest)
end

g.test_while_an_edition_is_built_the_others_get_the_former = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE })
    local former = edition_of(shelf)

    helper.write(fio.pathjoin(g.dir, 'guide.md'), '# Новое')

    local open = helper.hold(library_of)
    local built = {}
    local builder = fiber.create(function()
        built.edition = shelf:edition()
    end)

    -- Сборка встала на уступке после разбора, а соседний запрос
    -- получает прежнее издание сразу, не дожидаясь её.
    t.assert_not_equals(shelf.building, nil)
    t.assert_is(shelf:edition(), former)

    open()
    t.helpers.retrying({ timeout = 5 }, function()
        t.assert_equals(builder:status(), 'dead')
    end)

    t.assert_equals(assert(built.edition).pages.guide.title, 'Новое')
    t.assert_is(shelf.latest, built.edition)
    t.assert_equals(shelf.building, nil)
end

g.test_the_first_edition_is_awaited_by_everyone = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE })
    local open = helper.hold(library_of)
    local got = {}

    local first = fiber.create(function()
        got.first = shelf:edition()
    end)
    local second = fiber.create(function()
        got.second = shelf:edition()
    end)

    t.assert_equals(got, {})

    open()
    t.helpers.retrying({ timeout = 5 }, function()
        t.assert_equals({ first:status(), second:status() }, { 'dead', 'dead' })
    end)

    t.assert_is(got.second, got.first)
    t.assert_equals(assert(got.first).pages.guide.title, 'Руководство tnt')
end

g.test_a_breakdown_inside_the_build_wakes_the_waiters_and_goes_further = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE })
    local held = true
    local opened = fiber.cond()

    library_of._set_source({
        yield = function()
            while held do
                opened:wait()
            end

            error('сборка сломалась')
        end,
    })

    local got = {}
    local builder = fiber.create(function()
        got.builder = { pcall(shelf.edition, shelf) }
    end)
    local waiter = fiber.create(function()
        got.waiter = { shelf:edition() }
    end)

    held = false
    opened:broadcast()
    t.helpers.retrying({ timeout = 5 }, function()
        t.assert_equals({ builder:status(), waiter:status() }, { 'dead', 'dead' })
    end)

    t.assert_equals(got.builder[1], false)
    t.assert_str_contains(got.builder[2], 'сборка сломалась')
    -- Ждущий проснулся: издания нет, но и вечного ожидания нет.
    t.assert_equals(got.waiter, {})
    t.assert_equals(shelf.building, nil)

    library_of._set_source(nil)
    t.assert_equals(edition_of(shelf).pages.guide.title, 'Руководство tnt')
end

g.test_warm_builds_the_first_edition_in_the_background = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE })
    local open = helper.hold(library_of)
    local warming = shelf:warm()

    t.assert_equals(warming:name(), 'tnt.docs.warm')
    t.assert_equals(shelf.latest, nil)

    open()

    -- Первый запрос ждёт той же сборки, а не начинает свою.
    t.assert_equals(edition_of(shelf).pages.guide.title, 'Руководство tnt')
    t.assert_equals(warming:status(), 'dead')
end

g.test_a_warm_that_fails_is_written_to_the_journal = function()
    local shelf = library({})

    assert(shelf.options.roots[1]).directory = fio.pathjoin(g.dir, 'docs')

    local journal = helper.testing.capture_log()
    -- Прогрев, начатый внутри запроса, пишет с его опознавателем.
    local warming = require('tnt.context').run({ request_id = 'r-7' }, function()
        return shelf:warm()
    end)

    t.helpers.retrying({ timeout = 5 }, function()
        t.assert_equals(warming:status(), 'dead')
    end)
    journal.release()

    t.assert(journal.logged('раздел документации не прогрет'))
    t.assert(journal.logged('docs не'))
    t.assert(journal.logged('request_id=r-7'))
end

--- Своды проверки: руководство и документы пакетов в соседних каталогах.
---@param options table|nil Поверх умолчаний проверки
---@return TntDocsLibrary
local function shelves(options)
    g.dir = helper.directory({ framework = {}, packages = {} })
    helper.write(
        fio.pathjoin(g.dir, 'framework', 'guide.md'),
        '# Руководство\n\nСм. [маршруты](../packages/router.md#шаги), '
            .. '[план](../packages/plan.md) и [код](../../app.lua).'
    )
    helper.write(
        fio.pathjoin(g.dir, 'packages', 'router.md'),
        '# Маршруты\n\nК [руководству](../framework/guide.md).\n\n## Шаги\n\nТекст.'
    )
    helper.write(fio.pathjoin(g.dir, 'packages', 'plan.md'), '# План для своих')

    return library_of.new(settings_of({
        roots = {
            { section = 'framework', directory = fio.pathjoin(g.dir, 'framework'), hidden = {} },
            { section = 'packages', directory = fio.pathjoin(g.dir, 'packages'), hidden = { plan = true } },
        },
        groups = { { title = 'Пакеты', section = 'packages', pages = { 'router', 'plan' } } },
    }, options))
end

g.test_the_pages_of_the_roots_are_addressed_by_their_section = function()
    local shelf = shelves()
    local edition = edition_of(shelf)

    t.assert_equals(names_of(edition.pages), { 'framework/guide', 'packages/router' })
    t.assert_equals(shelf.hidden, { ['packages/plan'] = true })
    -- Ссылка в соседний свод — адрес его страницы; на скрытый документ
    -- и на файл репозитория выше сводов — текст.
    t.assert_str_contains(
        edition.pages['framework/guide'].body,
        'См. <a href="/docs/packages/router#шаги">маршруты</a>, план и код.'
    )
    t.assert_str_contains(
        edition.pages['packages/router'].body,
        '<a href="/docs/framework/guide">руководству</a>'
    )
    t.assert_equals(edition.sections['packages/router#шаги'].url, '/docs/packages/router#шаги')

    local group = assert(edition.navigation.groups[1])

    t.assert_equals(group.title, 'Пакеты')
    t.assert_equals(#group.entries, 1)
    t.assert_equals(assert(group.entries[1]).address, '/docs/packages/router')
end

g.test_the_menu_file_lays_the_groups_out_first = function()
    local shelf = shelves()

    shelf.options.menu = fio.pathjoin(g.dir, 'menu.md')
    helper.write(
        shelf.options.menu,
        '## Основы\n\n- [Гид](/docs/framework/guide)\n- [Кэш](/docs/framework/cache) {позже}\n'
            .. '- [План](/docs/packages/plan)\n'
    )

    local navigation = edition_of(shelf).navigation
    local first = assert(navigation.groups[1])

    t.assert_equals(first.title, 'Основы')
    -- Скрытый документ не стоит и в меню; ненаписанная страница — заглушка.
    t.assert_equals(#first.entries, 2)
    t.assert_equals(assert(first.entries[1]).title, 'Гид')
    t.assert_equals(assert(first.entries[2]).kind, 'upcoming')
    t.assert_equals(assert(navigation.groups[2]).title, 'Пакеты')

    -- Меню читается на каждой сверке: правка видна без перезапуска.
    helper.write(shelf.options.menu, '## Иначе\n\n- [Гид](/docs/framework/guide)\n')
    t.assert_equals(assert(edition_of(shelf).navigation.groups[1]).title, 'Иначе')
end

g.test_a_menu_that_is_not_there_or_not_understood_refuses_the_edition = function()
    local shelf = shelves()

    shelf.options.menu = fio.pathjoin(g.dir, 'menu.md')

    local edition, err = shelf:edition()

    t.assert_equals(edition, nil)
    t.assert_equals(assert(err).kind, 'missing')

    helper.write(shelf.options.menu, '## Основы\n\n- [Гид](/docs/framework/guide) {скоро}\n')

    local again, why = shelf:edition()

    t.assert_equals(again, nil)
    t.assert_equals(
        why,
        'в меню метка {скоро} неизвестна: есть {позже} и {частично}'
    )
end

g.test_a_broken_document_named_in_the_menu_is_a_page_and_not_a_promise = function()
    local shelf = shelves()

    shelf.options.menu = fio.pathjoin(g.dir, 'menu.md')
    helper.write(shelf.options.menu, '## Основы\n\n- [Сломан](/docs/framework/broken)\n')
    t.assert(fio.mkdir(fio.pathjoin(g.dir, 'framework', 'broken.md')))

    local edition = edition_of(shelf)

    t.assert_equals(edition.failures['framework/broken'].kind, 'failed')
    t.assert_equals(assert(assert(edition.navigation.groups[1]).entries[1]).kind, 'page')
end

g.test_a_document_at_the_address_of_the_plan_is_not_read = function()
    local shelf = library({ ['guide.md'] = helper.GUIDE, ['plan.md'] = {}, ['todo.md'] = {} }, {
        plan = { page = 'todo', pages = {} },
    })

    assert(shelf.options.roots[1]).hidden = { plan = true }

    local edition = edition_of(shelf)

    -- На месте документа — каталог: прочти его библиотека, был бы отказ.
    t.assert_equals(edition.failures, {})
    t.assert_equals(names_of(edition.pages), { 'guide' })
end

g.test_a_section_of_the_roots_that_is_not_there_refuses_the_edition = function()
    local shelf = shelves()

    assert(shelf.options.roots[2]).directory = fio.pathjoin(g.dir, 'nowhere')

    local edition, err = shelf:edition()

    t.assert_equals(edition, nil)
    t.assert_equals(assert(err).kind, 'missing')
end
