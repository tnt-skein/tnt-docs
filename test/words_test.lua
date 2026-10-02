--- Проверки слов указателя: куски текста, их ключи и память о разобранном.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local words_of = helper.part('words')

local g = t.group('tnt.docs.words')

g.test_a_key_is_the_stem_of_a_word_without_stop_words = function()
    local words = words_of.new()

    t.assert_equals(words:keys('Шаблоны'), { 'шаблон' })
    t.assert_equals(words:keys('и'), {})
    -- Кусок с тире без пробелов — два слова и два ключа.
    t.assert_equals(words:keys('шаблон—страница'), { 'шаблон', 'страниц' })
end

g.test_the_pieces_of_a_text_go_with_their_places = function()
    local words = words_of.new()
    local seen = {}

    words:each('Узлы (кластера), и всё.', function(from, to, keys)
        table.insert(seen, { from, to, keys })
    end)

    -- Места — байты: кириллическая буква занимает два. Стоп-слово
    -- остаётся куском без ключей: отрывку нужно и его место.
    t.assert_equals(seen, {
        { 1, 8, { 'узл' } },
        { 11, 26, { 'кластер' } },
        { 30, 31, {} },
        { 33, 38, {} },
    })
end

g.test_the_text_of_the_corpus_is_remembered_and_a_query_is_not = function()
    local words = words_of.new()
    local counts, total = words:counts('Шаблоны и шаблон, шаблоны.')

    t.assert_equals(counts, { ['шаблон'] = 3 })
    t.assert_equals(total, 3)
    -- Кусок «шаблон» в счёте без запятой: запятая — знак препинания.
    t.assert_equals(words.pieces, {
        ['Шаблоны'] = { 'шаблон' },
        ['и'] = {},
        ['шаблон'] = { 'шаблон' },
        ['шаблоны'] = { 'шаблон' },
    })
    t.assert_equals(
        words.words,
        { ['шаблоны'] = 'шаблон', ['и'] = false, ['шаблон'] = 'шаблон' }
    )

    -- Запрос не оставляет следа: память росла бы с каждым новым запросом.
    t.assert_equals(words:query('Кластеры кластеров узлы'), { 'кластер', 'узл' })
    t.assert_equals(words.pieces['Кластеры'], nil)
    t.assert_equals(words.words['кластеры'], nil)
end

g.test_a_query_takes_what_the_corpus_remembered = function()
    local words = words_of.new()

    words:counts('шаблоны')

    -- Слово, разобранное для свода, запрос берёт из памяти: подменённый
    -- ключ это и показывает.
    words.pieces['шаблоны'] = { 'подмена' }
    words.words['шаблон'] = 'другое'

    t.assert_equals(words:query('шаблоны шаблон'), { 'подмена', 'другое' })
end

g.test_a_stop_word_remembered_gives_no_key_again = function()
    local words = words_of.new()

    words:counts('и')

    t.assert_equals(words:keys('и'), {})
    t.assert_equals(words:query('и в на'), {})
end

g.test_a_text_without_words_gives_nothing = function()
    local words = words_of.new()

    t.assert_equals({ words:counts(' , . ') }, { {}, 0 })
    t.assert_equals(words:query(''), {})
end
