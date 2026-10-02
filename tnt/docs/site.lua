--- Сайт раздела: адреса, страницы, поиск и отказы.
---
---     GET /                                → 302 на начало раздела
---     GET <начало>                         → начальная страница (`start`) либо главная с карточками
---     GET <начало>?q=шаблоны               → страница выдачи поиска
---     GET <начало>/search.html?q=…         → список выдачи для окна поиска — кусок HTML
---     GET <начало>/search.json?q=…         → выдача поиска JSON
---     GET <начало>/<план>                  → сводная страница плана
---     GET <начало>/[<свод>/]<имя>          → страница документа либо заглушка «скоро»
---     GET <начало>/[<свод>/]<имя>/source   → разметка документа простым текстом
---     GET <начало>/assets/<метка>/<файл>   → вид раздела с меткой версии
---
--- Выдача поиска живёт на начале раздела, а ответы окна поиска и JSON —
--- на адресах с точкой: любое имя из одного участка однажды совпало бы
--- с именем документа, а точки в именах страниц не бывает.
---
--- Страницы рисуют шаблоны `tnt-template` целиком, с рамкой сайта;
--- отвечает роутер `tnt-router` со слоем `etag`: страница, которая
--- у браузера уже есть, отвечается 304 без тела. Отказ — страницей
--- на той же рамке: раздел читают браузером, и тело отказа JSON показало
--- бы посетителю скобки вместо слов.
---
--- Раздел подключается к серверу своим роутером (`attach`) либо
--- к роутеру приложения (`mount`): тогда приложение отдаёт разделу его
--- начало и всё под ним, а свои маршруты и слои оставляет себе.

local must = require('tnt.must')
local router = require('tnt.router')
local template = require('tnt.template')

local assets = require('tnt.docs.assets')
local frame = require('tnt.docs.frame')
local headers = require('tnt.docs.headers')
local library_of = require('tnt.docs.library')
local navigation = require('tnt.docs.navigation')
local search = require('tnt.docs.search')

local Module = {}

--- Сколько попаданий на странице выдачи.
Module.RESULTS = 50

--- Сколько ответов в окне поиска: окно стоит поверх страницы, и список,
--- который нужно прокручивать до конца, читателю не помогает — он
--- уточняет запрос быстрее, чем дочитывает третий десяток строк.
Module.WINDOW = 6

--- Сколько попаданий в ответе JSON.
Module.SUGGESTIONS = 8

--- Хвост шаблона маршрута: весь остаток пути.
---
--- Собран из двух кусков: пара знаков «косая черта со звёздочкой»
--- в строке — начало блочного комментария для языконезависимого
--- мутационного прогона, и всё, что стоит за ней, он перестаёт видеть.
local TAIL = '/' .. '*path'

--- Страница меняется с правкой разметки, и браузер обязан спросить узел,
--- не изменилась ли она: метка версии отвечает на это 304 без тела.
local PAGE = { ['cache-control'] = 'no-cache' }

--- Срок жизни файла вида: год, без вопросов узлу — метка версии стоит
--- в адресе, и новое содержимое приходит по новому адресу.
local FOREVER = 'public, max-age=31536000, immutable'

--- Отказ «такой страницы нет»: по договору отказа роутер отвечает его
--- статусом, а не 500. Строкой отказ читается для журнала: роутер пишет
--- причину отказа туда как есть, и таблица без своего слова дала бы
--- в записи адрес таблицы в памяти.
local MISSING = setmetatable({ status = 404, message = 'такой страницы нет' }, {
    __tostring = function()
        return 'в разделе нет страницы с таким адресом'
    end,
})

--- Навигация, пока издания нет: отказ рисуется и тогда.
local NOWHERE = { groups = {}, order = {}, places = {} }

