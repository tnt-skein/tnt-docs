--- Библиотека раздела: своды разметки и файл меню — изданием, по которому
--- отвечает сайт.
---
---     local shelf = library.new({ roots = roots, menu = 'docs/menu.md', address = address, … })
---
---     local edition, err = shelf:edition()   -- издание либо nil, err: каталог не прочитан
---     edition.pages['packages/router']       -- разобранная страница по адресу в разделе
---     edition.failures.broken                -- отказ документа, который не собрать
---
--- **Издание** — страницы по именам, отказы документов, навигация
--- и указатель поиска разом. Собирается оно, только когда разметка
--- на диске стала другой, и сверка идёт по самой разметке, а не по
--- времени правки файла: две правки в одну секунду время не различило бы.
--- Разбирается заново только изменённый документ, и указатель меняет
--- только его разделы. Правку видно без перезапуска узла.
---
--- Сверка с диском — не чаще раза в `recheck` секунд: это чтение всех
--- каталогов, и на каждый запрос оно стоило бы времени ответа. Файл меню
--- читается и разбирается на каждой сверке заново: он мал, а от него
--- зависит только навигация. Пока
--- издание собирается, остальные запросы получают прежнее, а первого
--- издания ждут все. Сборка уступает цикл событий после каждого
--- разобранного документа: разбор всего каталога занимает секунды,
--- и соседние запросы узел обслуживает и в это время.
---
--- Документ, который не прочитать или не разобрать (больше предела),
--- в издание входит отказом: его страница отвечает 500, остальной
--- раздел работает, а запись в журнале появляется сразу при сборке —
--- поломку видно, не дожидаясь, пока документ откроют.
---
--- Ссылки между документами зависят от состава раздела: ссылка
--- на скрытый или несуществующий документ остаётся текстом. Поэтому
--- новый или удалённый документ пересобирает все страницы, а правка
--- текста — только свою.

local fiber = require('fiber')
local fio = require('fio')

local clock = require('tnt.clock')
local context = require('tnt.context')
local external = require('tnt.external')
local fs = require('tnt.fs')

local fail = require('tnt.must.fail').raise
local log = require('tnt.log').new('tnt.docs')

local finders = require('tnt.docs.finder')
local menu = require('tnt.docs.menu')
local navigation = require('tnt.docs.navigation')
local page_of = require('tnt.docs.page')
local words_of = require('tnt.docs.words')

local Module = {}

--- Знак, которого в имени страницы не бывает: годны латиница, цифры,
--- дефис и подчёркивание.
---
--- Имя файла становится адресом страницы, и адрес приходит назад
--- от посетителя. Страница ищется только среди найденных здесь имён,
--- а не чтением файла по имени из адреса: `..%2F` не увести за каталог,
--- потому что файл по адресу не открывается вовсе. Пустого имени поиск
--- не находит сам: образец `*.md` скрытых файлов не видит, и `.md`
--- в список не попадает.
local FOREIGN = '[^%w_%-]'

--- Расширение файла разметки.
local EXTENSION = '.md'

--- Внешние средства: монотонные часы сверки и уступка цикла событий.
local source = external.install(Module, { now = clock.monotonic, yield = fiber.yield })

---@class TntDocsPlace Раздел страницы в указателе
---@field page TntDocsPage
---@field section TntDocsSection
---@field url string Адрес раздела: страница и якорь

---@class TntDocsEdition Издание раздела
---@field pages table<string, TntDocsPage> Страницы по имени
---@field failures table<string, table> Отказы документов, которые не собрать
---@field origins table<string, TntDocsOrigin> Откуда документ — по адресу
---@field sections table<string, TntDocsPlace> Разделы по опознавателю в указателе
---@field navigation TntDocsNavigation
---@field finder TntDocsFinder
---@field words TntDocsWords

---@class TntDocsLibraryOptions
---@field roots TntDocsRoot[]
---@field menu string|nil Файл меню
---@field prefix string Начало адресов раздела: по нему меню узнаёт свои ссылки
---@field groups TntDocsDeclaredGroup[]
---@field rest string
---@field plan { page: string|nil, pages: table<string, TntDocsPlanned> }
---@field recheck number
---@field address fun(slug: string): string Адрес страницы по адресу в разделе

---@class TntDocsKnown Разобранный документ
---@field source string Разметка, из которой собран
---@field page TntDocsPage|nil
---@field err table|nil Отказ разбора
---@field ids string[] Его разделы в указателе

---@class TntDocsOrigin Откуда страница: свод и имя файла
---@field section string|nil Свод; у раздела из одного каталога — пусто
---@field name string Имя файла без `.md`

