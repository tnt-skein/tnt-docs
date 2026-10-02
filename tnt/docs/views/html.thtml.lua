{{-- Документ целиком — внешняя оболочка каждой страницы раздела.

     Всё, что снаружи содержимого, живёт одним файлом: мета-теги, тема,
     значки, ссылки на вид раздела. Рамка сайта (layouts.app) наследует
     этот документ и наполняет кусок `body`, страницы наследуют рамку.

     Данные от каждой страницы (`view_data` раздела): `site` — общее
     (название, рамка, адреса вида), `path` — путь запроса. --}}
<!DOCTYPE html>
<html lang="{{ site.frame.locale }}" data-bs-theme="auto">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="google" content="notranslate">

    {{-- Тема — раньше стилей и раньше разметки: файлом без `defer`, до
         первой отрисовки. Встроенным сценарием её не поставить — правило
         источников раздела его не пустит, — а поставь её контроллер
         Stimulus, страница на миг мелькала бы светлой при каждом
         открытии. Turbo файл второй раз не исполняет: адрес тот же. --}}
    <script src="{{ site.assets.theme }}"></script>

    <title>@yield('title', site.title) · {{ site.frame.brand }}</title>
    <meta name="description" content="@yield('description', site.frame.description or site.title)">

    {{-- Значки: SVG читают нынешние браузеры, PNG 32×32 — запас для тех,
         что не читают (он объявлен раньше SVG, чтобы такой браузер нашёл
         понятную ему ссылку первой), PNG 180×180 — плитка iOS. --}}
    <link rel="icon" type="image/png" sizes="32x32" href="{{ site.assets.png }}">
    <link rel="icon" type="image/svg+xml" href="{{ site.assets.icon }}">
    <link rel="apple-touch-icon" sizes="180x180" href="{{ site.assets.touch }}">

    {{-- Цвет полотна в обеих темах: его берут строка состояния мобильного
         браузера и системные элементы вокруг страницы. Значения — те же,
         что у $body-bg и $body-bg-dark в стилях раздела. --}}
    <meta name="color-scheme" content="light dark">
    <meta name="theme-color" content="#fafafa" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#161822" media="(prefers-color-scheme: dark)">

    {{-- Как страница выглядит, когда ссылку на неё кладут в мессенджер.
         Адрес и картинка — только с внешним адресом сайта: разметку читает
         чужой сервер, и разрешать относительную ссылку ему не от чего. --}}
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="{{ site.frame.brand }}">
    <meta property="og:locale" content="{{ site.frame.locale }}">
    <meta property="og:title" content="@yield('title', site.title) · {{ site.frame.brand }}">
    <meta property="og:description" content="@yield('description', site.frame.description or site.title)">
    @if (site.frame.url)
    <meta property="og:url" content="{{ site.frame.url }}{{ path }}">
    @if (site.frame.image)
    <meta property="og:image" content="{{ site.frame.url }}{{ site.frame.image }}">
    <meta name="twitter:card" content="summary_large_image">
    @endif
    @endif

    {{-- Turbo меняет тело документа без перезагрузки: `morph` оставляет
         на месте совпавшие узлы, а `view-transition` разрешает браузеру
         растворить старый вид в новом вместо мигания. --}}
    <meta name="view-transition" content="same-origin">
    <meta name="turbo-refresh-method" content="morph">
    <meta name="turbo-refresh-scroll" content="preserve">

    {{-- Вид раздела — с меткой версии в адресе. `data-turbo-track`:
         страницы сайта вне раздела несут свой вид, и переход между ними
         и разделом Turbo делает полной загрузкой, а не подменой тела —
         иначе на странице оказались бы два набора стилей и сценариев. --}}
    <link rel="stylesheet" href="{{ site.assets.css }}" data-turbo-track="reload">
    <script src="{{ site.assets.js }}" defer data-turbo-track="reload"></script>

    @yield('head')
</head>
<body data-controller="theme">
@yield('body')
</body>
</html>
