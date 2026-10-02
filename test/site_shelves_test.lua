--- Проверки сайта со сводами: адреса «свод/имя», файл меню с заглушками
--- «скоро», сводная страница плана, рамка сайта приложения и подключение
--- раздела к роутеру приложения.

local fio = require('fio')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local headers = helper.part('headers')
local settings_of = helper.part('settings')
local site = helper.part('site')

local g = t.group('tnt.docs.site.shelves')

--- Меню приложения: свои страницы, заглушки и сводная страница.
local MENU = table.concat({
    '## Пролог',
    '',
    '- [Обзор](/docs/framework/guide)',
    '- [Что нового](/docs/framework/releases) {позже}',
    '- [Что впереди](/docs/plan)',
    '',
    '## Основы',
    '',
    '- [Кэш](/docs/framework/cache) {частично}',
    '- [Готово, но без текста](/docs/framework/ready)',
}, '\n')

--- План страниц: о чём будут, чего не хватает и чем закрываются.
local PLAN = {
    ['framework/guide'] = { tasks = { 'a1' } },
    ['framework/releases'] = {
        about = 'то, что изменилось',
        missing = 'выпусков ещё не было',
        note = 'первый выпуск',
    },
    ['framework/cache'] = { about = 'кэш', missing = 'тегов нет', tasks = { 'b1', 'b2' }, note = 'теги' },
    ['framework/ready'] = { tasks = { 'c1' } },
    plan = { note = 'эта страница' },
}

--- Выпадающее меню шапки.
local MORE = {
    title = 'Больше',
    columns = { { { icon = 'box', title = 'Ядро', note = 'Роль узла', href = '/about#kernel' } } },
}

--- Настройки сайта над сводами проверки.
---@param options table|nil Поверх умолчаний проверки
---@return TntDocsOptions
local function options_of(options)
    local merged = {
        roots = {
            { section = 'framework', directory = fio.pathjoin(g.dir, 'framework') },
            { section = 'packages', directory = fio.pathjoin(g.dir, 'packages'), hidden = { 'secret' } },
        },
        menu = fio.pathjoin(g.dir, 'menu.md'),
        start = '/docs/framework/guide',
        groups = { { title = 'Пакеты', section = 'packages', pages = { 'router' } } },
        plan = { page = 'plan', pages = PLAN },
        card = function(name, section)
            if section == 'packages' and name == 'router' then
                return { name = 'tnt-router', install = 'tt rocks install tnt-router' }
            end

            return nil
        end,
        frame = {
            brand = 'skein',
            home = '/',
            description = 'Приложение на узле.',
            url = 'https://example.org',
            image = '/og.png',
            menu = {
                { title = 'Главная', href = '/' },
                { title = 'Документация', href = '/docs' },
                MORE,
            },
            links = {
                { title = 'Tarantool', href = 'https://tarantool.io', icon = 'book' },
                { title = 'Исходники', href = 'https://example.org/src' },
            },
            footer = {
                note = 'Стоит на `tnt-*`.',
                columns = { { title = 'Разделы', links = { { title = 'Живость', href = '/health' } } } },
                signature = 'узел a · среда local',
            },
        },
        views = helper.VIEWS,
        warm = false,
        recheck = 0,
    }

    for key, value in pairs(options or {}) do
        merged[key] = value
    end

    return merged
end

--- Сайт над сводами проверки.
---@param options table|nil Поверх умолчаний проверки
---@return TntDocsSite
local function site_of(options)
    return site.new(settings_of.read(options_of(options)))
end

g.before_all(function()
    g.dir = helper.directory({ framework = {}, packages = {}, ['menu.md'] = MENU })
    helper.write(
        fio.pathjoin(g.dir, 'framework', 'guide.md'),
        '# Обзор набора\n\nСм. [маршруты](../packages/router.md).\n\n## Слои\n\nТекст.'
    )
    helper.write(fio.pathjoin(g.dir, 'packages', 'router.md'), '# Маршруты\n\nДерево.')
    helper.write(fio.pathjoin(g.dir, 'packages', 'queue.md'), '# Очереди\n\nЗадачи.')
    helper.write(fio.pathjoin(g.dir, 'packages', 'secret.md'), '# Для своих')
    g.client = helper.testing.client(site_of())
end)

g.after_all(function()
    helper.remove(g.dir)
end)

