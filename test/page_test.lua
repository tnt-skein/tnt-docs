--- Проверки страницы из разметки: заголовок, описание, текст, перевод
--- ссылок и разделы для указателя.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local page_of = helper.part('page')

local g = t.group('tnt.docs.page')

--- Адрес страницы, которая есть; скрытой и несуществующей — пусто.
---@param name string
---@return string|nil
local function address(name)
    if name == 'install' or name == 'guide' then
        return '/docs/' .. name
    end

    return nil
end

--- Страница из разметки; отказа здесь не ждут.
---@param source string
---@return TntDocsPage
local function render(source)
    local page = page_of.render('guide', source, page_of.resolver(nil, address))

    ---@cast page TntDocsPage
    return page
end

g.test_a_page_is_drawn_from_its_markup = function()
    local page = render(helper.GUIDE)

    t.assert_equals(page.name, 'guide')
    t.assert_equals(page.title, 'Руководство tnt')
    t.assert_equals(page.description, 'Первый абзац про шаблоны страниц.')
    t.assert_equals(page.summary, page.description)
    t.assert_is(page.source, helper.GUIDE)
    t.assert_equals(page.outline, {
        { level = 2, text = 'Шаблоны', anchor = 'шаблоны' },
        { level = 3, text = 'Каталог', anchor = 'каталог' },
    })
    t.assert_equals(
        page.body,
        table.concat({
            '<p>Первый абзац про <strong>шаблоны</strong> страниц.</p>',
            '<p>Смотрите <a href="/docs/install#шаги">установку</a>, план и черновик.</p>',
            '<h2 id="шаблоны">Шаблоны<a class="anchor" href="#шаблоны" aria-label="Ссылка на этот раздел"></a></h2>',
            '<p>Шаблон рисует страницу.</p>',
            '<h3 id="каталог">Каталог<a class="anchor" href="#каталог" aria-label="Ссылка на этот раздел"></a></h3>',
            '<p>Каталог шаблонов лежит рядом.</p>',
        }, '\n')
    )
end

g.test_the_sections_are_the_introduction_and_the_headings = function()
    t.assert_equals(render(helper.GUIDE).sections, {
        {
            anchor = '',
            title = 'Руководство tnt',
            text = 'Первый абзац про шаблоны страниц.\nСмотрите установку, план и черновик.',
        },
        { anchor = 'шаблоны', title = 'Шаблоны', text = 'Шаблон рисует страницу.' },
        {
            anchor = 'каталог',
            title = 'Каталог',
            text = 'Каталог шаблонов лежит рядом.',
        },
    })
end

g.test_a_link_to_a_page_that_is_not_there_keeps_its_text_everywhere = function()
    local page = render(table.concat({
        'Вступление.',
        '',
        '## [Скрытый](plan.md) раздел',
        '',
        '| Ключ | Смысл |',
        '|---|---|',
        '| [план](plan.md#шаги) | [установка](install.md) |',
        '',
        '- пункт со ссылкой на **[черновик](nowhere.md)**',
    }, '\n'))

    t.assert_equals(
        page.body,
        table.concat({
            '<p>Вступление.</p>',
            '<h2 id="скрытый-раздел">Скрытый раздел<a class="anchor" href="#скрытый-раздел"'
                .. ' aria-label="Ссылка на этот раздел"></a></h2>',
            '<div class="table-scroll">',
            '<table>',
            '<thead>',
            '<tr>',
            '<th>Ключ</th>',
            '<th>Смысл</th>',
            '</tr>',
            '</thead>',
            '<tbody>',
            '<tr>',
            '<td>план</td>',
            '<td><a href="/docs/install">установка</a></td>',
            '</tr>',
            '</tbody>',
            '</table>',
            '</div>',
            '<ul>',
            '<li>пункт со ссылкой на <strong>черновик</strong></li>',
            '</ul>',
        }, '\n')
    )
end

g.test_a_relative_link_is_the_address_of_a_page_or_plain_text = function()
    local page = render(table.concat({
        '[раз](install.md)',
        '[два](install.mdx)',
        '[три](install.md?raw=1)',
        '[четыре](../README.md)',
        '[пять](https://example.org/install.md)',
        '[шесть](.md)',
        '[семь](./install.md#шаги)',
        '[восемь](/docs/install)',
        '[девять](#раздел)',
        '[десять](mailto:duty@example.org)',
        '[одиннадцать](z:mark)',
        '[двенадцать]()',
    }, '\n\n'))

    -- Адрес наружу, от корня сайта и якорь остаются как есть; ссылка
    -- на документ — адрес страницы; всё остальное, что сайт не отдаёт, —
    -- текст.
    t.assert_equals(
        page.body,
        table.concat({
            '<p><a href="/docs/install">раз</a></p>',
            '<p>два</p>',
            '<p>три</p>',
            '<p>четыре</p>',
            '<p><a href="https://example.org/install.md">пять</a></p>',
            '<p>шесть</p>',
            '<p><a href="/docs/install#шаги">семь</a></p>',
            '<p><a href="/docs/install">восемь</a></p>',
            '<p><a href="#раздел">девять</a></p>',
            '<p><a href="mailto:duty@example.org">десять</a></p>',
            '<p><a href="z:mark">одиннадцать</a></p>',
            '<p>двенадцать</p>',
        }, '\n')
    )
