{{-- Рамка раздела документации: три колонки в один ряд.

     Между рамкой сайта и страницей раздела стоит ещё одна рамка, потому
     что меню нужно каждой странице раздела — и документу, и заглушке,
     и плану, и главной, и выдаче, и 404.

     Колонок три, и каждая уходит со своего порога: меню слева видно
     от `lg`, текст стоит посередине всегда, колонка оглавления справа
     появляется только на `xxl`. На узком экране обе боковины спрятаны,
     и то, что было в них, едет с текстом раскрывающимися полосками:
     соседние страницы раздела (`partials.docs-nearby`) и оглавление
     самой страницы (`partials.docs-table-of-contents`).

     `align-items-start` на ряду — не украшение: колонка с
     `position-sticky` внутри ряда, растянутого по высоте (умолчание
     flex — `stretch`), прилипать не может, потому что её высота уже
     равна высоте ряда.

     Контейнер свой — `container-docs`: три колонки в общие 1120 пикселей
     рамки не помещаются, и текст в них ужимался бы до половины строки.

     Данные: `navigation` — группы меню, `opened` — название раскрытой
     группы, `entry` — пункт открытой страницы, `outline` — оглавление
     страницы либо пусто. --}}
@extends('layouts.app')

@section('content')
{{-- Контроллер один на весь раздел: он и меню раскрывает, и подсвечивает
     раздел при прокрутке, и собирает кнопки «скопировать» у блоков кода.
     Поставить его на текст было бы мало — меню лежит в соседней
     колонке. --}}
<div class="container container-docs my-4 my-xxl-5" data-controller="docs">
    <div class="row gap-2 justify-content-center align-items-start position-relative mb-5">
        {{-- Меню — первым в разметке: на узком экране оно спрятано, а
             чтец и обход табуляцией идут по порядку разметки, и меню
             раздела должно встречаться до его текста. --}}
        <aside class="col-3 col-xl-3 col-xxl-2 position-sticky py-md-3 z-1 d-none d-lg-block doc-navigation"
               aria-label="Навигация по документации">
            @include('partials.docs-menu')
        </aside>

        <div class="px-0 px-md-2 px-xl-3 col-md-10 col-lg-8 col-xl-8 col-xxl-6">
            {{-- Полотно текста — свой класс, а не утилиты Bootstrap:
                 на узком экране карточка вокруг текста пропадает вовсе,
                 а утилиты пишутся с `!important`. --}}
            <div class="docs-content-surface">
                {{-- Вторая кнопка поиска — для узкого экрана: колонка
                     меню там спрятана вместе с первой. --}}
                @include('partials.docs-search-button', { extra_class = 'd-lg-none mb-3' })

                @include('partials.docs-nearby')

                <article class="docs-content position-relative">
                    @yield('docs')
                </article>
            </div>
        </div>

        {{-- Колонка оглавления есть только у страницы с текстом: у плана,
             заглушки и 404 оглавления нет, и пустая колонка забирала бы
             у текста шестую часть ряда. --}}
        @if (outline ~= nil and #outline > 0)
        <aside class="col-3 col-xl-2 position-sticky py-md-3 z-1 d-none d-xxl-block doc-navigation"
               aria-label="Оглавление страницы">
            <p class="docs-sidebar-label">На этой странице</p>
            @include('partials.docs-anchors')
        </aside>
        @endif
    </div>
</div>

{{-- Окно поиска — вне ряда колонок нарочно: оно накрывает страницу
     целиком, а внутри колонки с `position: sticky` и своей прокруткой
     его положение считалось бы от боковины, а не от окна браузера. --}}
@include('docs.search')
@endsection
