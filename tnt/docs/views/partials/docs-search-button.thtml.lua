{{-- Кнопка, открывающая окно поиска по документации.

     Куском, а не двумя копиями разметки: кнопка стоит в двух местах —
     над меню на широком экране и над текстом на узком, где колонки меню
     нет вовсе, — и подпись сочетания клавиш у них обязана совпадать.

     Открывает окно сам Bootstrap по `data-bs-target`, без единой строки
     своего кода. Подпись `⌘K` — второй способ открытия, его ловит
     контроллер `docs-search`; на не-яблочной клавиатуре тот же
     контроллер меняет подпись на `Ctrl K` — сочетание там другое,
     и обещать читателю несуществующую клавишу нельзя.

     Данные: `extra_class` — классы сверх своих (отступ, порог
     видимости). Имя не `class` нарочно: `@include` отдаёт свои данные
     и вложенным кускам, а у иконки внутри поле `class` своё — оно
     получило бы отступ кнопки. --}}
<button type="button"
        class="docs-search-trigger btn d-flex align-items-center gap-2 w-100 text-start {{ extra_class or '' }}"
        data-bs-toggle="modal"
        data-bs-target="#docs-search-modal"
        aria-label="Поиск по документации">
    @include('partials.icon', { icon = 'search' })
    <span class="flex-grow-1">Поиск</span>
    <kbd class="docs-search-shortcut" aria-hidden="true">⌘K</kbd>
</button>
