--- Проверки рамки сайта: умолчания, ссылки наружу, абзац подвала
--- и открытый пункт шапки.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local frame = helper.part('frame')

local g = t.group('tnt.docs.frame')

g.test_without_settings_the_frame_is_the_title_of_the_section = function()
    t.assert_equals(frame.read(nil, 'Документация', '/docs'), {
        brand = 'Документация',
        home = '/docs',
        locale = 'ru',
        menu = {},
        links = {},
        columns = {},
    })
end

g.test_what_is_given_stays_and_links_know_if_they_lead_away = function()
    local menu = { { title = 'Главная', href = '/' } }
    local read = frame.read({
        brand = 'skein',
        home = '/',
        description = 'Приложение.',
        url = 'https://example.org',
        image = '/og.png',
        locale = 'en',
        menu = menu,
        links = {
            { title = 'Tarantool', href = 'https://tarantool.io', icon = 'book' },
            { title = 'Вход', href = '/login' },
        },
        footer = {
            note = 'Стоит на `tnt-*`: [исходники](https://example.org/src).',
            columns = {
                {
                    title = 'Разделы',
                    links = {
                        { title = 'Сообщество', href = '//t.me/x' },
                        { title = 'О нас', href = '/about' },
                    },
                },
            },
            signature = 'узел a · среда local',
        },
    }, 'Документация', '/docs')

    t.assert_equals(read, {
        brand = 'skein',
        home = '/',
        description = 'Приложение.',
        url = 'https://example.org',
        image = '/og.png',
        locale = 'en',
        menu = menu,
        links = {
            { title = 'Tarantool', href = 'https://tarantool.io', icon = 'book', external = true },
            { title = 'Вход', href = '/login', external = false },
        },
        -- Абзац — разметкой: код и ссылка в нём экранированы и собраны.
        note = '<p>Стоит на <code>tnt-*</code>: <a href="https://example.org/src">исходники</a>.</p>',
        columns = {
            {
                title = 'Разделы',
                links = {
                    { title = 'Сообщество', href = '//t.me/x', external = true },
                    { title = 'О нас', href = '/about', external = false },
                },
            },
        },
        signature = 'узел a · среда local',
    })
end

g.test_an_address_with_a_scheme_or_a_host_leads_away = function()
    t.assert(frame.external('https://example.org'))
    t.assert(frame.external('mailto:duty@example.org'))
    t.assert(frame.external('//example.org'))
    -- Схема из одной буквы — тоже схема.
    t.assert(frame.external('z:mark'))
    t.assert_not(frame.external('/docs'))
    t.assert_not(frame.external('docs/x:y'))
    t.assert_not(frame.external('#top'))
end

g.test_the_item_of_the_page_and_of_everything_under_it_is_open = function()
    local read = frame.read({
        menu = {
            { title = 'Главная', href = '/' },
            { title = 'Документация', href = '/docs' },
            { title = 'Наружу', href = 'https://example.org' },
            { title = 'Больше', columns = { { { title = 'Ядро', href = '/about#kernel' } } } },
        },
    }, 'Документация', '/docs')

    local menu = frame.menu_at(read, '/docs/router')

    t.assert_equals(menu, {
        -- Корень сайта открыт только на самом корне, а не на всём под ним.
        { title = 'Главная', href = '/', external = false, active = false },
        { title = 'Документация', href = '/docs', external = false, active = true },
        { title = 'Наружу', href = 'https://example.org', external = true, active = false },
        {
            title = 'Больше',
            columns = { { { title = 'Ядро', href = '/about#kernel' } } },
            external = false,
            active = false,
        },
    })
    t.assert_equals(assert(frame.menu_at(read, '/')[1]).active, true)
    t.assert_equals(assert(frame.menu_at(read, '/docs')[2]).active, true)
    t.assert_equals(assert(frame.menu_at(read, '/docsy')[2]).active, false)
end

g.test_an_item_of_the_menu_is_a_link_or_a_dropdown_and_not_both = function()
    t.assert_equals(frame.explain({}, 'рамка'), nil)
    t.assert_equals(frame.explain({ menu = { { title = 'А', href = '/' } } }, 'рамка'), nil)
    t.assert_equals(
        frame.explain({ menu = { { title = 'А', href = '/' }, { title = 'Б' } } }, 'рамка'),
        'рамка.menu[2] — ссылка href либо меню columns, ровно одно'
    )
    t.assert_equals(
        frame.explain({ menu = { { title = 'Б', href = '/', columns = {} } } }, 'рамка'),
        'рамка.menu[1] — ссылка href либо меню columns, ровно одно'
    )
end
