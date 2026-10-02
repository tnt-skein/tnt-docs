--- Примеры `docs/docs.md`: документ обязан совпадать с кодом, и каждый
--- его пример исполняется здесь тем же вызовом. Каталоги разметки
--- примеров — временные, вместо `docs` и сводов, порт — свободный,
--- вместо 8088.

local fio = require('fio')
local http = require('http.client')
local json = require('json')
local server = require('http.server')
local t = require('luatest')
local yaml = require('yaml')

local helper = dofile('test/helper.lua')

local docs = helper.docs
local menu = helper.part('menu')
local role = helper.part('role')

local g = t.group('tnt.docs.examples')

--- Документы примеров.
local FILES = {
    ['install.md'] = table.concat({
        '# Установка',
        '',
        'Пакет ставится одной командой. Смотрите [заметки](drafts.md) и [использование](usage.md#шаги).',
        '',
        '## Шаги',
        '',
        'Сборка из каталога пакета.',
    }, '\n'),
    ['usage.md'] = '# Использование\n\nКак пользоваться.\n\n## Шаги\n\nПорядок работы.',
    ['api.md'] = '# Справочник API\n\nВызовы.',
    ['changelog.md'] = '# Изменения\n\nЧто нового.',
    ['drafts.md'] = '# Черновики\n\nДля своих.',
}

--- Файл меню из документа.
local MENU = table.concat({
    '## Пролог',
    '',
    '- [Обзор](/docs/guide/overview)',
    '- [Что нового](/docs/guide/releases) {позже}',
    '- [Что впереди](/docs/plan)',
    '',
    '## Основы',
    '',
    '- [Маршруты](/docs/guide/routing)',
    '- [Генерация ссылок](/docs/guide/urls) {частично}',
}, '\n')

g.before_all(function()
    g.dir = helper.directory(FILES)
end)

g.after_all(function()
    helper.remove(g.dir)
end)

g.after_each(function()
    role.stop()
    package.loaded['app.docs'] = nil
end)

--- Настройки примера с каталогом проверки и шаблонами дерева.
---@param options table
---@return table
local function here(options)
    options.directory = g.dir
    options.views = helper.VIEWS
    options.warm = false

    return options
end

--- Просит страницу у поднятого сервера.
---@param port integer
---@param path string
---@return table
local function get(port, path)
    return http.get(('http://127.0.0.1:%d%s'):format(port, path), { timeout = 30 })
end

--- Страница раздела напрямую, без сервера.
---@param site TntRouter
---@param path string
---@param query table|nil
---@return table
local function page(site, path, query)
    return site.dispatch({ method = 'GET', path = path, query = query })
end

g.test_the_header = function()
    local port = helper.testing.free_port()
    local httpd = server.new('127.0.0.1', port, { log_requests = false, idle_timeout = 60 })

    docs.new(here({})).attach(httpd)
    httpd:start()

    local response = get(port, '/docs/install')

    httpd:stop()
    t.assert_equals(response.status, 200)
end

g.test_how_to_make_a_section = function()
    local port = helper.testing.free_port()
    local httpd = server.new('127.0.0.1', port, { log_requests = false, idle_timeout = 60 })

    docs.new(here({
        title = 'Документация',
        groups = {
            { title = 'Начало', pages = { 'install', 'usage' } },
            { title = 'Справочник', pages = { 'api' } },
        },
        hidden = { 'drafts' },
    })).attach(httpd)

    httpd:start()

    local index = get(port, '/docs')
    local drafts = get(port, '/docs/drafts')

    httpd:stop()
    t.assert_equals(index.status, 200)
    t.assert_str_contains(index.body, '<h2 id="docs-index-2">Справочник</h2>')
    t.assert_equals(drafts.status, 404)
end

g.test_a_bad_setting_is_named = function()
    t.assert_error_msg_contains(
        'настройки раздела: ключа «hiden» нет, есть card, directory, frame, groups, hidden, menu, plan, '
            .. 'prefix, recheck, rest, roots, start, suggestions, title, views, warm',
        docs.new,
        { directory = 'docs', hiden = { 'drafts' } }
    )
end

g.test_the_mount_on_the_router_of_the_application = function()
    local router = require('tnt.router')

    local app = router.new()

    app.get('/', function()
        return app.html('<p>главная</p>')
    end)

    docs.new(here({})).mount(app)

    t.assert_equals(app.dispatch({ method = 'GET', path = '/' }).body, '<p>главная</p>')
    t.assert_equals(app.dispatch({ method = 'GET', path = '/docs/install' }).status, 200)
end

g.test_the_routes_of_an_application = function()
    local route = require('tnt.router').new()
    local container = {
        get = function(_, name)
            t.assert_equals(name, 'docs')

            return docs.new(here({}))
        end,
    }

    -- routes/web.lua
    local routes = function(router, app)
        app:get('docs').mount(router)
    end

    routes(route, container)
    t.assert_equals(route.dispatch({ method = 'GET', path = '/docs/usage' }).status, 200)
