--- Проверки роли раздела: проверка настроек словом для оператора,
--- свой сервер на своём порту, повторное применение и снятие.
---
--- Сервер настоящий, на свободном порту: роль только и делает, что
--- поднимает его, и двойник проверил бы двойника.

local http = require('http.client')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local role = helper.part('role')

local g = t.group('tnt.docs.role')

g.before_all(function()
    g.dir = helper.directory({ ['guide.md'] = helper.GUIDE, ['install.md'] = helper.INSTALL })
end)

g.after_all(function()
    helper.remove(g.dir)
end)

g.after_each(function()
    role.stop()
    package.loaded['test_docs_options'] = nil
end)

--- Настройки роли на порту поверх умолчаний проверки.
---@param listen any
---@param extra table|nil
---@return table
local function cfg_of(listen, extra)
    local cfg = { listen = listen, directory = g.dir, views = helper.VIEWS, warm = false }

    for key, value in pairs(extra or {}) do
        cfg[key] = value
    end

    return cfg
end

--- Просит страницу у сервера роли.
---@param port integer
---@param path string
---@return table
local function get(port, path)
    return http.get(('http://127.0.0.1:%d%s'):format(port, path), { timeout = 10 })
end

--- Текст отказа проверки настроек.
---@param cfg any
---@return string
local function refusal(cfg)
    local ok, err = pcall(role.validate, cfg)

    t.assert_not(ok)

    return tostring(err)
end

g.test_good_settings_pass = function()
    role.validate(cfg_of(8088))
    role.validate(cfg_of(1))
    role.validate(cfg_of(65535))
    role.validate(cfg_of('0.0.0.0:8088'))
    role.validate(cfg_of('localhost:1'))
end

g.test_a_bad_listen_is_named_for_the_operator = function()
    local words = 'listen — порт от 1 до 65535 либо «узел:порт», а не %s'

    for _, listen in ipairs({ 0, 65536, 8088.5, '8088', ':8088', 'localhost:', 'localhost:x', '' }) do
        t.assert_equals(refusal(cfg_of(listen)), words:format(listen), listen)
    end

    t.assert_equals(refusal({ directory = 'docs' }), words:format('nil'))
    t.assert_str_contains(refusal(cfg_of({ 8088 })), words:format('table: '))
end

g.test_settings_of_another_kind_are_refused = function()
    t.assert_equals(refusal(nil), 'роль tnt.docs.role настраивается таблицей, а не nil')
    t.assert_equals(
        refusal('docs'),
        'роль tnt.docs.role настраивается таблицей, а не string'
    )
end

g.test_a_bad_setting_of_the_section_is_named_without_a_place = function()
    t.assert_equals(
        refusal(cfg_of(8088, { hidden = 'plan' })),
        'настройки раздела.hidden — массив, а не строка'
    )
    t.assert_equals(
        refusal({ listen = 8088 }),
        'настройки раздела: разметка — каталог directory либо своды roots, ровно одно'
    )
end

g.test_the_options_module_must_load_into_a_table = function()
    t.assert_str_contains(
        refusal(cfg_of(8088, { options = 'test_docs_nowhere' })),
        'options — модуль с таблицей настроек раздела, а «test_docs_nowhere» не загрузился в таблицу: '
            .. "module 'test_docs_nowhere' not found"
    )

    package.loaded['test_docs_options'] = 'строка'

    t.assert_equals(
        refusal(cfg_of(8088, { options = 'test_docs_options' })),
        'options — модуль с таблицей настроек раздела, а «test_docs_options» не загрузился в таблицу: строка'
    )
end

g.test_the_section_answers_on_its_own_port = function()
    local port = helper.testing.free_port()
    local journal = helper.testing.capture_log()

    role.apply(cfg_of(port))
    journal.release()

    local response = get(port, '/docs/guide')

    t.assert_equals(response.status, 200)
    t.assert_str_contains(response.body, '<h1 class="fw-bold text-body-emphasis">Руководство tnt</h1>')
    t.assert(
        journal.logged(
            ('раздел документации слушает directory=%s listen=127.0.0.1:%d'):format(
                g.dir,
                port
            )
        )
    )
end

g.test_the_server_is_made_with_its_limits = function()
    local server = require('http.server')
    local new = server.new
    local made = {}

    server.new = function(host, port, options)
        made = { host = host, port = port, options = options }

        return new(host, port, options)
    end

    local port = helper.testing.free_port()
    local ok, err = pcall(role.apply, cfg_of(('127.0.0.1:%d'):format(port)))

    server.new = new

    t.assert(ok, err)
    -- Строку запроса сервер без `log_requests = false` писал бы мимо
    -- журнала узла, а без срока простоя соединение, шлющее заголовки
    -- по байту, держало бы файбер бессрочно.
    t.assert_equals(made, { host = '127.0.0.1', port = port, options = { log_requests = false, idle_timeout = 60 } })
    t.assert_equals({ role.HOST, role.IDLE_TIMEOUT }, { '127.0.0.1', 60 })
end

g.test_the_options_module_gives_what_yaml_can_not_and_the_config_wins = function()
    package.loaded['test_docs_options'] = {
        title = 'Из модуля',
        card = function(name)
            return { name = 'tnt-' .. name }
        end,
    }

    local port = helper.testing.free_port()

    role.apply(cfg_of(port, { options = 'test_docs_options', title = 'Из конфигурации' }))

    local body = get(port, '/docs/install').body

    t.assert_str_contains(body, '<span class="docs-context-item">tnt-install</span>')
    t.assert_str_contains(body, '<title>Установка · Из конфигурации</title>')
end

g.test_applied_again_on_the_same_port_the_section_changes_without_closing_it = function()
    local port = helper.testing.free_port()

    role.apply(cfg_of(port, { title = 'Первая' }))
    t.assert_str_contains(get(port, '/docs').body, '<title>Первая · Первая</title>')

    role.apply(cfg_of(port, { title = 'Вторая' }))
    t.assert_str_contains(get(port, '/docs').body, '<title>Вторая · Вторая</title>')
end

g.test_applied_on_another_port_the_section_moves = function()
    local first = helper.testing.free_port()

    role.apply(cfg_of(first))

    -- Второй свободный порт ищется, пока первый занят ролью: иначе
    -- поиск отдал бы его же.
    local second = helper.testing.free_port()

    role.apply(cfg_of(second))

    t.assert_equals(get(second, '/docs').status, 200)
    t.assert_equals(get(first, '/docs').status, 595)
end

g.test_stopped_the_section_closes_its_port = function()
    local port = helper.testing.free_port()

    role.apply(cfg_of(port))
    role.stop()

    t.assert_equals(get(port, '/docs').status, 595)

    -- Снять снятое — не ошибка: ядро зовёт `stop` и без `apply`.
    role.stop()
end
