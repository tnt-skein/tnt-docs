--- Проверки сайта раздела с того места, откуда на него смотрит браузер:
--- запрос по адресу и страница в ответе.
---
--- Сокета здесь нет — клиент проверок зовёт роутер напрямую; живой
--- сервер поднимает проверка роли. Своды, меню, план и подключение
--- к роутеру приложения — в `site_shelves_test.lua`.

local fiber = require('fiber')
local fio = require('fio')
local json = require('json')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local assets = helper.part('assets')
local headers = helper.part('headers')
local library_of = helper.part('library')
local settings_of = helper.part('settings')
local site = helper.part('site')

local g = t.group('tnt.docs.site')

--- Заголовок браузера: такой шлют Chrome и Firefox.
local BROWSER = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'

--- Карточка пакета страницы `install`.
local CARD = {
    name = 'tnt-install',
    install = 'tt rocks install tnt-install',
    repository = 'https://example.org/tnt-install',
}

--- Сайт над каталогом проверки.
---@param dir string
---@param options table|nil Поверх умолчаний проверки
---@return TntDocsSite
local function site_of(dir, options)
    local merged = {
        directory = dir,
        views = helper.VIEWS,
        warm = false,
        recheck = 0,
        hidden = { 'plan' },
        groups = { { title = 'Начало', pages = { 'install', 'guide' } } },
        card = function(name)
            return name == 'install' and CARD or nil
        end,
    }

    for key, value in pairs(options or {}) do
        merged[key] = value
    end

    return site.new(settings_of.read(merged))
end

g.before_all(function()
    g.dir = helper.directory({
        ['guide.md'] = helper.GUIDE,
        ['install.md'] = helper.INSTALL,
        ['plan.md'] = '# План',
        ['broken.md'] = {},
        ['about.md'] = '# О разделе\n\nПро раздел.',
    })
    g.web = site_of(g.dir)
    g.client = helper.testing.client(g.web)
end)

g.after_all(function()
    helper.remove(g.dir)
end)

g.after_each(function()
    library_of._set_source(nil)
end)

--- Утверждения о заголовках безопасности ответа.
---@param answer table Утверждения клиента
local function guarded(answer)
    for name, value in pairs(headers.HEADERS) do
        answer.header(name, value)
    end
end

g.test_the_index_shows_the_groups_with_the_cards_of_pages = function()
    local index = g.client.get('/docs')

    index
        .status(200)
        .content_type('html')
        .header('etag')
        .header('cache-control', 'no-cache')
        .sees('<title>Документация · Документация</title>')
        .sees('<h1 class="fw-bold text-body-emphasis">Документация</h1>')
        .sees('<h2 id="docs-index-1">Начало</h2>')
        .sees('<span class="docs-index-card-title">Установка</span>')
        -- Описание — голый текст первого абзаца.
        .sees('<span class="docs-index-card-note">Сначала — make deps.</span>')
        .sees('<span class="docs-index-card-note">Первый абзац про шаблоны страниц.</span>')
        -- Страница вне групп — в группе «Прочее».
        .sees('<h2 id="docs-index-2">Прочее</h2>')
        .sees('<a href="/docs/about" class="docs-index-card">')
        -- Без страницы в меню раскрыта первая группа.
        .sees('aria-controls="docs-menu-panel-1"\n                    aria-expanded="true"')
        .sees('aria-controls="docs-menu-panel-2"\n                    aria-expanded="false"')
        -- Ссылка «все разделы» на узком экране ведёт на эту же главную.
        .sees('<a href="/docs" class="text-decoration-none">Все разделы документации</a>')
    guarded(index)

    -- Скрытая и несобранная страницы в навигацию не идут.
    t.assert_not_str_contains(index.response.body, '/docs/plan')
    t.assert_not_str_contains(index.response.body, '/docs/broken')
end