end

g.test_the_addresses = function()
    local site = docs.new(here({ hidden = { 'drafts' } }))

    t.assert_equals(page(site, '/docs/install').status, 200)
    t.assert_equals(page(site, '/docs/install/source').headers['content-type'], 'text/plain; charset=utf-8')
    t.assert_equals(page(site, '/docs/drafts').status, 404)
    t.assert_equals(page(site, '/').headers.location, '/docs')
end

g.test_the_roots = function()
    local root = fio.tempdir()

    t.assert(fio.mktree(fio.pathjoin(root, 'resources/docs/guide')))
    t.assert(fio.mktree(fio.pathjoin(root, 'kit/docs')))
    helper.write(
        fio.pathjoin(root, 'resources/docs/guide/install.md'),
        '# Установка\n\nСмотрите [маршруты](../packages/router.md#шаги), '
            .. '[план](../packages/plan.md)\nи [код](../../app.lua).'
    )
    helper.write(fio.pathjoin(root, 'kit/docs/router.md'), '# Маршруты\n\n## Шаги\n\nТекст.')
    helper.write(fio.pathjoin(root, 'kit/docs/plan.md'), '# План')

    local site = docs.new({
        roots = {
            { section = 'guide', directory = fio.pathjoin(root, 'resources/docs/guide') },
            { section = 'packages', directory = fio.pathjoin(root, 'kit/docs'), hidden = { 'plan' } },
        },
        views = helper.VIEWS,
        warm = false,
    })

    t.assert_equals(page(site, '/docs/guide/install').status, 200)
    t.assert_equals(page(site, '/docs/packages/router').status, 200)
    t.assert_equals(page(site, '/docs/packages/plan').status, 404)
    t.assert_str_contains(
        page(site, '/docs/guide/install').body,
        'Смотрите <a href="/docs/packages/router#шаги">маршруты</a>, план\nи код.'
    )
    t.assert(fio.rmtree(root))
end

g.test_the_menu_file = function()
    t.assert_equals(menu.parse(MENU, '/docs'), {
        {
            title = 'Пролог',
            items = {
                { title = 'Обзор', slug = 'guide/overview', state = 'ready' },
                { title = 'Что нового', slug = 'guide/releases', state = 'later' },
                { title = 'Что впереди', slug = 'plan', state = 'ready' },
            },
        },
        {
            title = 'Основы',
            items = {
                { title = 'Маршруты', slug = 'guide/routing', state = 'ready' },
                { title = 'Генерация ссылок', slug = 'guide/urls', state = 'partial' },
            },
        },
    })
end

g.test_the_groups_and_their_order = function()
    local site = docs.new(here({
        groups = {
            { title = 'Начало', pages = { 'install', 'usage', 'missing' } },
            { title = 'Справочник', pages = { 'usage', 'api' } },
        },
        rest = 'Ещё',
        hidden = { 'drafts' },
    }))

    local body = page(site, '/docs').body --[[@as string]]
    local seen = {}

    for title, cards in body:gmatch('<h2 id="docs%-index%-%d">([^<]*)</h2>(.-)</section>') do
        local names = {}

        for name in cards:gmatch('href="/docs/([%w_%-]*)"') do
            table.insert(names, name)
        end

        table.insert(seen, { title, names })
    end

    t.assert_equals(seen, {
        { 'Начало', { 'install', 'usage' } },
        { 'Справочник', { 'api' } },
        { 'Ещё', { 'changelog' } },
    })
end

g.test_a_hidden_document_is_text_in_a_link = function()
    local site = docs.new(here({ hidden = { 'drafts' } }))

    t.assert_str_contains(
        page(site, '/docs/install').body,
        'Смотрите заметки и <a href="/docs/usage#шаги">использование</a>.'
    )
end

g.test_the_plan = function()
    local menu_file = fio.pathjoin(g.dir, 'menu.md')

    helper.write(
        menu_file,
        '## Пролог\n\n- [Установка](/docs/install)\n- [Что нового](/docs/releases) {позже}\n'
    )

    local site = docs.new(here({
        menu = menu_file,
        plan = {
            page = 'plan',
            pages = {
                releases = {
                    about = 'то, что изменилось от выпуска к выпуску',
                    missing = 'выпусков ещё не было',
                    tasks = { '9b4cfd69' },
                    note = 'первый выпуск',
                },
                install = { tasks = { '0ea5dabf' } },
            },
        },
    }))

    local later = page(site, '/docs/releases').body

    t.assert(os.remove(menu_file))
    t.assert_str_contains(
        later,
        'Здесь будет рассказано про то, что изменилось от выпуска к выпуску.'
    )
    t.assert_str_contains(
        later,
        'Сейчас этой возможности в наборе нет: выпусков ещё не было.'
    )
    t.assert_str_contains(later, 'Задача на разработку — <code>9b4cfd69</code>.')
    t.assert_str_contains(
        page(site, '/docs/plan').body,
        'Всего страниц в своде — 2; написано — 1; впереди — 1.'
    )
