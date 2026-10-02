rockspec_format = '3.0'

package = 'tnt-docs'
version = 'scm-1'

source = {
    url = 'git+https://github.com/tnt-skein/tnt-docs.git',
    branch = 'main',
}

description = {
    summary = 'Раздел документации из каталогов markdown: меню с планом, поиск по-русски, рамка сайта',
    detailed = [[
        Раздел документации для приложения на Tarantool: каталоги файлов
        markdown становятся сайтом прямо на узле. Документы лежат одним
        каталогом либо сводами — руководство приложения и документы
        пакетов из соседнего репозитория — со ссылками между ними.

        Меню разделов задаёт приложение — файлом меню, группами или тем
        и другим: колонка-гармошка, «назад» и «вперёд» по порядку меню,
        главная с карточками страниц. Пункт меню, за которым страницы ещё
        нет, открывается заглушкой «скоро» с тем, что на ней будет и чего
        для этого не хватает, а сводная страница показывает весь план
        одной таблицей.

        Поиск идёт по разделам страниц с русской морфологией — запрос
        «шаблоны» находит и «шаблон», — в окне ⌘K по мере набора и на
        странице выдачи, которая работает без сценариев; ответ JSON — для
        своих клиентов.

        Разметка разбирается один раз на правку: страницы и указатель
        поиска собираются заново, только когда разметка на диске стала
        другой, сверкой по содержимому, и прогреваются в фоне при подъёме.
        Ссылка на скрытый или несуществующий документ и на файл, которого
        сайт не отдаёт, остаётся текстом.

        Страница рисуется целиком, внутри рамки сайта: марку, пункты шапки,
        ссылки наружу и подвал даёт приложение. Вид — Bootstrap 5.3 со
        своими токенами, шрифты Inter и Raleway, Turbo и Stimulus,
        подсветка кода Prism, светлая и тёмная тема. Стили, сценарии,
        значки и шрифты упакованы в модуль и раздаются из памяти узла
        с меткой версии в адресе и годовым кэшем. Каждый ответ несёт
        Content-Security-Policy без встроенных сценариев и стилей; отказ —
        страницей с номером происшествия, подробности — в журнал.

        Подключается к своему серверу, к роутеру приложения участком
        адресов либо ролью tnt.docs.role со своим портом. Зависит
        от tnt-markdown, tnt-router, tnt-template, tnt-morphology, tnt-fs,
        tnt-log, tnt-clock, tnt-context, tnt-must и tnt-external. Покрытие
        строк и убитых мутантов — 100 %.

        Код — MIT; оформление — CC BY-NC-SA 4.0, шрифты — SIL OFL 1.1:
        подробности в NOTICE.
    ]],
    homepage = 'https://github.com/tnt-skein/tnt-docs',
    issues_url = 'https://github.com/tnt-skein/tnt-docs/issues',
    maintainer = 'tnt-skein',
    -- Код — MIT, оформление (стили, шаблоны рамки и раздела) — CC BY-NC-SA
    -- 4.0, шрифты — OFL 1.1: что к чему относится, сказано в NOTICE.
    license = 'MIT AND CC-BY-NC-SA-4.0 AND OFL-1.1',
    labels = { 'tarantool', 'documentation', 'markdown', 'search', 'site' },
}

dependencies = {
    'lua >= 5.1',
    -- Сервер, который поднимает роль раздела на своём порту.
    'http',
    -- Разметка в дерево, страницу, оглавление и разделы указателя.
    'tnt-markdown',
    -- Адреса, слой метки версии, раздача вида из памяти и отказы.
    'tnt-router',
    -- Рамка и страницы раздела шаблонами с экранированием по умолчанию.
    'tnt-template',
    -- Основа слова для поиска: «шаблоны» находит «шаблон».
    'tnt-morphology',
    -- Чтение каталога разметки: отказ диска — пара с родом.
    'tnt-fs',
    -- Запись о документе, который не собрать, и о непрогретом разделе.
    'tnt-log',
    -- Монотонные часы: когда издание сверялось с диском.
    'tnt-clock',
    -- Контекст подключившего в файбере прогрева: записи о сборке несут
    -- его опознаватель.
    'tnt-context',
    -- Проверка настроек раздела и бросок без места.
    'tnt-must',
    -- Подмена часов, уступки и поиска модуля в проверках.
    'tnt-external',
}

