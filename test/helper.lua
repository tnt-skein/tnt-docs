--- Общие средства проверок раздела документации.
---
--- Исходники пакета читаются с диска, а не через `require`: у Tarantool
--- свой загрузчик `.rocks`, он идёт раньше `package.path` и подсунул бы
--- установленную копию пакета, если она есть. Проверки тогда шли бы
--- против вчерашнего кода, а покрытие считалось бы по нему. Зависимости
--- берутся из `.rocks`, куда их ставит `make deps`, обычным `require`.
---
--- Оснастка в `test/testing/` — загрузчик исходников, ловушка журнала,
--- свободный порт и клиент запросов без сокета — грузится так же и один
--- раз на процесс: второй экземпляр загрузчика не знал бы, что вытеснил
--- первый, и не вернул бы вытесненное на место.
---
--- Проверки берут всё через этот помощник, а не из оснастки напрямую:
--- помощник — единственное, чем файл проверок отличается от того же файла
--- там, где пакет живёт рядом со своими зависимостями.
---
--- Каталог разметки у каждой проверки свой и временный: библиотека
--- помнит разобранное по разметке, и общий на набор файл, переписанный
--- одной проверкой, достался бы соседней.

-- luatest берёт этот файл `require('test.helper')` раньше, чем включает
-- замер покрытия, и исходники, прочитанные тогда, исполнялись бы мимо
-- замера. `require` передаёт чанку имя модуля первым аргументом,
-- а `dofile` из файлов проверок — ничего: пустая таблица достаётся одному
-- luatest, которому помощник не нужен.
if ... == 'test.helper' then
    return {}
end

local fiber = require('fiber')
local fio = require('fio')
local t = require('luatest')

--- Модули оснастки в порядке зависимостей.
local TESTING = {
    { name = 'tnt.testing.sources', path = 'test/testing/sources.lua' },
    { name = 'tnt.testing.files', path = 'test/testing/files.lua' },
    { name = 'tnt.testing.journal', path = 'test/testing/journal.lua' },
    { name = 'tnt.testing.node', path = 'test/testing/node.lua' },
    { name = 'tnt.testing.expect', path = 'test/testing/expect.lua' },
    { name = 'tnt.testing.web', path = 'test/testing/web.lua' },
}

for _, module in ipairs(TESTING) do
    if package.loaded[module.name] == nil then
        local chunk, failure = loadfile(fio.abspath(module.path))

        if chunk == nil then
            error(('оснастка %s не читается: %s'):format(module.name, tostring(failure)))
        end

        package.loaded[module.name] = chunk()
    end
end

local sources = package.loaded['tnt.testing.sources']

local helper = {}

--- Модули пакета в порядке зависимостей.
local OWN = {
    'tnt.docs.public.bundle',
    'tnt.docs.words',
    'tnt.docs.finder',
    'tnt.docs.snippet',
    'tnt.docs.page',
    'tnt.docs.menu',
    'tnt.docs.navigation',
    'tnt.docs.frame',
    'tnt.docs.settings',
    'tnt.docs.library',
    'tnt.docs.search',
    'tnt.docs.assets',
    'tnt.docs.headers',
    'tnt.docs.site',
    'tnt.docs',
    'tnt.docs.role',
}

--- Исходники пакета: путь складывается из имени модуля.
helper.MODULES = {}

for _, name in ipairs(OWN) do
    table.insert(helper.MODULES, { name = name, path = name:gsub('%.', '/') .. '.lua' })
end

--- Фасад пакета из исходников.
helper.docs = sources.load(helper.MODULES, 'tnt.docs')

--- Шаблоны пакета в репозитории: от них рисуют страницы проверки.
helper.VIEWS = 'tnt/docs/views'

--- Оснастка проверок под теми именами, что зовут проверки.
helper.testing = {
    capture_log = package.loaded['tnt.testing.journal'].capture,
    client = package.loaded['tnt.testing.web'].new,
    free_port = package.loaded['tnt.testing.node'].free_port,
}

--- Часть пакета из той же загрузки, что и фасад.
---@param name string Имя без приставки: `library`, `search`
---@return any
function helper.part(name)
    return sources.module('tnt.docs.' .. name)
end

--- Документ-образец: заголовок, первый абзац, разделы, ссылки на соседа,
--- на скрытый документ и на документ, которого нет.
helper.GUIDE = table.concat({
    '# Руководство `tnt`',
    '',
    'Первый абзац про **шаблоны** страниц.',
    '',
    'Смотрите [установку](install.md#шаги), [план](plan.md) и [черновик](nowhere.md).',
    '',
    '## Шаблоны',
    '',
    'Шаблон рисует страницу.',
    '',
    '### Каталог',
    '',
    'Каталог шаблонов лежит рядом.',
}, '\n')

--- Документ-сосед образца.
helper.INSTALL =
    '# Установка\n\nСначала — `make deps`.\n\n## Шаги\n\nПоставить пакет.'

--- Пишет файл целиком.
---@param path string
---@param content string
function helper.write(path, content)
    local file = assert(io.open(path, 'w'))

    file:write(content)
    file:close()
end

--- Заводит временный каталог разметки с названными файлами.
---
--- Таблица вместо текста — каталог: так проверяется файл, который есть,
--- а прочитать его нельзя.
---@param files table<string, string|table>
---@return string
function helper.directory(files)
    local dir = fio.tempdir()

    for name, content in pairs(files) do
        local path = fio.pathjoin(dir, name)

        if type(content) == 'table' then
            t.assert(fio.mkdir(path))
        else
            helper.write(path, content)
        end
    end

    return dir
end

--- Сносит каталог разметки проверки.
---@param dir string
function helper.remove(dir)
    t.assert(fio.rmtree(dir))
end

--- Затвор уступки библиотеки: сборка издания встаёт на первой уступке,
--- пока проверка его не откроет. Снимает затвор `_set_source(nil)`.
---@param library_of table Модуль `tnt.docs.library`
---@return fun() open
function helper.hold(library_of)
    local held = true
    local opened = fiber.cond()

    library_of._set_source({
        yield = function()
            while held do
                opened:wait()
            end
        end,
    })

    return function()
        held = false
        opened:broadcast()
    end
end

--- Ссылка меню слева на открытую страницу — так её рисует колонка.
---@param address string
---@return string
function helper.current(address)
    return ('<a href="%s"\n%sclass="text-decoration-none "\n%saria-current="page">'):format(
        address,
        (' '):rep(31),
        (' '):rep(31)
    )
end

--- Адрес страницы по имени — тот, что даёт сайт с началом `/docs`.
---@param name string
---@return string
function helper.address(name)
    return '/docs/' .. name
end

return helper