g.test_the_start_of_the_section_leads_to_the_first_page = function()
    g.client.get('/docs').redirect('/docs/framework/guide', 302)
    -- Свод — участок адреса, а не страница.
    g.client.get('/docs/framework').status(404)
end

g.test_a_page_of_a_section_is_drawn_on_the_frame_of_the_application = function()
    local page = g.client.get('/docs/framework/guide')

    page
        .status(200)
        .sees('<title>Обзор набора · skein</title>')
        .sees('<a href="/docs/packages/router">маршруты</a>')
        -- Название группы — из меню, заголовок — из документа.
        .sees('<span class="docs-context-item">Пролог</span>')
        .sees('<h1 class="fw-bold text-body-emphasis">Обзор набора</h1>')
        .sees('<span>Обзор</span>')
        .sees('<a href="/docs/framework/guide/source"')
        .sees('title="framework/guide.md">')
        -- Рамка приложения: марка, открытый пункт шапки, меню колонками,
        -- ссылки наружу, абзац и подпись подвала.
        .sees('<span class="fs-4 fw-bold">skein</span>')
        .sees('<a href="/docs" class="nav-link px-3 link-body-emphasis active">')
        .sees('<a href="/" class="nav-link px-3 link-body-emphasis ">')
        .sees('<span class="d-block">Ядро</span>')
        .sees('<small class="opacity-50 line-clamp-2 text-balance">Роль узла</small>')
        .sees('aria-label="Tarantool">')
        .sees('<p class="small text-muted mb-2">Приложение на узле.</p>')
        .sees('<div class="small text-muted site-footer-note"><p>Стоит на <code>tnt-*</code>.</p></div>')
        .sees('<p class="fw-normal text-white">Разделы</p>')
        .sees('<a href="/health" class="nav-link p-0">Живость</a>')
        .sees('<p class="small text-muted border-top pt-3 mb-0">узел a · среда local</p>')
        .sees('<meta property="og:url" content="https://example.org/docs/framework/guide">')
        .sees('<meta property="og:image" content="https://example.org/og.png">')
    -- Соседи — мимо заглушек: за обзором идёт план.
    page.sees('<a class="docs-pager-link docs-pager-next" href="/docs/plan" rel="next">')
end

g.test_a_page_of_a_package_has_its_card_by_name_and_section = function()
    g.client
        .get('/docs/packages/router')
        .status(200)
        .sees('<span class="docs-context-item">tnt-router</span>')
        .sees('<pre><code class="language-bash">tt rocks install tnt-router</code></pre>')
        .sees('<span class="docs-context-item">Пакеты</span>')
    g.client.get('/docs/packages/router/source').status(200).body('# Маршруты\n\nДерево.')
    -- Скрытый документ свода — 404, документ вне групп — в «Прочем».
    g.client.get('/docs/packages/secret').status(404)
    g.client.get('/docs/packages/queue').status(200).sees('<span class="docs-context-item">Прочее</span>')
end

g.test_a_page_that_is_not_written_yet_is_a_promise = function()
    local later = g.client.get('/docs/framework/releases')

    later
        .status(200)
        .header('cache-control', 'no-cache')
        .sees('<title>Что нового · skein</title>')
        .sees('<p class="text-primary text-uppercase fw-semibold ls-xl small mb-2">Пролог</p>')
        .sees('<h1 class="fw-bold text-body-emphasis mb-2">Что нового</h1>')
        .sees('по плану раздела — <strong>позже</strong>.')
        .sees('Здесь будет рассказано про то, что изменилось.')
        .sees('Сейчас этой возможности в наборе нет: выпусков ещё не было.')
        .sees(
            'Задачи на разработку у раздела нет; чем закрывается — первый выпуск.'
        )
        .sees('<a href="/docs/plan" class="link-body-emphasis">Что впереди</a>')
        -- В меню заглушка приглушена и подписана.
        .sees('class="text-decoration-none docs-menu-upcoming"')
        .sees('<span class="badge rounded-pill text-bg-secondary fw-normal">скоро</span>')
    -- У заглушки нет ни исходного файла, ни соседей.
    t.assert_not_str_contains(later.response.body, 'docs-pager')
    g.client.get('/docs/framework/releases/source').status(404)

    g.client
        .get('/docs/framework/cache')
        .sees('Возможность в наборе есть, но не целиком: тегов нет.')
        .sees('Задачи на разработку — <code>b1</code>, <code>b2</code>.')
    g.client
        .get('/docs/framework/ready')
        .sees('Возможность в наборе есть и проверена применением')
        .sees('По плану раздела её закрывает задача <code>c1</code>.')
