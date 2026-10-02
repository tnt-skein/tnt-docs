--- Проверки настроек раздела: отказ словом, умолчания и каталог шаблонов
--- пакета.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local settings = helper.part('settings')

local g = t.group('tnt.docs.settings')

g.after_each(function()
    settings._set_source(nil)
end)

--- Поиск модуля, который находит пакет по названному пути.
---@param path string|nil
---@return table asked Какие имена спрашивали
local function found_at(path)
    local asked = {}

    settings._set_source({
        search = function(name)
            table.insert(asked, name)

            return path
        end,
    })

    return asked
end

g.test_good_settings_have_nothing_to_explain = function()
    t.assert_equals(settings.explain({ directory = 'docs' }), nil)
    t.assert_equals(
        settings.explain({
            directory = 'docs',
            prefix = '/help/docs-2_x',
            title = 'Справка',
            start = '/help/docs-2_x/install',
            menu = 'docs/menu.md',
            groups = { { title = 'Начало', pages = { 'install' } } },
            rest = 'Ещё',
            hidden = { 'plan' },
            plan = { page = 'plan', pages = { install = { about = 'установку', tasks = { 'a1' } } } },
            suggestions = {
                { icon = 'book', title = 'Обзор', note = 'С чего начать.', href = '/help' },
            },
            card = function() end,
            frame = { brand = 'skein', menu = { { title = 'Главная', href = '/' } } },
            recheck = 0,
            warm = false,
            views = 'views',
        }),
        nil
    )
    t.assert_equals(settings.explain({ roots = { { section = 'packages', directory = 'docs' } } }), nil)
    t.assert_equals(
        settings.explain({
            roots = {
                { section = 'framework', directory = 'docs/framework' },
                { section = 'packages', directory = '/tree/docs', hidden = { 'plan' } },
            },
            groups = { { title = 'Пакеты', section = 'packages', pages = { 'router' } } },
        }),
        nil
    )
end

g.test_a_bad_setting_is_named = function()
    local cases = {
        { nil, 'настройки раздела — таблица, а не nil' },
        {
            {},
            'настройки раздела: разметка — каталог directory либо своды roots, ровно одно',
        },
        {
            { directory = 'docs', roots = { { section = 'a', directory = 'a' } } },
            'настройки раздела: разметка — каталог directory либо своды roots, ровно одно',
        },
        {
            { directory = 'docs', hiden = {} },
            'настройки раздела: ключа «hiden» нет, есть card, directory, frame, groups, '
                .. 'hidden, menu, plan, prefix, recheck, rest, roots, start, suggestions, title, views, warm',
        },
        {
            { directory = 'docs', prefix = 'docs' },
            'настройки раздела.prefix — строка по образцу '
                .. '^/[%w_%-/]*[%w_%-]$, а не «docs»',
        },
        {
            { directory = 'docs', prefix = '/docs/' },
            'настройки раздела.prefix — строка по образцу '
                .. '^/[%w_%-/]*[%w_%-]$, а не «/docs/»',
        },
        {
            { directory = 'docs', start = 'docs/install' },
            'настройки раздела.start — строка по образцу ^/, а не «docs/install»',
        },
        {
            { directory = 'docs', menu = '' },
            'настройки раздела.menu — непустая строка, а не пустая',
        },
        {
            { directory = 'docs', groups = { { title = 'Начало', pages = { 1 } } } },
            'настройки раздела.groups[1].pages[1]'
                .. ' — непустая строка, а не число',
        },
        {
            { directory = 'docs', groups = { { pages = {} } } },
            'настройки раздела.groups[1].title — непустая строка, а не nil',
        },
        {
            { directory = 'docs', groups = { { title = 'Пакеты', section = 'packages', pages = {} } } },
            'настройки раздела.groups[1].section «packages» — такого свода нет',
        },
        {
            { directory = 'docs', hidden = 'plan' },
            'настройки раздела.hidden — массив, а не строка',
        },
        {
            { roots = { { section = 'a', directory = 'a' } }, hidden = { 'plan' } },
            'настройки раздела.hidden — у каталога directory; скрытые документы свода — roots[…].hidden',
        },
        { { roots = {} }, 'настройки раздела.roots — хотя бы один свод' },
        {
            { roots = { { section = 'a b', directory = 'a' } } },
            'настройки раздела.roots[1].section — строка по образцу ^[%w_%-]+$, а не «a b»',
        },
        {
            { roots = { { section = 'a', directory = 'a' }, { section = 'assets', directory = 'b' } } },
            'настройки раздела.roots[2].section «assets» занят видом раздела',
        },
        {
            { roots = { { section = 'a', directory = 'a' }, { section = 'a', directory = 'b' } } },
            'настройки раздела.roots[2].section «a» уже назван',
        },
        {
            { directory = 'docs', plan = { page = 'a/b' } },
            'настройки раздела.plan.page — строка по образцу ^[%w_%-]+$, а не «a/b»',
        },
        {
            { directory = 'docs', plan = { pages = { [1] = {} } } },
            'настройки раздела.plan.pages — адрес страницы ключом, а не number',
        },
        {
            { directory = 'docs', plan = { pages = { install = { tasks = 'a1' } } } },
            'настройки раздела.plan.pages[«install»].tasks — массив, а не строка',
        },
        {
            { directory = 'docs', suggestions = { { title = 'Обзор' } } },
            'настройки раздела.suggestions[1].href — непустая строка, а не nil',
        },
        {
            { directory = 'docs', suggestions = { { icon = 'star', title = 'Обзор', href = '/' } } },
            'настройки раздела.suggestions[1].icon — одно из «logo», «menu», «book», «box», «code», «search», '
                .. '«route», «database», «bolt», «terminal», «mail», «clock», «shield-check», «arrow-right», '
                .. '«angle-up», «circle-fill», «theme-light», «theme-dark», «theme-auto», а не «star»',
        },
        {
            { directory = 'docs', frame = { url = 'https://example.org/' } },
            'настройки раздела.frame.url — строка по образцу ^https?://.*[^/]$, а не «https://example.org/»',
        },
        {
            { directory = 'docs', frame = { menu = { { title = 'Больше' } } } },
            'настройки раздела.frame.menu[1] — ссылка href либо меню columns, ровно одно',
        },
        {
            { directory = 'docs', card = 'карточка' },
            'настройки раздела.card — функция или вызываемая таблица, а не строка',
        },
        {
            { directory = 'docs', recheck = -1 },
            'настройки раздела.recheck — число не меньше 0, а не -1',
        },
        {
            { directory = 'docs', warm = 'да' },
            'настройки раздела.warm — логическое значение, а не строка',
        },
        {
            { directory = 'docs', title = '' },
            'настройки раздела.title — непустая строка, а не пустая',
        },
        {
            { directory = 'docs', rest = '' },
            'настройки раздела.rest — непустая строка, а не пустая',
        },
        {
            { directory = 'docs', views = '' },
            'настройки раздела.views — непустая строка, а не пустая',
        },
    }

    for _, case in ipairs(cases) do
        t.assert_equals(settings.explain(case[1]), case[2])
    end