end

g.test_the_start = function()
    local site = docs.new(here({ start = '/docs/install' }))

    t.assert_equals(page(site, '/docs').headers.location, '/docs/install')
end

g.test_the_card_of_a_package = function()
    local site = docs.new(here({
        card = function(name, section)
            t.assert_equals(section, nil)

            if name == 'install' then
                return {
                    name = 'app-kit',
                    install = 'tt rocks install app-kit',
                    repository = 'https://example.org/app-kit',
                }
            end
        end,
    }))

    local body = page(site, '/docs/install').body

    t.assert_str_contains(body, '<a href="https://example.org/app-kit"')
    t.assert_str_contains(body, '        app-kit\n    </a>')
    t.assert_str_contains(body, '<pre><code class="language-bash">tt rocks install app-kit</code></pre>')
    t.assert_not_str_contains(page(site, '/docs/usage').body, 'docs-package')
end

g.test_the_search = function()
    local site = docs.new(here({}))

    local answer = page(site, '/docs/search.json', { q = 'шаги сборки' })
    local found = json.decode(answer.body)

    t.assert_equals(found, {
        query = 'шаги сборки',
        total = 1,
        partial = false,
        items = {
            {
                title = 'Установка',
                section = 'Шаги',
                url = '/docs/install#шаги',
                snippet = '<mark>Сборка</mark> из каталога пакета.',
            },
        },
    })
end

g.test_the_suggestions = function()
    local site = docs.new(here({
        suggestions = {
            { icon = 'book', title = 'Установка', note = 'С чего начать.', href = '/docs/install' },
        },
    }))

    local window = page(site, '/docs/search.html').body

    t.assert_str_contains(window, '<a href="/docs/install" class="docs-search-suggestion text-decoration-none">')
    t.assert_str_contains(window, '<span>С чего начать.</span>')
end

g.test_the_frame = function()
    local site = docs.new(here({
        frame = {
            brand = 'kit',
            home = '/',
            description = 'Приложение на узле Tarantool.',
            menu = {
                { title = 'Главная', href = '/' },
                { title = 'Документация', href = '/docs' },
                {
                    title = 'Больше',
                    columns = {
                        { { icon = 'box', title = 'Ядро', note = 'Роль узла', href = '/about#kernel' } },
                    },
                },
            },
            links = {
                { title = 'Tarantool', href = 'https://www.tarantool.io/ru/doc/latest/', icon = 'book' },
                { title = 'Исходники', href = 'https://example.org/kit' },
            },
            footer = {
                note = 'Стоит на Tarantool 3: [исходники](https://example.org/kit).',
                columns = { { title = 'Разделы', links = { { title = 'Главная', href = '/' } } } },
                signature = 'узел kit-001 · среда local',
            },
        },
    }))

    local body = page(site, '/docs/install').body

    t.assert_str_contains(body, '<title>Установка · kit</title>')
    t.assert_str_contains(body, '<a href="/docs" class="nav-link px-3 link-body-emphasis active">')
    t.assert_str_contains(body, '<span class="d-block">Ядро</span>')
    t.assert_str_contains(
        body,
        '<p>Стоит на Tarantool 3: <a href="https://example.org/kit">исходники</a>.</p>'
    )
    t.assert_str_contains(body, 'узел kit-001 · среда local')
end

g.test_the_role = function()
    local cfg = yaml.decode(table.concat({
        'roles: [tnt.docs.role]',
        'roles_cfg:',
        '  tnt.docs.role:',
        '    listen: 127.0.0.1:8088',
        '    directory: docs',
        '    groups:',
        '      - { title: Начало, pages: [install, usage] }',
        '    hidden: [drafts]',
        '    options: app.docs',
    }, '\n'))

    package.loaded['app.docs'] = {
        card = function(name)
            return { name = 'app-' .. name, install = 'tt rocks install app-' .. name }
        end,
    }

    local settings = cfg.roles_cfg['tnt.docs.role']
    local port = helper.testing.free_port()

    t.assert_equals(cfg.roles, { 'tnt.docs.role' })
    settings.listen = ('127.0.0.1:%d'):format(port)

    role.validate(here(settings))
    role.apply(settings)

    local body = get(port, '/docs/install').body

    t.assert_str_contains(body, '<span class="docs-context-item">app-install</span>')
    t.assert_str_contains(body, '<pre><code class="language-bash">tt rocks install app-install</code></pre>')
    t.assert_equals(get(port, '/docs/drafts').status, 404)
end

g.test_the_refusal_of_the_role = function()
    t.assert_error_msg_equals(
        'listen — порт от 1 до 65535 либо «узел:порт», а не 0',
        role.validate,
        { listen = 0, directory = 'docs' }
    )
end