g.test_the_frame_takes_the_view_of_the_package_with_its_version = function()
    local base = ('/docs/assets/%s/'):format(assets.VERSION)

    g
        .client
        .get('/docs')
        .sees(('<link rel="stylesheet" href="%sdocs.css" data-turbo-track="reload">'):format(base))
        .sees(('<script src="%stheme.js"></script>'):format(base))
        .sees(('<script src="%sdocs.js" defer data-turbo-track="reload"></script>'):format(base))
        .sees(('<link rel="icon" type="image/svg+xml" href="%sfavicon.svg">'):format(base))
        .sees(('<link rel="icon" type="image/png" sizes="32x32" href="%sfavicon-32x32.png">'):format(base))
        .sees(('<link rel="apple-touch-icon" sizes="180x180" href="%sapple-touch-icon.png">'):format(base))
        .sees('<html lang="ru" data-bs-theme="auto">')
        .sees('data-docs-search-url-value="/docs/search.html"')
        .sees('maxlength="200"')
        -- Без настроек рамки марка — название раздела и ведёт на его начало.
        .sees('<span class="fs-4 fw-bold">Документация</span>')
        .sees('<a href="/docs" class="d-inline-flex align-items-center gap-2 link-body-emphasis text-decoration-none')
end

g.test_a_page_is_its_markup_on_the_frame_of_the_site = function()
    local page = g.client.get('/docs/guide', { headers = { accept = BROWSER } })

    page.status(200)
        .content_type('html')
        .header('cache-control', 'no-cache')
        .sees('<title>Руководство tnt · Документация</title>')
        .sees('<meta name="description" content="Первый абзац про шаблоны страниц.">')
        .sees('<h1 class="fw-bold text-body-emphasis">Руководство tnt</h1>')
        .sees('<span class="docs-context-item">Начало</span>')
        .sees('<span class="docs-context-item">Разделов: 2</span>')
        .sees('<a href="/docs/guide/source"')
        .sees('title="guide.md">')
        .sees('<a href="/docs/install#шаги">установку</a>, план и черновик.')
        .sees('<li class="anchor-h2">')
        .sees('<li class="anchor-h3">')
        .sees('data-scroll-to-value="#каталог">Каталог</a>')
        .sees('<p class="docs-sidebar-label">На этой странице</p>')
        .sees(helper.current('/docs/guide'))
        .sees('<a class="docs-pager-link" href="/docs/install" rel="prev">')
        .sees('<a class="docs-pager-link docs-pager-next" href="/docs/about" rel="next">')
    guarded(page)

    -- Карточки у этой страницы нет.
    t.assert_not_str_contains(page.response.body, 'docs-package')
end

g.test_a_page_with_a_package_shows_its_card = function()
    local page = g.client.get('/docs/install')

    page.status(200)
        .sees('<a href="https://example.org/tnt-install"')
        .sees('        tnt-install\n    </a>')
        .sees('<pre><code class="language-bash">tt rocks install tnt-install</code></pre>')

    -- Первая страница порядка: назад вести некуда.
    t.assert_not_str_contains(page.response.body, 'rel="prev"')
end

g.test_a_card_without_a_repository_or_a_command_shows_what_it_has = function()
    local client = helper.testing.client(site_of(g.dir, {
        card = function(name, section)
            t.assert_equals(section, nil)

            return name == 'install' and { name = 'tnt-install' } or { repository = 'https://example.org/repo' }
        end,
    }))

    local named = client.get('/docs/install').status(200)

    named.sees('<span class="docs-context-item">tnt-install</span>')
    t.assert_not_str_contains(named.response.body, 'language-bash')

    client.get('/docs/guide').status(200).sees('        Репозиторий\n    </a>')
end

