--- Проверки файлов вида: метка версии из имён и содержимого, байты
--- шрифтов и значков из base64.

local digest = require('digest')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local assets = helper.part('assets')
local bundle = helper.part('public.bundle')

local g = t.group('tnt.docs.assets')

g.test_the_version_is_the_crc32_of_names_and_contents_in_order = function()
    local version = assets.version_of({ ['theme.js'] = 'b', ['docs.css'] = 'a' })

    t.assert_equals(version, ('%08x'):format(digest.crc32('docs.css\0a\0theme.js\0b')))
end

g.test_a_renamed_file_is_another_version = function()
    t.assert_not_equals(assets.version_of({ ['a.css'] = 'x' }), assets.version_of({ ['b.css'] = 'x' }))
    t.assert_not_equals(assets.version_of({ ['a.css'] = 'x' }), assets.version_of({ ['a.css'] = 'y' }))
end

g.test_the_version_has_eight_hex_digits = function()
    -- Ведущие нули остаются: метка одной длины у любого содержимого.
    local small = assets.version_of({ ['a'] = '\x9c' })

    t.assert_str_matches(small, '^%x%x%x%x%x%x%x%x$')
end

g.test_the_bundle_of_the_package_is_given_with_its_version = function()
    t.assert_equals(assets.files, assets.unpacked(bundle))
    t.assert_equals(assets.VERSION, assets.version_of(assets.files))

    local names = {}

    for name in pairs(assets.files) do
        table.insert(names, name)
    end

    table.sort(names)
    t.assert_equals(names, {
        'apple-touch-icon.png',
        'docs.css',
        'docs.js',
        'favicon-32x32.png',
        'favicon.svg',
        'fonts/OFL.txt',
        'fonts/inter-cyrillic.woff2',
        'fonts/inter-latin.woff2',
        'fonts/raleway-cyrillic.woff2',
        'fonts/raleway-latin.woff2',
        'theme.js',
    })
    -- Шрифт — двоичный файл со своей подписью, а не строка base64.
    t.assert_equals(assets.files['fonts/inter-latin.woff2']:sub(1, 4), 'wOF2')
    t.assert_equals(assets.files['favicon-32x32.png']:sub(2, 4), 'PNG')
end

g.test_text_stays_and_bytes_come_out_of_base64 = function()
    local bytes = '\r\n\0\255'

    t.assert_equals(
        assets.unpacked({ ['a.css'] = 'текст', ['b.woff2'] = { base64 = digest.base64_encode(bytes) } }),
        { ['a.css'] = 'текст', ['b.woff2'] = bytes }
    )
end