build = {
    type = 'builtin',
    modules = {
        ['tnt.docs'] = 'tnt/docs.lua',
        ['tnt.docs.assets'] = 'tnt/docs/assets.lua',
        ['tnt.docs.finder'] = 'tnt/docs/finder.lua',
        ['tnt.docs.frame'] = 'tnt/docs/frame.lua',
        ['tnt.docs.headers'] = 'tnt/docs/headers.lua',
        ['tnt.docs.library'] = 'tnt/docs/library.lua',
        ['tnt.docs.menu'] = 'tnt/docs/menu.lua',
        ['tnt.docs.navigation'] = 'tnt/docs/navigation.lua',
        ['tnt.docs.page'] = 'tnt/docs/page.lua',
        ['tnt.docs.public.bundle'] = 'tnt/docs/public/bundle.lua',
        ['tnt.docs.role'] = 'tnt/docs/role.lua',
        ['tnt.docs.search'] = 'tnt/docs/search.lua',
        ['tnt.docs.settings'] = 'tnt/docs/settings.lua',
        ['tnt.docs.site'] = 'tnt/docs/site.lua',
        ['tnt.docs.snippet'] = 'tnt/docs/snippet.lua',
        ['tnt.docs.views.docs.found'] = 'tnt/docs/views/docs/found.thtml.lua',
        ['tnt.docs.views.docs.index'] = 'tnt/docs/views/docs/index.thtml.lua',
        ['tnt.docs.views.docs.layout'] = 'tnt/docs/views/docs/layout.thtml.lua',
        ['tnt.docs.views.docs.plan'] = 'tnt/docs/views/docs/plan.thtml.lua',
        ['tnt.docs.views.docs.refusal'] = 'tnt/docs/views/docs/refusal.thtml.lua',
        ['tnt.docs.views.docs.search'] = 'tnt/docs/views/docs/search.thtml.lua',
        ['tnt.docs.views.docs.search-results'] = 'tnt/docs/views/docs/search-results.thtml.lua',
        ['tnt.docs.views.docs.show'] = 'tnt/docs/views/docs/show.thtml.lua',
        ['tnt.docs.views.docs.upcoming'] = 'tnt/docs/views/docs/upcoming.thtml.lua',
        ['tnt.docs.views.html'] = 'tnt/docs/views/html.thtml.lua',
        ['tnt.docs.views.layouts.app'] = 'tnt/docs/views/layouts/app.thtml.lua',
        ['tnt.docs.views.partials.back-to-top'] = 'tnt/docs/views/partials/back-to-top.thtml.lua',
        ['tnt.docs.views.partials.docs-anchors'] = 'tnt/docs/views/partials/docs-anchors.thtml.lua',
        ['tnt.docs.views.partials.docs-menu'] = 'tnt/docs/views/partials/docs-menu.thtml.lua',
        ['tnt.docs.views.partials.docs-nearby'] = 'tnt/docs/views/partials/docs-nearby.thtml.lua',
        ['tnt.docs.views.partials.docs-pager'] = 'tnt/docs/views/partials/docs-pager.thtml.lua',
        ['tnt.docs.views.partials.docs-search-button'] = 'tnt/docs/views/partials/docs-search-button.thtml.lua',
        ['tnt.docs.views.partials.docs-table-of-contents'] = 'tnt/docs/views/partials/docs-table-of-contents.thtml.lua',
        ['tnt.docs.views.partials.footer'] = 'tnt/docs/views/partials/footer.thtml.lua',
        ['tnt.docs.views.partials.icon'] = 'tnt/docs/views/partials/icon.thtml.lua',
        ['tnt.docs.views.partials.navbar'] = 'tnt/docs/views/partials/navbar.thtml.lua',
        ['tnt.docs.views.partials.toast'] = 'tnt/docs/views/partials/toast.thtml.lua',
        ['tnt.docs.views.partials.toast-message'] = 'tnt/docs/views/partials/toast-message.thtml.lua',
        ['tnt.docs.words'] = 'tnt/docs/words.lua',
    },
}
