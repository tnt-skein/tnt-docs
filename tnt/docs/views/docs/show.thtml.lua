{{-- Страница документа: разметка markdown, разобранная на узле.

     Тело уходит сырым выводом `{!! !!}`: его собрал сам узел пакетом
     tnt-markdown, который экранирует всё, что пришло из разметки, —
     текст, содержимое ограды, адрес и подпись ссылки, — а сырой HTML
     из разметки в страницу не пускает и показывает текстом.

     Заголовок страницы рисует эта шапка, а не содержимое: первый
     заголовок разбор из текста убирает, иначе название стояло бы дважды.

     Полоска под заголовком говорит про сам документ: в какой группе меню
     он стоит, сколько в нём разделов, где лежит его исходный файл и,
     у документа пакета, где репозиторий. Под ней — команда установки
     пакета: обычная ограда кода, и полоску с подписью и кнопкой
     «скопировать» ей ставит тот же контроллер `docs`, что и оградам
     в тексте.

     Оглавление (`outline`) читается из того же дерева, из которого
     собран текст, поэтому якорь в нём — тот же, что стоит в заголовке.
     На широком экране его рисует колонка справа (рамка раздела), на узком —
     липкий `<details>` здесь же.

     Данные: `page` — страница (`title`, `summary`, `name`, `body`),
     `entry` — её пункт меню, `outline` — оглавление, `card` — карточка
     пакета либо пусто, `previous` и `following` — соседи. --}}
@extends('docs.layout')

{{-- Заголовок и описание — куском-блоком, а не строкой: блок
     собирается из `{{ }}` и потому экранируется, а значения приходят
     из документа. --}}
@section('title'){{ page.title }}@endsection
@section('description'){{ page.summary ~= '' and page.summary or (page.title .. ' — ' .. site.title) }}@endsection

@section('docs')
<h1 class="fw-bold text-body-emphasis">{{ page.title }}</h1>

<div class="docs-context d-flex flex-wrap align-items-center gap-2 mt-3 mb-4" aria-label="Сведения о документе">
    <span class="docs-context-item">{{ entry.group }}</span>
    <span class="docs-context-item">Разделов: {{ #outline }}</span>

    {{-- `data-turbo="false"`: по ссылке приходит не страница, а простой
         текст, и Turbo, ждущий HTML, всё равно ушёл бы на полную
         перезагрузку — пусть уходит сразу, без лишнего запроса. --}}
    <a href="{{ entry.address }}/source"
       class="docs-context-item text-decoration-none"
       data-turbo="false"
       title="{{ page.name }}.md">
        Исходный файл
    </a>

    @if (card and card.repository)
    <a href="{{ card.repository }}"
       class="docs-context-item text-decoration-none"
       target="_blank"
       rel="noopener">
        {{ card.name or 'Репозиторий' }}
    </a>
    @elseif (card and card.name)
    <span class="docs-context-item">{{ card.name }}</span>
    @endif
</div>

@if (card and card.install)
<div class="docs-package">
<pre><code class="language-bash">{{ card.install }}</code></pre>
</div>
@endif

@if (#outline > 0)
@include('partials.docs-table-of-contents')
@endif

{!! page.body !!}

@include('partials.docs-pager')
@endsection