g.test_a_card_of_false_is_no_card_and_a_card_of_a_string_is_a_breakdown = function()
    local none = helper.testing.client(site_of(g.dir, {
        card = function()
            return false
        end,
    }))

    t.assert_not_str_contains(none.get('/docs/install').status(200).response.body, 'docs-package')

    local journal = helper.testing.capture_log()
    local wrong = helper.testing.client(site_of(g.dir, {
        card = function()
            return 'карточка'
        end,
    }))

    wrong.get('/docs/install').status(500)
    journal.release()
    t.assert(
        journal.logged(
            'карточка пакета страницы «install» — таблица, а не строка'
        )
    )
end

g.test_a_page_without_headings_has_no_outline = function()
    local body = g.client.get('/docs/about').status(200).response.body

    t.assert_not_str_contains(body, 'docs-table-of-contents')
    t.assert_not_str_contains(body, 'docs-sidebar-label')
    t.assert_str_contains(body, '<span class="docs-context-item">Разделов: 0</span>')
end

g.test_the_source_of_a_page_is_its_markup_as_plain_text = function()
    local source = g.client.get('/docs/guide/source')

    source
        .status(200)
        .content_type('text/plain; charset=utf-8')
        .header('cache-control', 'no-cache')
        .header('etag')
        .body(helper.GUIDE)
    guarded(source)

    -- У скрытого, несобранного и несуществующего документа файла нет.
    g.client.get('/docs/plan/source').status(404).content_type('html')
    g.client.get('/docs/broken/source').status(404)
    g.client.get('/docs/nowhere/source').status(404)
end

g.test_a_hidden_or_missing_page_answers_404_with_a_page = function()
    for _, path in ipairs({ '/docs/plan', '/docs/nowhere', '/docs/..%2Fguide' }) do
        local page = g.client.get(path, { headers = { accept = BROWSER } })

        page
            .status(404)
            .content_type('html')
            .sees('<title>Страница не найдена · Документация</title>')
            .sees('<h1 class="fw-bold text-body-emphasis mb-3">Такой страницы нет</h1>')
            .sees(('В разделе документации нет страницы <code>%s</code>.'):format(path))
            .sees('с <a href="/docs" class="link-body-emphasis">начала раздела</a>.')
            -- Навигация — и на странице отказа.
            .sees('<a href="/docs/guide"')
        guarded(page)
        t.assert_not_str_contains(page.response.body, 'Происшествие')
    end
end

g.test_the_journal_says_why_a_page_is_missing = function()
    local journal = helper.testing.capture_log()

    g.client.get('/docs/plan').status(404)
    journal.release()
    t.assert(journal.logged('в разделе нет страницы с таким адресом'))
end

g.test_a_page_that_can_not_be_drawn_answers_500_and_says_no_more = function()
    local journal = helper.testing.capture_log()
    local page = g.client.get('/docs/broken')

    journal.release()
    page.status(500)
        .content_type('html')
        .sees('Раздел не смог ответить на этот запрос (код 500).')
        .sees('<p class="mb-0">Происшествие <code>')
    -- Путь файла и слово ядра — для журнала, а не для посетителя.
    t.assert_not_str_contains(page.response.body, 'broken.md')
    t.assert(journal.logged('broken.md не прочитан'))
end

g.test_a_directory_that_is_not_there_answers_500_everywhere = function()
    local client = helper.testing.client(site_of(fio.pathjoin(g.dir, 'nowhere')))

    -- Причина — что каталога нет — уходит в журнал на каждом адресе.
    for _, path in ipairs({ '/docs', '/docs/guide', '/docs/guide/source', '/docs/search.json', '/docs/search.html' }) do
        local journal = helper.testing.capture_log()
        local answer = client.get(path, { query = { q = 'шаблон' } })

        journal.release()
        answer.status(500)
        t.assert(journal.logged('nowhere'), path)
    end

    -- Издания не было ни разу: страница отказа — без меню, но страница.
    client.get('/docs').sees('<p class="mb-0">Происшествие <code>')
    client.get('/docs', { query = { q = 'шаблон' } }).status(500)
end

