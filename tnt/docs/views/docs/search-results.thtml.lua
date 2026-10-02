{{-- Ответы поиска по документации: список, который подменяется целиком.

     Кусок с тремя читателями: окно поиска включает его при сборке
     страницы — пустым, с подсказками, — адрес `search.html` отдаёт его
     же ответом на набранное, а страница выдачи (`docs.found`) рисует им
     свой список. Один шаблон на все три значит, что списки не могут
     разойтись вёрсткой.

     Состояний три, и различают их два поля данных:

     — нашлось: `results.items` непуст — строки находок;
     — не нашлось: пуст, а `asked` истинно — читатель набрал то, чего
       в документации нет;
     — ещё не спрашивали: пуст и `asked` ложно — окно только что открыли,
       и вместо пустоты в нём стоят подсказки.

     Строка находки — три яруса: страница, заголовок раздела и отрывок
     вокруг найденного. Сначала страница: одно и то же слово стоит
     в разделах разных страниц, и «где это написано» читателю нужно
     раньше, чем «как называется раздел». Ярус страницы пропадает, когда
     найдено вступление страницы, а не раздел в ней: её название стояло
     бы в строке дважды подряд.

     Отрывок уходит сырым выводом: он собран на узле из текста раздела,
     текст экранирован, а отметки `<mark>` поставлены поверх.

     Данные: `results` — выдача (`items`, `partial`), `asked` — был ли
     запрос, `site.suggestions` — куда звать, пока не спрашивали. --}}
<ul class="docs-search-results list-unstyled">
@if (results.items[1])
    @if (results.partial)
    <li class="docs-search-partial">Всех слов вместе нет ни в одном разделе — показаны разделы хотя бы с одним.</li>
    @endif
    @for (_, item in ipairs(results.items))
    <li>
        <a href="{{ item.url }}" class="docs-search-result text-decoration-none">
            @if (item.section)
            <span class="docs-search-result-page">{{ item.title }}</span>
            @endif
            <span class="docs-search-result-title">{{ item.section or item.title }}</span>
            <span class="docs-search-result-snippet">{!! item.snippet !!}</span>
        </a>
    </li>
    @endfor
@elseif (asked)
    {{-- Почему не нашлось — сказано сразу: слово ищется в любой форме,
         а все слова запроса — вместе, и лишнее слово чаще всего и мешает. --}}
    <li class="docs-search-empty">
        <strong>Ничего не найдено</strong>
        <span>Слово ищется в любой форме: попробуйте другое или уберите лишнее из запроса.</span>
    </li>
@elseif (site.suggestions[1])
    <li class="docs-search-suggestions">
        <p class="docs-search-suggestions-label">Смотрите также:</p>

        @for (_, item in ipairs(site.suggestions))
        <a href="{{ item.href }}" class="docs-search-suggestion text-decoration-none">
            @include('partials.icon', { icon = item.icon, size = '1.25rem' })
            <span class="docs-search-suggestion-copy">
                <strong>{{ item.title }}</strong>
                @if (item.note)
                <span>{{ item.note }}</span>
                @endif
            </span>
        </a>
        @endfor
    </li>
@endif
</ul>
