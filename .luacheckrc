-- Конфигурация luacheck.

-- Базовый стандарт — LuaJIT: Tarantool исполняет код именно на нём.
std = 'luajit'

-- Глобалы, которые Tarantool добавляет к стандартной библиотеке.
read_globals = {
    'box',
    '_TARANTOOL',
    'tonumber64',
    'utf8',
    -- Tarantool дописывает в стандартные таблицы свои функции: их нет
    -- в обычном Lua, и без объявления luacheck считает их опечатками.
    table = { fields = { 'deepcopy', 'copy', 'clear', 'new', 'equals' } },
    string = { fields = { 'hex', 'fromhex' } },
    -- `package.search` — поиск модуля по путям загрузчика, тоже Tarantool:
    -- по нему раздел находит свои шаблоны рядом с модулем.
    package = { fields = { 'search' } },
}

-- Поля 120 символов — та же планка, что в .editorconfig и stylua.toml.
max_line_length = 120

exclude_files = {
    '.rocks/**',
    'var/**',
    -- Временные файлы мутационного прогона.
    '.tmp_mutant.*',
    '**/*.um.backup.*',
    -- Пакеты сборки вида раздела.
    'node_modules/**',
    -- Упакованный вид раздела: данные, а не код, — минифицированные
    -- стили и сценарии в длинных строках.
    'tnt/docs/public/bundle.lua',
    -- Шаблоны страниц tnt-template: HTML с вкраплениями, не Lua.
    '**/*.thtml.lua',
}

files['test/*_test.lua'] = {
    -- luatest наполняет группу тестов присваиванием полей.
    std = '+busted',
}