end

g.test_the_plan_is_the_menu_with_what_is_written_and_what_is_ahead = function()
    local plan = g.client.get('/docs/plan')

    plan
        .status(200)
        .header('cache-control', 'no-cache')
        .sees('<title>Что впереди · skein</title>')
        .sees('<h1 class="fw-bold text-body-emphasis mb-3">Что впереди</h1>')
        .sees('Всего страниц в своде — 5; написано — 2; впереди — 3.')
        .sees('<a href="/docs/framework/releases">Что нового</a>')
        .sees('<td>частично</td>')
        .sees('теги — <code>b1</code>, <code>b2</code>')
        -- Открытый пункт меню — сама сводная страница.
        .sees(helper.current('/docs/plan'))
    -- Документы пакетов — без плана, и в план не входят: в таблице
    -- их строки нет, а в меню слева они есть.
    t.assert_not_str_contains(plan.response.body, '<a href="/docs/packages/router">')
    -- «Все разделы» на узком экране ведут на план.
    plan.sees('<a href="/docs/plan" class="text-decoration-none">Все разделы документации</a>')
end

g.test_a_plan_the_menu_does_not_name_is_still_there = function()
    helper.write(fio.pathjoin(g.dir, 'other.md'), '## Раздел\n\n- [Обзор](/docs/framework/guide)\n')

    local client = helper.testing.client(site_of({ menu = fio.pathjoin(g.dir, 'other.md') }))

    client.get('/docs/plan').status(200).sees('<h1 class="fw-bold text-body-emphasis mb-3">Что впереди</h1>')
    -- 404 зовёт на начальную страницу и на план.
    client
        .get('/docs/framework/nowhere')
        .status(404)
        .sees('с <a href="/docs/framework/guide" class="link-body-emphasis">начала раздела</a>')
        .sees('на странице <a href="/docs/plan" class="link-body-emphasis">Что впереди</a>.')
end

g.test_without_a_plan_there_is_no_plan_page = function()
    local options = options_of({ plan = { pages = PLAN } })

    options.menu = nil

    local client = helper.testing.client(site.new(settings_of.read(options)))

    client.get('/docs/plan').status(404)
    -- Заглушки без меню нет: имя без файла в группах пропускается.
    client.get('/docs/framework/releases').status(404)
end

g.test_the_section_mounted_on_the_router_of_the_application_answers_under_its_start = function()
    local router = require('tnt.router')
    local app = router.new()

    app.get('/', function()
        return app.html('<p>главная</p>')
    end)
    app.get('/docs-old', function()
        return app.html('<p>старое</p>')
    end)

    site_of().mount(app)

    local client = helper.testing.client(app)

    client.get('/').status(200).body('<p>главная</p>')
    client.get('/docs-old').status(200).body('<p>старое</p>')
    client.get('/docs').redirect('/docs/framework/guide', 302)

    local page = client.get('/docs/framework/guide')

    page.status(200).sees('<h1 class="fw-bold text-body-emphasis">Обзор набора</h1>')

    -- Заголовки раздела и метка версии — и под роутером приложения.
    for name, value in pairs(headers.HEADERS) do
        page.header(name, value)
    end

    client.get('/docs/framework/guide', { headers = { ['if-none-match'] = page.response.headers['etag'] } }).status(304)
    client.head('/docs/framework/guide').status(200).header('etag')
    client.get('/docs/framework/nowhere').status(404).sees('Такой страницы нет')
    client.get('/docs/search.json', { query = { q = 'дерево' } }).status(200).content_type('json')
end

g.test_without_its_roots_the_plan_answers_500 = function()
    local options = options_of({ groups = {} })

    options.roots = { { section = 'framework', directory = fio.pathjoin(g.dir, 'nowhere') } }

    local journal = helper.testing.capture_log()

    helper.testing.client(site.new(settings_of.read(options))).get('/docs/plan').status(500)
    journal.release()
    t.assert(journal.logged('nowhere'))
end