---@class TntDocsFound Что лежит в сводах
---@field names string[] Адреса страниц раздела по порядку
---@field origins table<string, TntDocsOrigin> Откуда страница — по адресу
---@field texts table<string, string> Разметка прочитанных
---@field failures table<string, table> Отказы непрочитанных
---@field menu TntDocsMenuGroup[] Разделы файла меню

---@class TntDocsLibrary
---@field options TntDocsLibraryOptions
---@field hidden table<string, boolean> Скрытые документы по адресу в разделе
---@field words TntDocsWords
---@field finder TntDocsFinder
---@field known table<string, TntDocsKnown>
---@field signature string|nil Состав раздела прошлой сборки
---@field latest TntDocsEdition|nil Последнее собранное издание
---@field failure table|nil Отказ последней сборки, пока издания нет
---@field checked number Когда издание сверялось с диском; до первого издания не читается
---@field building table|nil Условие, которое будит ждущих конца сборки
local Library = {}
Library.__index = Library

--- Заводит библиотеку; каталог читается при первом издании.
---@param options TntDocsLibraryOptions
---@return TntDocsLibrary
function Module.new(options)
    local words = words_of.new()
    local hidden = {}

    for _, root in ipairs(options.roots) do
        for name in pairs(root.hidden) do
            hidden[root.section and root.section .. '/' .. name or name] = true
        end
    end

    return setmetatable({
        options = options,
        hidden = hidden,
        words = words,
        finder = finders.new(words),
        known = {},
    }, Library)
end

--- Опознаватель раздела в указателе.
---@param name string
---@param anchor string
---@return string
local function id_of(name, anchor)
    return name .. '#' .. anchor
end

--- Разделы файла меню; меню нет — пусто.
---
--- Меню, которое назвали и которого нет, — отказ издания, а не пустое
--- меню: разделы молча исчезли бы из колонки, и этого никто бы не заметил.
---@param self TntDocsLibrary
---@return TntDocsMenuGroup[]|nil groups
---@return any err
local function menu_of(self)
    local path = self.options.menu

    if path == nil then
        return {}
    end

    local text, err = fs.read(path)

    if text == nil then
        return nil, err
    end

    return menu.parse(text, self.options.prefix)
end

--- Документы одного свода: адреса и разметка.
---
--- Скрытые, негодные в адрес имена и документ с адресом сводной страницы
--- не читаются вовсе. Файл, пропавший между поиском и чтением, страницей
--- не считается; файл, который есть, а не читается, — страница с отказом.
---@param self TntDocsLibrary
---@param root TntDocsRoot
---@param found TntDocsFound
---@return table|nil err
local function scan(self, root, found)
    local paths, failure = fs.glob(root.directory, '*' .. EXTENSION)

    if paths == nil then
        return failure
    end

    for _, path in ipairs(paths) do
        local name = fio.basename(path, EXTENSION)
        local slug = root.section and root.section .. '/' .. name or name

        if name:find(FOREIGN) == nil and not root.hidden[name] and slug ~= self.options.plan.page then
            local text, err = fs.read(path)

            -- Нет текста — есть отказ: так отвечает `tnt-fs`.
            ---@cast err TntFsFailure

            if text ~= nil or err.kind ~= fs.MISSING then
                found.texts[slug] = text
                found.failures[slug] = err
                found.origins[slug] = { section = root.section, name = name }
                table.insert(found.names, slug)
            end
        end
    end

    return nil
end

--- Что лежит в сводах: адреса страниц, их разметка и меню.
---@param self TntDocsLibrary
---@return TntDocsFound|nil found
---@return any err
local function scanned(self)
    local groups, refusal = menu_of(self)

    if groups == nil then
        return nil, refusal
    end

    local found = { names = {}, origins = {}, texts = {}, failures = {}, menu = groups }

    for _, root in ipairs(self.options.roots) do
        local failure = scan(self, root, found)

        if failure ~= nil then
            return nil, failure
        end
    end

    return found
end

--- Убирает документ из разобранного и его разделы из указателя.
---@param self TntDocsLibrary
---@param name string
local function forget(self, name)
    local known = self.known[name]

    if known ~= nil then
        for _, id in ipairs(known.ids) do
            self.finder:remove(id)
        end

        self.known[name] = nil
    end
end

