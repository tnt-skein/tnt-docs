--- Проверки заголовков безопасности: правило источников и слой входа.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local headers = helper.part('headers')

local g = t.group('tnt.docs.headers')

g.test_the_policy_allows_only_the_node_itself = function()
    t.assert_equals(
        headers.POLICY,
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; "
            .. "connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"
    )
end

g.test_the_layer_adds_the_headers_and_keeps_the_others = function()
    local response = headers.layer({ path = '/' }, function(request)
        return { status = 200, headers = { ['x-path'] = request.path }, body = '' }
    end)

    t.assert_equals(response.headers, {
        ['x-path'] = '/',
        ['content-security-policy'] = headers.POLICY,
        ['x-content-type-options'] = 'nosniff',
        ['referrer-policy'] = 'strict-origin-when-cross-origin',
    })
end
