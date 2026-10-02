--- Заголовки безопасности: на каждом ответе раздела, отказы тоже.
---
--- Раздел публичный, и страница несёт текст, который пишут люди:
--- разметка экранирует его, а заголовки закрывают то, что экранирование
--- не держит.
---
--- * `Content-Security-Policy` — сценарии, стили, картинки и запросы
---   только со своего узла, встроенных сценариев нет вовсе. Тег
---   `<script>`, проскочивший в страницу мимо экранирования, не исполнится,
---   а чужой узел не встроит раздел в свою страницу (`frame-ancestors`).
---   Вид раздела весь лежит на узле, поэтому правило ничего у него
---   не отнимает; значок `data:` — из стилей Bootstrap.
--- * `X-Content-Type-Options: nosniff` — браузер верит типу ответа и не
---   угадывает его по содержимому.
--- * `Referrer-Policy: strict-origin-when-cross-origin` — по ссылке
---   наружу уходит только адрес узла, без пути и запроса поиска.
---
--- Слой стоит на входе роутера: так заголовки получает каждый ответ —
--- страница, файл вида, 304, отказ 404 и 500.

local Module = {}

--- Правило источников для браузера.
Module.POLICY = table.concat({
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
}, '; ')

--- Заголовки каждого ответа.
Module.HEADERS = {
    ['content-security-policy'] = Module.POLICY,
    ['x-content-type-options'] = 'nosniff',
    ['referrer-policy'] = 'strict-origin-when-cross-origin',
}

--- Слой входа: ответ с заголовками безопасности.
---@param request table
---@param nxt fun(request: table): table
---@return table
function Module.layer(request, nxt)
    local response = nxt(request)

    for name, value in pairs(Module.HEADERS) do
        response.headers[name] = value
    end

    return response
end

return Module