end

g.test_a_link_goes_from_its_section_to_the_neighbour_one = function()
    local resolve = page_of.resolver('framework', function(slug)
        if slug == 'packages/router' or slug == 'framework/views' then
            return '/docs/' .. slug
        end

        return nil
    end)

    t.assert_equals(resolve('views.md'), '/docs/framework/views')
    t.assert_equals(resolve('../packages/router.md#шаги'), '/docs/packages/router#шаги')
    t.assert_equals(resolve('../packages/./../packages/router.md'), '/docs/packages/router')
    -- Выше корня сводов — файл репозитория, а не страница.
    t.assert_equals(resolve('../../routes/web.md'), 'tnt.docs.unlinked')
    t.assert_equals(resolve('../packages/plan.md'), 'tnt.docs.unlinked')
    t.assert_equals(resolve('../../../routes/web.lua'), 'tnt.docs.unlinked')
    t.assert_equals(resolve('https://example.org/x.md'), nil)
end

g.test_the_outline_stops_at_the_third_level_and_the_sections_do_not = function()
    local page = render('# Заголовок\n\n## Два\n\n### Три\n\n#### Четыре\n\nтекст')

    t.assert_equals(page.outline, {
        { level = 2, text = 'Два', anchor = 'два' },
        { level = 3, text = 'Три', anchor = 'три' },
    })
    t.assert_equals(page_of.OUTLINE_LEVEL, 3)
    t.assert_equals(assert(page.sections[4]).title, 'Четыре')
end

g.test_the_summary_of_the_head_goes_before_the_first_paragraph = function()
    local page =
        render('---\ndescription: Для поисковика.\n---\n# Заголовок\n\nПервый абзац.')

    t.assert_equals(page.summary, 'Для поисковика.')
    t.assert_equals(page.description, 'Первый абзац.')
end

g.test_the_title_of_the_head_goes_first_then_the_heading_then_the_name = function()
    local own = render('---\ntitle: Своё слово\n---\n# Заголовок\n\nтекст')

    t.assert_equals(own.title, 'Своё слово')
    -- Заголовок документа из текста уходит и тогда: шапка одна.
    t.assert_equals(own.body, '<p>текст</p>')
    t.assert_equals(assert(own.sections[1]).title, 'Своё слово')

    local plain = render('просто абзац')

    t.assert_equals(plain.title, 'guide')
    t.assert_equals(plain.body, '<p>просто абзац</p>')
end

g.test_the_heading_of_a_document_leaves_before_it_takes_an_anchor = function()
    -- Заголовок второго уровня в начале документа — заголовок страницы:
    -- уйди он после якорей, тёзка ниже получил бы якорь «раздел-2».
    local page = render('## Раздел\n\n## Раздел')

    t.assert_equals(page.title, 'Раздел')
    t.assert_equals(page.outline, { { level = 2, text = 'Раздел', anchor = 'раздел' } })
end

g.test_the_description_is_the_first_paragraph_on_one_line = function()
    local page = render(
        '# Заголовок\n\n```lua\nкод\n```\n\n> цитата\n\nСтрока\nвторая  строка.\n\nдальше'
    )

    t.assert_equals(page.description, 'Строка вторая строка.')
    -- Ни абзаца, ни описания.
    t.assert_equals(render('# Заголовок\n\n- пункт').description, '')
end

g.test_a_long_description_ends_with_a_whole_word = function()
    local long = ('слово '):rep(60)
    local page = render('# Заголовок\n\n' .. long)

    -- 33 слова с пробелами — 198 знаков, и 34-е за предел уже не влезает.
    t.assert_equals(page.description, ('слово '):rep(32) .. 'слово…')
    t.assert_equals(page_of.DESCRIPTION, 200)
end

g.test_a_string_is_shortened_by_whole_words = function()
    t.assert_equals(page_of.shortened('раз два', 7), 'раз два')
    t.assert_equals(page_of.shortened('раз два', 6), 'раз…')
    t.assert_equals(page_of.shortened('раз два', 3), 'раз…')
    -- Предел ровно на конце слова: слово целиком. Знаком дальше пробела
    -- нет — значит, на пределе слово оборвано, и оно уходит целиком.
    t.assert_equals(page_of.shortened('раз два три', 7), 'раз два…')
    t.assert_equals(page_of.shortened('раз два три', 6), 'раз…')
    -- Слово длиннее предела режется по пределу.
    t.assert_equals(page_of.shortened('словосочетание', 5), 'слово…')
    -- Битая строка меряется байтами.
    t.assert_equals(page_of.shortened('ab\xff cd', 4), 'ab\xff…')
end

g.test_markup_larger_than_the_limit_is_a_refusal = function()
    local page, err = page_of.render('large', ('x'):rep(1024 * 1024 + 1), page_of.resolver(nil, address))

    t.assert_equals(page, nil)
    t.assert_equals(assert(err).kind, 'too_large')
end