g.test_the_root_leads_to_the_section = function()
    g.client.get('/').redirect('/docs', 302)
end

g.test_a_page_seen_already_answers_304_without_a_body = function()
    local tag = g.client.get('/docs/guide').response.headers['etag']
    local seen = g.client.get('/docs/guide', { headers = { ['if-none-match'] = tag } })

    seen.status(304).header('etag', tag)
    guarded(seen)
    t.assert_equals(seen.response.body, nil)
    g.client.get('/docs/guide', { headers = { ['if-none-match'] = '"старая"' } }).status(200)
end

g.test_head_is_get_without_a_body = function()
    local head = g.client.head('/docs/guide')

    head.status(200).content_type('html').header('etag')
    guarded(head)
    t.assert_equals(head.response.body, '')
end

g.test_a_page_answers_only_to_get_and_names_what_it_answers_to = function()
    g.client
        .post('/docs/guide')
        .status(405)
        .content_type('html')
        .header('allow', 'GET, HEAD, OPTIONS')
        .sees(
            '<h1 class="fw-bold text-body-emphasis mb-3">этот способ здесь не поддерживается</h1>'
        )
        .sees('(код 405)')
end

g.test_a_query_on_the_index_is_a_search = function()
    local found = g.client.get('/docs', { query = { q = '  шаблонов ' } })

    found
        .status(200)
        .header('cache-control', 'no-cache')
        .sees('<title>Поиск: шаблонов · Документация</title>')
        .sees('value="шаблонов"')
        .sees('Нашлось разделов: 3.')
        .sees('<a href="/docs/guide#каталог" class="docs-search-result text-decoration-none">')
        .sees('<span class="docs-search-result-page">Руководство tnt</span>')
        .sees('<span class="docs-search-result-title">Каталог</span>')
        .sees(
            '<span class="docs-search-result-snippet">Каталог <mark>шаблонов</mark> лежит рядом.</span>'
        )
        -- Найдено вступление страницы: её название в строке один раз.
        .sees(
            '<a href="/docs/guide" class="docs-search-result text-decoration-none">\n'
                .. '            <span class="docs-search-result-title">Руководство tnt</span>'
        )
    guarded(found)

    -- Пустой запрос — это главная.
    g.client.get('/docs', { query = { q = '   ' } }).status(200).sees('docs-index-card')
end

g.test_a_search_without_hits_and_with_some_words_says_so = function()
    local nothing = g.client.get('/docs', { query = { q = 'нигде' } }).status(200)

    nothing.sees('<strong>Ничего не найдено</strong>')
    t.assert_not_str_contains(nothing.response.body, 'Нашлось разделов')

    g.client.get('/docs', { query = { q = 'установка каталог' } }).status(200).sees(
        'Всех слов вместе нет ни в одном разделе — показаны разделы хотя бы с одним.'
    )
end

g.test_the_limits_of_the_answers = function()
    t.assert_equals({ site.RESULTS, site.WINDOW, site.SUGGESTIONS }, { 50, 6, 8 })
end

g.test_a_search_shows_the_first_hits_and_counts_all = function()
    local saved = site.RESULTS

    site.RESULTS = 2

    local found = g.client.get('/docs', { query = { q = 'шаблонов' } })

    site.RESULTS = saved

    found.sees('Нашлось разделов: 3, показаны первые 2.')
end

g.test_a_query_longer_than_the_limit_is_refused_with_a_page = function()
    g.client
        .get('/docs', { query = { q = ('я'):rep(201) } })
        .status(400)
        .content_type('html')
        .sees('<h1 class="fw-bold text-body-emphasis mb-3">запрос длиннее 200 знаков</h1>')
end

