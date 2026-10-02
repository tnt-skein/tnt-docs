--- Проверки указателя разделов: оценка BM25 с прибавкой за заголовок,
--- отбор всех ключей либо хоть одного, порядок и замена раздела.
---
--- Оценка сверяется с формулой, записанной здесь заново числами,
--- а не постоянными модуля: правка постоянной иначе прошла бы
--- незамеченной вместе с ожиданием.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local finders = helper.part('finder')
local words_of = helper.part('words')

local g = t.group('tnt.docs.finder')

--- Точность сверки оценок.
local EPSILON = 1e-9

--- Оценка по формуле шапки модуля: K1 = 1,2, B = 0,75, заголовок — 2.
---@param count integer Сколько разделов в указателе
---@param df integer В скольких разделах ключ
---@param tf integer Сколько раз ключ в тексте раздела
---@param length integer Длина текста раздела в ключах
---@param average number Средняя длина текста
---@param titled boolean Стоит ли ключ в заголовке
---@return number
local function bm25(count, df, tf, length, average, titled)
    local idf = math.log(1 + (count - df + 0.5) / (df + 0.5))
    ---@type number
    local text = 0

    if tf > 0 then
        text = tf * 2.2 / (tf + 1.2 * (0.25 + 0.75 * length / average))
    end

    return idf * (text + (titled and 2 or 0))
end

--- Указатель с тремя разделами разной длины.
---@return TntDocsFinder
local function corpus()
    local finder = finders.new(words_of.new())

    finder:put('a', 'Шаблоны', 'шаблон страница')
    finder:put('b', 'Узлы', 'шаблон шаблон шаблон кластер')
    finder:put('c', 'Кластер', 'узлы')

    return finder
end

g.test_the_score_is_bm25_with_a_bonus_for_the_title = function()
    local hits = corpus():search({ 'шаблон' }, finders.ALL)

    local first = hits[1] --[[@as TntDocsHit]]
    local second = hits[2] --[[@as TntDocsHit]]

    t.assert_equals(#hits, 2)
    t.assert_equals(first.id, 'a')
    t.assert_almost_equals(first.score, bm25(3, 2, 1, 2, 7 / 3, true), EPSILON)
    t.assert_equals(second.id, 'b')
    t.assert_almost_equals(second.score, bm25(3, 2, 3, 4, 7 / 3, false), EPSILON)
end

g.test_a_key_only_in_the_title_counts_the_bonus_alone = function()
    local hits = corpus():search({ 'кластер' }, finders.ALL)

    local first = hits[1] --[[@as TntDocsHit]]
    local second = hits[2] --[[@as TntDocsHit]]

    t.assert_equals(#hits, 2)
    t.assert_equals(first.id, 'c')
    t.assert_almost_equals(first.score, bm25(3, 2, 0, 1, 7 / 3, true), EPSILON)
    t.assert_equals(second.id, 'b')
    t.assert_almost_equals(second.score, bm25(3, 2, 1, 4, 7 / 3, false), EPSILON)
end

g.test_all_wants_every_key_and_any_takes_one = function()
    local finder = corpus()

    local all = finder:search({ 'шаблон', 'кластер' }, finders.ALL)

    local only = all[1] --[[@as TntDocsHit]]

    t.assert_equals(#all, 1)
    t.assert_equals(only.id, 'b')
    t.assert_almost_equals(only.score, bm25(3, 2, 3, 4, 7 / 3, false) + bm25(3, 2, 1, 4, 7 / 3, false), EPSILON)

    local any = finder:search({ 'шаблон', 'кластер' }, finders.ANY)
    local ids = {}

    for _, hit in ipairs(any) do
        table.insert(ids, hit.id)
    end

    t.assert_equals(ids, { 'a', 'b', 'c' })
end

g.test_equal_scores_go_in_the_order_of_ids = function()
    local finder = finders.new(words_of.new())

    finder:put('z', 'Раз', 'кластер')
    finder:put('x', 'Два', 'кластер')
    finder:put('y', 'Три', 'узел')

    local hits = finder:search({ 'кластер' }, finders.ALL)

    local first = hits[1] --[[@as TntDocsHit]]
    local second = hits[2] --[[@as TntDocsHit]]

    t.assert_equals({ first.id, second.id }, { 'x', 'z' })
    t.assert_equals(first.score, second.score)
end

g.test_a_key_nobody_has_and_no_keys_find_nothing = function()
    local finder = corpus()

    t.assert_equals(finder:search({ 'нет' }, finders.ALL), {})
    t.assert_equals(finder:search({ 'нет' }, finders.ANY), {})
    t.assert_equals(finder:search({}, finders.ALL), {})
end

g.test_a_section_put_again_replaces_the_former = function()
    local finder = corpus()

    finder:put('a', 'Кластер', 'узлы узлы')

    t.assert_equals(finder.count, 3)
    t.assert_equals(finder.length, 7)
    t.assert_equals(finder:search({ 'страниц' }, finders.ALL), {})
    -- Пустой список ключа уходит из указателя целиком.
    t.assert_equals(finder.body['страниц'], nil)
    t.assert_equals(finder.heading['шаблон'], nil)
    t.assert_equals(finder.body['шаблон'], { b = 3 })
    t.assert_equals(finder.body['узл'], { a = 2, c = 1 })
end

g.test_a_removed_section_leaves_the_counts_and_the_lists = function()
    local finder = corpus()

    finder:remove('b')

    t.assert_equals({ finder.count, finder.length }, { 2, 3 })
    t.assert_equals(finder.documents.b, nil)
    t.assert_equals(finder.body['шаблон'], { a = 1 })
    t.assert_equals(finder.body['кластер'], nil)
    t.assert_equals(finder.heading['кластер'], { c = true })

    -- Раздела, которого нет, убирать нечего, и счёт не трогается.
    finder:remove('b')

    t.assert_equals({ finder.count, finder.length }, { 2, 3 })
end

g.test_sections_with_titles_only_do_not_divide_by_zero = function()
    local finder = finders.new(words_of.new())

    finder:put('a', 'Кластер', '')
    finder:put('b', 'Узлы', '')

    local hits = finder:search({ 'кластер' }, finders.ALL)

    t.assert_equals(#hits, 1)
    t.assert_almost_equals((hits[1] --[[@as TntDocsHit]]).score, math.log(1 + 1.5 / 1.5) * 2, EPSILON)
end