end

g.test_the_defaults_fill_what_is_not_given = function()
    local asked = found_at('/rocks/tnt/docs.lua')

    t.assert_equals(settings.read({ directory = 'docs' }), {
        roots = { { directory = 'docs', hidden = {} } },
        sectioned = false,
        prefix = '/docs',
        title = 'Документация',
        groups = {},
        rest = 'Прочее',
        plan = { pages = {} },
        suggestions = {},
        frame = {
            brand = 'Документация',
            home = '/docs',
            locale = 'ru',
            menu = {},
            links = {},
            columns = {},
        },
        recheck = 1,
        warm = true,
        views = '/rocks/tnt/docs/views',
    })
    t.assert_equals(asked, { 'tnt.docs' })
    t.assert_equals(
        { settings.PREFIX, settings.TITLE, settings.REST, settings.RECHECK, settings.RESERVED },
        { '/docs', 'Документация', 'Прочее', 1, 'assets' }
    )
end

g.test_what_is_given_stays_and_hidden_names_become_a_set = function()
    local asked = found_at(nil)
    local card = function() end
    local groups = { { title = 'Начало', pages = { 'install' } } }
    local pages = { install = { about = 'установку' } }
    local suggestions = { { title = 'Обзор', href = '/help' } }

    t.assert_equals(
        settings.read({
            directory = 'docs',
            prefix = '/help',
            title = 'Справка',
            start = '/help/install',
            menu = 'docs/menu.md',
            groups = groups,
            rest = 'Ещё',
            hidden = { 'plan', 'drafts' },
            plan = { page = 'plan', pages = pages },
            suggestions = suggestions,
            card = card,
            frame = { brand = 'skein' },
            recheck = 0,
            warm = false,
            views = 'views',
        }),
        {
            roots = { { directory = 'docs', hidden = { plan = true, drafts = true } } },
            sectioned = false,
            prefix = '/help',
            title = 'Справка',
            start = '/help/install',
            menu = 'docs/menu.md',
            groups = groups,
            rest = 'Ещё',
            plan = { page = 'plan', pages = pages },
            suggestions = suggestions,
            card = card,
            frame = { brand = 'skein', home = '/help', locale = 'ru', menu = {}, links = {}, columns = {} },
            recheck = 0,
            warm = false,
            views = 'views',
        }
    )
    -- Свой каталог шаблонов назван — пакет не ищется.
    t.assert_equals(asked, {})
end

g.test_the_roots_keep_their_sections_and_hidden_names = function()
    found_at(nil)

    local read = settings.read({
        roots = {
            { section = 'framework', directory = 'guide' },
            { section = 'packages', directory = '/tree/docs', hidden = { 'plan' } },
        },
        views = 'views',
    })

    t.assert_equals(read.roots, {
        { section = 'framework', directory = 'guide', hidden = {} },
        { section = 'packages', directory = '/tree/docs', hidden = { plan = true } },
    })
    t.assert_equals(read.sectioned, true)
end

g.test_the_templates_of_the_package_lie_next_to_its_module = function()
    found_at('/rocks/share/tarantool/tnt/docs.lua')

    t.assert_equals(settings.views(), '/rocks/share/tarantool/tnt/docs/views')
end

g.test_a_package_the_loader_does_not_find_has_no_templates = function()
    found_at(nil)

    local ok, err = pcall(settings.views)

    t.assert_not(ok)
    t.assert_equals(
        err,
        'пакет tnt.docs не найден загрузчиком: шаблонов страниц негде взять'
    )
end

g.test_the_real_loader_is_asked_by_default = function()
    -- Без подмены спрашивается `package.search`. Пакет в дереве разработки
    -- лежит мимо пути поиска, поэтому спрашивается сосед, который стоит
    -- всегда: ответ обязан совпасть с ответом загрузчика.
    local anchor = settings.ANCHOR

    settings.ANCHOR = 'tnt.must'

    local ok, views = pcall(settings.views)

    settings.ANCHOR = anchor

    t.assert(ok, views)
    t.assert_equals(views, (package.search('tnt.must'):gsub('%.lua$', '/views')))
end
