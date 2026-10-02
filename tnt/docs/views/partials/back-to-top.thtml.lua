{{-- Кнопка «Наверх».

     Обёртка высотой в экран стоит у начала страницы: пока она видна,
     контроллер `viewport-entrance-toggle` держит на ней класс, который
     прячет кнопку. Стоит странице прокрутиться — обёртка уходит за край,
     класс снимается, кнопка появляется. Ни одного обработчика прокрутки:
     браузер будит наблюдателя только на пересечении границы. --}}
<div class="back-to-top-container back-to-top-container--intersecting d-none d-md-block"
     data-controller="viewport-entrance-toggle"
     data-viewport-entrance-toggle-class-value="back-to-top-container--intersecting">
    <button class="back-to-top__button btn btn-primary d-inline-flex align-items-center"
            type="button"
            data-controller="scroll"
            data-action="click->scroll#go">
        Наверх
        @include('partials.icon', { icon = 'angle-up', class = 'ms-2' })
    </button>
</div>