--- Собирает роутер раздела.
---@param settings TntDocsSettings
---@return TntDocsSite
function Module.new(settings)
    ---@type TntDocsSite
    local web

    local home = settings.prefix
    local sectioned = settings.sectioned

    --- Адрес страницы по адресу в разделе: имена — латиница, цифры, дефис
    --- и подчёркивание, и кодировать в них нечего.
    ---@param slug string
    ---@return string
    local function address(slug)
        return home .. '/' .. slug
    end

    local shelf = library_of.new({
        roots = settings.roots,
        menu = settings.menu,
        prefix = home,
        groups = settings.groups,
        rest = settings.rest,
        plan = settings.plan,
        recheck = settings.recheck,
        address = address,
    })

    local base = ('%s/assets/%s/'):format(home, assets.VERSION)

    -- Общее для каждой страницы, в том числе для страницы отказа,
    -- которую обработчик не рисует.
    local shared = {
        title = settings.title,
        home = home,
        start = settings.start,
        frame = settings.frame,
        suggestions = settings.suggestions,
        found = home .. '/search.html',
        query_length = search.QUERY_LENGTH,
        assets = {
            css = base .. 'docs.css',
            js = base .. 'docs.js',
            theme = base .. 'theme.js',
            icon = base .. 'favicon.svg',
            png = base .. 'favicon-32x32.png',
            touch = base .. 'apple-touch-icon.png',
        },
    }

    web = router.new({
        view = template.new({ path = settings.views }) --[[@as TntRouterView]],
        entry = { headers.layer },
        middleware = {
            router.etag() --[[@as TntRouterLayer]],
        },
        view_data = function(request)
            local path = request.path

            return { site = shared, path = path, menu = frame.menu_at(settings.frame, path), query = '' }
        end,
    }) --[[@as TntDocsSite]]

    --- Данные страницы раздела: меню слева, раскрытый в нём раздел
    --- и открытый пункт; поверх — данные самой страницы.
    ---
    --- Раскрыт раздел открытой страницы; страницы в меню нет (главная,
    --- выдача, 404) — первый: колонка, свёрнутая целиком, не подсказывает,
    --- куда идти.
    ---@param map TntDocsNavigation
    ---@param entry TntDocsEntry|nil
    ---@param data table
    ---@return table
    local function page_data(map, entry, data)
        local first = map.groups[1]

        data.navigation = map
        data.entry = entry
        data.opened = entry and entry.group or first and first.title

        return data
    end

    --- Карточка пакета для страницы; нет её — пусто.
    ---
    --- Имя и свод — те, под которыми документ лежит на диске: их знает
    --- издание, и разбирать адрес обратно не нужно.
    ---@param edition TntDocsEdition
    ---@param slug string
    ---@return TntDocsCard|nil
    local function card_of(edition, slug)
        if settings.card == nil then
            return nil
        end

        local origin = edition.origins[slug]
        local card = settings.card(origin.name, origin.section)

        -- Нет данных — `nil` либо `false` — нет и карточки.
        if not card then
            return nil
        end

        must.table(card, ('карточка пакета страницы «%s»'):format(slug))

        return card
    end

    --- Страница документа, заглушка ненаписанной либо отказ.
    ---@param slug string
    ---@return table|nil response
    ---@return any err
    local function page_of(slug)
        local edition, err = shelf:edition()

        if edition == nil then
            return nil, err
        end

        local map = edition.navigation
        local entry = navigation.entry_of(map, slug)
        local page = edition.pages[slug]

        if page ~= nil then
            local previous, following = navigation.neighbours(map, slug)

            return web.view(
                'docs.show',
                page_data(map, entry, {
                    page = page,
                    outline = page.outline,
                    card = card_of(edition, slug),
                    previous = previous,
                    following = following,
                }),
                nil,
                PAGE
            )
        end

        local failure = edition.failures[slug]

        if failure ~= nil then
            return nil, failure
        end

        if entry ~= nil and entry.kind == 'upcoming' then
            return web.view('docs.upcoming', page_data(map, entry, {}), nil, PAGE)
        end

        return nil, MISSING
    end

    --- Разметка документа как есть: простым текстом, а не `text/markdown` —
    --- этот тип браузер скачивает файлом, а читателю нужно его увидеть.
    ---@param slug string
    ---@return table|nil response
    ---@return any err
    local function source_of(slug)
        local edition, err = shelf:edition()

        if edition == nil then
            return nil, err
        end

        local page = edition.pages[slug]

        if page == nil then
            return nil, MISSING
        end

        return web.text(page.source, 200, PAGE)
    end

    web.get('/', function()
        return web.redirect(home)
    end)

    web.get(home, function(request)
        local query = search.text(request.query.q)

        if query == '' and settings.start ~= nil then
            return web.redirect(settings.start)
        end

        local edition, err = shelf:edition()

        if edition == nil then
            return nil, err
        end

        if query == '' then
            return web.view('docs.index', page_data(edition.navigation, nil, {}), nil, PAGE)
        end

        local results, refusal = search.run(edition, query, Module.RESULTS)

        if results == nil then
            return nil, refusal
        end

        return web.view(
            'docs.found',
            page_data(edition.navigation, nil, { results = results, query = query }),
            nil,
            PAGE
        )
    end, { name = 'docs.index' })

    web.get(home .. '/search.html', function(request)
        local edition, err = shelf:edition()

        if edition == nil then
            return nil, err
        end

        local query = search.text(request.query.q)
        local results, refusal = search.run(edition, query, Module.WINDOW)

        if results == nil then
            return nil, refusal
        end

        return web.view('docs.search-results', { results = results, asked = query ~= '' }, nil, PAGE)
    end, { name = 'docs.window' })

    web.get(home .. '/search.json', function(request)
        local edition, err = shelf:edition()

        if edition == nil then
            return nil, err
        end

        local results, refusal = search.run(edition, search.text(request.query.q), Module.SUGGESTIONS)

        -- Отказ ответу JSON — тоже JSON: его читает сценарий, а не человек.
        if results == nil then
            ---@cast refusal table
            return web.json({ message = refusal.message }, refusal.status)
        end

        return web.json(results)
    end, { name = 'docs.search' })

    local files = router.files({ bundle = assets.files, cache = FOREVER })

    -- Прежняя метка — отказ, а не нынешний файл: под годовым кэшем
    -- по старому адресу осело бы новое содержимое.
    web.get(home .. '/assets/:version' .. TAIL, function(request)
        if request.params.version ~= assets.VERSION then
            return nil, MISSING
        end

        return files(request)
    end, { name = 'docs.assets' })

    if settings.plan.page ~= nil then
        web.get(address(settings.plan.page), function()
            local edition, err = shelf:edition()

            if edition == nil then
                return nil, err
            end

            local map = edition.navigation
            local items, written = navigation.planned(map)

            return web.view('docs.plan', page_data(map, map.plan, { items = items, written = written }), nil, PAGE)
        end, { name = 'docs.plan' })
    end

    if sectioned then
        web.get(home .. '/:section/:name', function(request)
            return page_of(request.params.section .. '/' .. request.params.name)
        end, { name = 'docs.page' })

        web.get(home .. '/:section/:name/source', function(request)
            return source_of(request.params.section .. '/' .. request.params.name)
        end, { name = 'docs.source' })
    else
        web.get(home .. '/:name', function(request)
            return page_of(request.params.name)
        end, { name = 'docs.page' })

        web.get(home .. '/:name/source', function(request)
            return source_of(request.params.name)
        end, { name = 'docs.source' })
    end

    -- Заголовки отказа уходят вместе с ним: `Allow` у 405 нужен клиенту,
    -- чтобы отличить «нет такого адреса» от «сюда так нельзя».
    web.on_error(function(failure)
        local latest = shelf.latest
        local page = web.view(
            'docs.refusal',
            page_data(latest and latest.navigation or NOWHERE, nil, { failure = failure }),
            failure.status,
            failure.headers
        )

        -- Отказ рисует тот же движок, что и страницы: сломанный шаблон
        -- отказа роутер встретит своим последним ответом 500.
        ---@cast page table
        return page
    end)

    -- Прогрев — при подключении, а не при заведении: роутер, который
    -- зовут напрямую (проверки, свой сервер приложения), фоновой работы
    -- не заводит.
    local function warm()
        if settings.warm then
            shelf:warm()
        end
    end

    local attach = web.attach

    web.attach = function(...)
        local attached = attach(...)

        warm()

        return attached
    end

    --- Подключает раздел к роутеру приложения: начало раздела и всё под
    --- ним отвечает раздел своим роутером — со своими заголовками, меткой
    --- версии и страницами отказа, — а остальные адреса, слои входа
    --- и обработчик отказов остаются у приложения.
    ---@param app TntRouter
    ---@return TntRouter app
    web.mount = function(app)
        app.get(home .. TAIL, function(request)
            return web.dispatch(request)
        end)

        warm()

        return app
    end

    return web
end

return Module