g.test_the_window_of_the_search_gets_the_list_alone = function()
    local window = g.client.get('/docs/search.html', { query = { q = 'шаблонов' } })

    window
        .status(200)
        .content_type('html')
        .header('etag')
        .header('cache-control', 'no-cache')
        .sees('<ul class="docs-search-results list-unstyled">')
        .sees('<span class="docs-search-result-title">Шаблоны</span>')
    guarded(window)
    -- Кусок, а не страница: рамки в нём нет.
    t.assert_not_str_contains(window.response.body, '<html')

    -- Ещё не спрашивали — подсказки; подсказок нет — пустой список.
    local empty = g.client.get('/docs/search.html').status(200).response.body

    t.assert_not_str_contains(empty, 'Ничего не найдено')
    t.assert_not_str_contains(empty, 'Смотрите также')
    g.client
        .get('/docs/search.html', { query = { q = 'нигде' } })
        .sees('<strong>Ничего не найдено</strong>')
    g.client.get('/docs/search.html', { query = { q = ('я'):rep(201) } }).status(400)
end

g.test_the_window_of_the_search_shows_the_first_hits = function()
    local saved = site.WINDOW

    site.WINDOW = 1

    local body = g.client.get('/docs/search.html', { query = { q = 'шаблонов' } }).response.body

    site.WINDOW = saved

    local _, rows = body:gsub('class="docs%-search%-result text%-decoration%-none"', '')

    t.assert_equals(rows, 1)
end

g.test_the_empty_window_suggests_where_to_go = function()
    local client = helper.testing.client(site_of(g.dir, {
        suggestions = {
            { icon = 'book', title = 'Обзор', note = 'С чего начать.', href = '/docs/guide' },
            { title = 'Установка', href = '/docs/install' },
        },
    }))

    local window = client.get('/docs/search.html').status(200)

    window
        .sees('<p class="docs-search-suggestions-label">Смотрите также:</p>')
        .sees('<a href="/docs/guide" class="docs-search-suggestion text-decoration-none">')
        .sees('<strong>Обзор</strong>')
        .sees('<span>С чего начать.</span>')
        .sees('<strong>Установка</strong>')
    -- И в окне на каждой странице раздела — те же подсказки.
    client.get('/docs/about').sees('<strong>Обзор</strong>')
end

