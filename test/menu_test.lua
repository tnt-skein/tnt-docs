--- Проверки файла меню: разделы, пункты со ссылкой и метки состояния.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local menu = helper.part('menu')

local g = t.group('tnt.docs.menu')

--- Меню из разметки; отказа здесь не ждут.
---@param source string
---@return TntDocsMenuGroup[]
local function parsed(source)
    local groups, err = menu.parse(source, '/docs')

    t.assert_equals(err, nil)

    return assert(groups)
end

g.test_a_heading_is_a_group_and_a_link_is_a_page = function()
    local groups = parsed(table.concat({
        '---',
        'title: Документация',
        '---',
        '',
        '- [До раздела](/docs/lost)',
        '',
        '## Пролог',
        '',
        '- [Обзор **набора**](/docs/framework/overview)',
        '- [Что нового](/docs/framework/releases) {позже}',
        '- [Что впереди](/docs/plan)',
        '',
        '### Подзаголовок — не раздел',
        '',
        'Абзац между списками.',
        '',
        '- [Деплой](/docs/framework/deployment) { частично }',
        '',
        '## Пустой',
    }, '\n'))

    t.assert_equals(groups, {
        {
            title = 'Пролог',
            items = {
                { title = 'Обзор набора', slug = 'framework/overview', state = 'ready' },
                { title = 'Что нового', slug = 'framework/releases', state = 'later' },
                { title = 'Что впереди', slug = 'plan', state = 'ready' },
                { title = 'Деплой', slug = 'framework/deployment', state = 'partial' },
            },
        },
        { title = 'Пустой', items = {} },
    })
end

g.test_an_item_that_does_not_lead_into_the_section_is_not_in_the_menu = function()
    local groups = parsed(table.concat({
        '## Раздел',
        '',
        '- [Наружу](https://example.org/docs/x)',
        '- [Другой раздел](/about)',
        '- [Начало раздела](/docs)',
        '- [Глубже двух](/docs/a/b/c)',
        '- [С якорем](/docs/a#b)',
        '- текст без ссылки',
        '- ```',
        '  код',
        '  ```',
        '- [Почти](/docsy/x)',
        '- [Пустой адрес](/docs/)',
        '- [Без свода](/docs//x)',
        '- [Без имени](/docs/x/)',
        '- [Годный](/docs/name_1-2)',
    }, '\n'))

    t.assert_equals(
        groups,
        { { title = 'Раздел', items = { { title = 'Годный', slug = 'name_1-2', state = 'ready' } } } }
    )
end

g.test_an_unknown_mark_is_a_refusal_and_not_a_ready_page = function()
    local groups, err = menu.parse('## Раздел\n\n- [Кэш](/docs/cache) {скоро}\n', '/docs')

    t.assert_equals(groups, nil)
    t.assert_equals(
        err,
        'в меню метка {скоро} неизвестна: есть {позже} и {частично}'
    )
    -- Скобки без слова — не метка, а текст.
    local item = assert(assert(parsed('## Раздел\n\n- [Кэш](/docs/cache) {}\n')[1]).items[1])

    t.assert_equals(item.state, 'ready')
end

g.test_markup_larger_than_the_limit_is_a_refusal = function()
    local groups, err = menu.parse(('x'):rep(1024 * 1024 + 1), '/docs')

    t.assert_equals(groups, nil)
    t.assert_str_contains(err, 'меню не разобрано: ')
end

g.test_the_marks_are_the_words_of_the_plan = function()
    t.assert_equals(menu.MARKS, { ['позже'] = 'later', ['частично'] = 'partial' })
    t.assert_equals(menu.READY, 'ready')
end
