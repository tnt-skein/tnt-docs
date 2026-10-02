--- Проверки фасада раздела: роутер по настройкам, подключение к роутеру
--- приложения и отказ на строке того, кто завёл раздел.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local docs = helper.docs

local g = t.group('tnt.docs')

g.test_a_section_is_a_router_over_the_directory = function()
    local dir = helper.directory({ ['guide.md'] = helper.GUIDE })
    local web = docs.new({ directory = dir, views = helper.VIEWS, warm = false })

    helper.testing
        .client(web)
        .get('/docs/guide')
        .status(200)
        .sees('<h1 class="fw-bold text-body-emphasis">Руководство tnt</h1>')
    helper.remove(dir)
end

g.test_a_section_mounts_on_the_router_of_the_application = function()
    local dir = helper.directory({ ['guide.md'] = helper.GUIDE })
    local app = require('tnt.router').new()

    docs.new({ directory = dir, views = helper.VIEWS, warm = false }).mount(app)
    helper.testing.client(app).get('/docs/guide').status(200).sees('Руководство tnt')
    helper.remove(dir)
end

g.test_a_bad_setting_blames_the_line_that_made_the_section = function()
    local function made()
        docs.new({ directory = 'docs', hiden = { 'plan' } })
    end

    local _, err = pcall(made)
    local info = debug.getinfo(made, 'S') --[[@as { short_src: string, linedefined: integer }]]

    t.assert_equals(
        err,
        (
            '%s:%d: настройки раздела: ключа «hiden» нет, есть card, directory, frame, groups, hidden, menu, plan, '
            .. 'prefix, recheck, rest, roots, start, suggestions, title, views, warm'
        ):format(info.short_src, info.linedefined + 1)
    )
end