g.test_suggestions_are_the_same_search_in_json = function()
    local answer = g.client.get('/docs/search.json', { query = { q = 'шаблонов' } })

    answer.status(200).content_type('json').header('etag')
    guarded(answer)

    local data = answer.data()

    t.assert_equals({ data.query, data.total, data.partial, #data.items }, { 'шаблонов', 3, false, 3 })
    -- Первым — раздел, названный словом запроса.
    t.assert_equals(data.items[1].url, '/docs/guide#шаблоны')

    -- Пустой запрос — пустой список, а не объект.
    t.assert_str_contains(g.client.get('/docs/search.json').status(200).response.body, '"items":[]')
end

g.test_suggestions_are_limited = function()
    local saved = site.SUGGESTIONS

    site.SUGGESTIONS = 1

    local data = g.client.get('/docs/search.json', { query = { q = 'шаблонов' } }).data()

    site.SUGGESTIONS = saved

    t.assert_equals({ data.total, #data.items }, { 3, 1 })
end

g.test_a_long_query_is_refused_to_the_suggestions_in_json = function()
    local answer = g.client.get('/docs/search.json', { query = { q = ('я'):rep(201) } })

    answer.status(400).content_type('json')
    t.assert_equals(answer.data(), { message = 'запрос длиннее 200 знаков' })
end

g.test_the_view_is_given_with_a_long_life = function()
    local css = g.client.get(('/docs/assets/%s/docs.css'):format(assets.VERSION))

    css.status(200)
        .content_type('text/css; charset=utf-8')
        .header('cache-control', 'public, max-age=31536000, immutable')
        .body(assets.files['docs.css'])
    guarded(css)

    g.client
        .get(('/docs/assets/%s/docs.js'):format(assets.VERSION))
        .status(200)
        .content_type('application/javascript; charset=utf-8')
    g.client
        .get(('/docs/assets/%s/fonts/inter-latin.woff2'):format(assets.VERSION))
        .status(200)
        .content_type('font/woff2')
        .body(assets.files['fonts/inter-latin.woff2'])
    g.client.get(('/docs/assets/%s/favicon-32x32.png'):format(assets.VERSION)).status(200).content_type('image/png')
    g.client.get(('/docs/assets/%s/none.css'):format(assets.VERSION)).status(404)
end

g.test_a_view_of_another_version_is_not_there = function()
    g.client.get('/docs/assets/00000000/docs.css').status(404).content_type('html')
end

g.test_a_section_has_its_own_prefix = function()
    local client = helper.testing.client(site_of(g.dir, { prefix = '/help/v2' }))

    client.get('/').redirect('/help/v2', 302)
    client.get('/help/v2').status(200).sees('href="/help/v2/guide"')
    client.get('/help/v2/guide').status(200).sees('<a href="/help/v2/install#шаги">установку</a>')
    client.get('/help/v2/guide/source').status(200)
    client.get('/help/v2/search.json', { query = { q = 'шаблон' } }).status(200)
    client.get('/help/v2/search.html', { query = { q = 'шаблон' } }).status(200)
    client.get(('/help/v2/assets/%s/theme.js'):format(assets.VERSION)).status(200)
end

g.test_the_start_of_the_section_leads_to_its_first_page = function()
    local client = helper.testing.client(site_of(g.dir, { start = '/docs/guide' }))

    client.get('/docs').redirect('/docs/guide', 302)
    -- Поиск на начале раздела остаётся поиском.
    client.get('/docs', { query = { q = 'шаблонов' } }).status(200).sees('Нашлось разделов: 3.')
    -- Главной нет — «все разделы» на узком экране вести некуда, а 404
    -- зовёт на начальную страницу.
    local missing = client.get('/docs/nowhere').status(404)

    missing.sees('с <a href="/docs/guide" class="link-body-emphasis">начала раздела</a>.')
    t.assert_not_str_contains(missing.response.body, 'Все разделы документации')
end

--- Есть ли файбер прогрева.
---@return boolean
local function warming()
    for _, info in pairs(fiber.info()) do
        if info.name == 'tnt.docs.warm' then
            return true
        end
    end

    return false
end

g.test_the_section_is_warmed_when_it_is_attached = function()
    local open = helper.hold(library_of)
    local httpd = require('http.server').new('127.0.0.1', helper.testing.free_port(), { idle_timeout = 60 })
    local cold = site_of(g.dir)

    t.assert_is(cold.attach(httpd), httpd)
    t.assert_not(warming())

    local warm = site_of(g.dir, { warm = true })

    -- И вызовом с двоеточием: прогрев не ломает способ роутера.
    t.assert_is(warm:attach(httpd), httpd)
    t.assert(warming())

    open()
    t.helpers.retrying({ timeout = 5 }, function()
        t.assert_not(warming())
    end)
end

g.test_the_section_is_warmed_when_it_is_mounted = function()
    local open = helper.hold(library_of)
    local app = require('tnt.router').new()

    t.assert_is(site_of(g.dir).mount(app), app)
    t.assert_not(warming())

    local other = require('tnt.router').new()

    t.assert_is(site_of(g.dir, { warm = true }).mount(other), other)
    t.assert(warming())

    open()
    t.helpers.retrying({ timeout = 5 }, function()
        t.assert_not(warming())
    end)
end

g.test_the_journal_of_a_breakdown_is_json_free = function()
    -- Отказ страницы — HTML и тогда, когда браузер просит JSON: раздел
    -- читают глазами.
    local page = g.client.get('/docs/nowhere', { headers = { accept = 'application/json' } })

    page.status(404).content_type('html')
    t.assert_equals(pcall(json.decode, page.response.body), false)
end
