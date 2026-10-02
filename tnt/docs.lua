--- Раздел документации: каталог markdown — сайтом.
---
---     local docs = require('tnt.docs')
---
---     local site = docs.new({
---         directory = 'docs',
---         groups = { { title = 'Начало', pages = { 'install', 'usage' } } },
---         hidden = { 'drafts' },
---     })
---
---     site.attach(require('http.server').new('127.0.0.1', 8088, { log_requests = false, idle_timeout = 60 }))
---
--- `new` отдаёт роутер `tnt-router`: раздел подключается к своему серверу
--- (`attach`), к роутеру приложения (`mount` — начало раздела и всё под
--- ним отвечает раздел, остальное — приложение) либо зовётся напрямую
--- (`dispatch`). Узлу без своего приложения — роль `tnt.docs.role`
--- со своим портом.
---
--- Что лежит в разделе и как разложено, решает приложение: своды
--- разметки, меню и группы, план ненаписанных страниц, скрытые
--- документы, карточки пакетов, рамка сайта вокруг раздела. Пакет знает
--- правила сайта: навигация, поиск по-русски, подсветка кода, тема,
--- отказы.

local settings = require('tnt.docs.settings')
local site = require('tnt.docs.site')

local Module = {}

---@class TntDocsSite: TntRouter Роутер раздела
---@field mount fun(app: TntRouter): TntRouter Подключает раздел к роутеру приложения

--- Заводит раздел.
---
--- Негодная настройка — ошибка программиста: бросок винит строку,
--- которая завела раздел.
---@param options TntDocsOptions
---@return TntDocsSite
function Module.new(options)
    local complaint = settings.explain(options)

    if complaint ~= nil then
        error(complaint, 2)
    end

    return site.new(settings.read(options))
end

return Module