--- Разбирает документ и кладёт его разделы в указатель.
---@param self TntDocsLibrary
---@param name string Адрес страницы в разделе
---@param root string|nil Свод документа
---@param text string
---@param address fun(slug: string): string|nil
local function render(self, name, root, text, address)
    forget(self, name)

    local page, err = page_of.render(name, text, page_of.resolver(root, address))
    local known = { source = text, page = page, err = err, ids = {} }

    if page == nil then
        log.error('документ не собран', { name = name, reason = tostring(err) })
    else
        for _, section in ipairs(page.sections) do
            local id = id_of(name, section.anchor)

            self.finder:put(id, section.title, section.text)
            table.insert(known.ids, id)
        end
    end

    self.known[name] = known
end

--- Издание по разобранному.
---@param self TntDocsLibrary
---@param found TntDocsFound
---@return TntDocsEdition
local function edition_of(self, found)
    local failures = found.failures
    local pages, sections, documents = {}, {}, {}

    for _, name in ipairs(found.names) do
        documents[name] = true
    end

    for name, known in pairs(self.known) do
        local page = known.page

        if page == nil then
            failures[name] = known.err
        else
            local address = self.options.address(name)

            pages[name] = page

            for _, section in ipairs(page.sections) do
                local url = section.anchor == '' and address or address .. '#' .. section.anchor

                sections[id_of(name, section.anchor)] = { page = page, section = section, url = url }
            end
        end
    end

    return {
        pages = pages,
        failures = failures,
        origins = found.origins,
        sections = sections,
        navigation = navigation.build({
            pages = pages,
            documents = documents,
            hidden = self.hidden,
            menu = found.menu,
            groups = self.options.groups,
            rest = self.options.rest,
            plan = self.options.plan,
            address = self.options.address,
        }),
        finder = self.finder,
        words = self.words,
    }
end

--- Собирает издание по каталогу на диске.
---@param self TntDocsLibrary
---@return TntDocsEdition|nil edition
---@return table|nil err
local function rebuilt(self)
    local found, failure = scanned(self)

    if found == nil then
        return nil, failure
    end

    local visible = {}

    for _, name in ipairs(found.names) do
        visible[name] = true
    end

    -- Ссылка на документ, которого на сайте нет, остаётся текстом, поэтому
    -- страница зависит и от состава раздела: при новом составе прежняя
    -- разметка уже не повод брать прежнюю страницу.
    local signature = table.concat(found.names, '\n')
    local regroup = signature ~= self.signature

    self.signature = signature

    local function address(name)
        return visible[name] and self.options.address(name) or nil
    end

    for name in pairs(self.known) do
        if found.texts[name] == nil then
            forget(self, name)
        end
    end

    for _, name in ipairs(found.names) do
        local text = found.texts[name]
        local known = self.known[name]

        if text ~= nil and (regroup or known == nil or known.source ~= text) then
            render(self, name, found.origins[name].section, text, address)
            source().yield()
        end
    end

    return edition_of(self, found)
end

--- Собирает издание заново; ждущие просыпаются при любом исходе.
---@param self TntDocsLibrary
---@return TntDocsEdition|nil edition
---@return table|nil err
local function refreshed(self)
    local building = fiber.cond()

    self.building = building

    local ok, edition, err = pcall(rebuilt, self)

    self.building = nil
    building:broadcast()

    -- Поломка внутри сборки — ошибка кода, а не каталога, и уходит
    -- дальше. Но ждущие к этому мигу уже разбужены: иначе они висели бы
    -- до перезапуска узла.
    if not ok then
        fail(edition)
    end

    if edition == nil then
        self.failure = err

        return nil, err
    end

    self.latest, self.failure, self.checked = edition, nil, source().now()

    return edition
end

--- Издание, сверенное с диском не раньше, чем `recheck` секунд назад.
---
--- Каталог не прочитан — `nil, err`; следующий запрос пробует снова.
---@return TntDocsEdition|nil edition
---@return table|nil err
function Library:edition()
    local building = self.building

    if building ~= nil then
        if self.latest == nil then
            building:wait()
        end

        return self.latest, self.failure
    end

    if self.latest ~= nil and source().now() - self.checked < self.options.recheck then
        return self.latest
    end

    return refreshed(self)
end

--- Собирает первое издание в фоне: первый посетитель не ждёт разбора
--- всего каталога.
---
--- Файбер несёт контекст того, кто подключал раздел: прогрев, начатый
--- внутри запроса, пишет о документе, который не собрать, с его
--- опознавателем.
---@return table fiber
function Library:warm()
    return fiber.create(context.bind(function()
        fiber.self():name('tnt.docs.warm')

        local edition, err = self:edition()

        if edition == nil then
            log.error('раздел документации не прогрет', { reason = tostring(err) })
        end
    end))
end

return Module
