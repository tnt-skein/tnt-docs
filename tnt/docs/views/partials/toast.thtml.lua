{{-- Всплывающие сообщения.

     Контейнер стоит в рамке сайта и приезжает с каждой страницей. Пустой
     он ничего не загораживает: `.toast-container` пропускает нажатия
     сквозь себя (`pointer-events: none`), а сами сообщения их ловят.

     Наполняют его двое:

     — страница — списком `toasts` в данных. Запись сообщения:

           { message = 'Настройки сохранены', level = 'success' }

     — сценарий на странице — событием `toast` у окна:

           window.dispatchEvent(new CustomEvent('toast', {
               detail: { message: 'Скопировано', level: 'info' },
           }));

       Так о своей удаче или беде сообщает то, что случилось без
       перехода, — окно поиска, когда узел не ответил.

     Разметку сообщения обоим даёт partials/toast-message: пришедшие
     со страницей стоят готовыми, а заготовка для сценария лежит
     в <template> — его содержимое браузер не рисует и не считает
     частью документа, поэтому Stimulus не видит в нём ни целей,
     ни контроллеров.

     Место — сверху: по центру на узком экране, у правого края
     на широком. Классы вместо `fixed-top`: та утилита заодно ставит свой
     `z-index` (1030) и увела бы сообщения под то, что Bootstrap кладёт
     выше, — у `.toast-container` он 1090. --}}
<div class="toast-container position-fixed top-0 start-0 w-100 p-3 d-flex flex-column align-items-center align-items-md-end"
     data-controller="toast"
     data-action="toast@window->toast#notify">
    <template data-toast-target="template">
        @include('partials.toast-message', { toast = { message = '' } })
    </template>

    @for (_, toast in ipairs(toasts or {}))
    @include('partials.toast-message', { toast = toast })
    @endfor
</div>
