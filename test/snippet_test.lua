--- Проверки отрывка: окно целыми кусками вокруг первого совпадения,
--- отметки, экранирование и знаки пропуска по краям.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local snippet = helper.part('snippet')
local words_of = helper.part('words')

local g = t.group('tnt.docs.snippet')

--- Отрывок по тексту и ключам.
---@param text string
---@param keys string[]
---@param length integer
---@return string
local function cut(text, keys, length)
    local wanted = {}

    for _, key in ipairs(keys) do
        wanted[key] = true
    end

    return snippet.cut(text, wanted, words_of.new(), length)
end

--- Восемь слов, пятое — с совпадением.
local LINE = 'один два три четыре шаблон пять шесть семь'

g.test_a_short_text_goes_whole_with_its_matches_marked = function()
    t.assert_equals(
        cut('Шаблон рисует шаблоны.', { 'шаблон' }, 100),
        '<mark>Шаблон</mark> рисует <mark>шаблоны</mark>.'
    )
end

g.test_the_window_grows_around_the_first_match_while_it_fits = function()
    -- «четыре шаблон пять» — 18 знаков; следующий кусок с любой стороны
    -- вышел бы за 20.
    t.assert_equals(cut(LINE, { 'шаблон' }, 20), '…четыре <mark>шаблон</mark> пять…')
    -- На пределе ровно в 18 знаков окно то же. В 17 правый кусок
    -- не влезает, и окно добирает слева: «три четыре шаблон» — 17.
    t.assert_equals(cut(LINE, { 'шаблон' }, 18), '…четыре <mark>шаблон</mark> пять…')
    t.assert_equals(cut(LINE, { 'шаблон' }, 17), '…три четыре <mark>шаблон</mark>…')
end

g.test_the_window_grows_left_and_right_by_turns = function()
    -- Окно растёт по очереди: слева «четыре», справа «пять», снова слева
    -- «три» — и справа уже не влезает ничего.
    t.assert_equals(cut(LINE, { 'шаблон' }, 22), '…три четыре <mark>шаблон</mark> пять…')
end

g.test_a_match_at_the_edges_has_no_mark_of_omission_there = function()
    t.assert_equals(
        cut('узел кластер роутер', { 'узел' }, 12),
        '<mark>узел</mark> кластер…'
    )
    t.assert_equals(cut(LINE, { 'сем' }, 10), '…шесть <mark>семь</mark>')
end

g.test_a_match_longer_than_the_window_goes_whole = function()
    t.assert_equals(cut(LINE, { 'шаблон' }, 3), '…<mark>шаблон</mark>…')
end

g.test_punctuation_at_the_edges_stays_with_its_piece = function()
    t.assert_equals(
        cut('раз два (шаблон), три четыре', { 'шаблон' }, 8),
        '…(<mark>шаблон</mark>),…'
    )
end

g.test_punctuation_without_spaces_stays_whole_at_both_edges = function()
    -- Между кусками нет пробела — знаки по краям окна идут целиком,
    -- а соседние куски — нет.
    t.assert_equals(
        cut('раз два-(шаблон) три', { 'шаблон' }, 8),
        '…-(<mark>шаблон</mark>)…'
    )
    t.assert_equals(cut('шаблон),три четыре', { 'шаблон' }, 6), '<mark>шаблон</mark>),…')
end

g.test_the_text_is_escaped_and_the_marks_are_not = function()
    t.assert_equals(
        cut('шаблон <b> & "x"', { 'шаблон' }, 100),
        '<mark>шаблон</mark> &lt;b&gt; &amp; &quot;x&quot;'
    )
end

g.test_breaks_between_blocks_become_one_space = function()
    t.assert_equals(
        cut('раз\n\n  шаблон\nдва', { 'шаблон' }, 100),
        'раз <mark>шаблон</mark> два'
    )
end

g.test_without_a_match_the_snippet_is_the_head_of_the_text = function()
    t.assert_equals(cut(LINE, { 'кластер' }, 13), 'один два три…')
end

g.test_a_text_without_pieces_gives_an_empty_snippet = function()
    t.assert_equals(cut('', { 'шаблон' }, 10), '')
    -- Тире — не знак препинания ASCII, а кусок; пробелы по краям уходят.
    t.assert_equals(cut(' — ', { 'шаблон' }, 10), '—')
end

g.test_broken_utf8_is_measured_in_bytes = function()
    -- Битая строка знаками не меряется: окно считает байты, а не падает.
    -- «\xff шаблон» — 14 байт: в 15 окно его берёт, в 13 — нет.
    t.assert_equals(cut('ab \xff шаблон', { 'шаблон' }, 15), '…\xff <mark>шаблон</mark>')
    t.assert_equals(cut('ab \xff шаблон', { 'шаблон' }, 13), '…<mark>шаблон</mark>')
end
