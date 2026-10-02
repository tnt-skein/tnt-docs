{{-- Соседние страницы по порядку меню: «назад» и «вперёд» в конце текста.

     Порядок — сквозной по группам меню и мимо заглушек: последняя
     страница группы ведёт к первой странице следующей. Ссылка «вперёд»
     стоит справа, даже когда ссылки «назад» нет: место ссылки
     говорит, куда она ведёт.

     Данные: `previous` и `following` — пункты меню либо пусто. --}}
@if (previous or following)
<nav class="docs-pager" aria-label="Соседние страницы">
    @if (previous)
    <a class="docs-pager-link" href="{{ previous.address }}" rel="prev">
        <span class="docs-pager-label">Назад</span>
        <span class="docs-pager-title">{{ previous.title }}</span>
    </a>
    @endif
    @if (following)
    <a class="docs-pager-link docs-pager-next" href="{{ following.address }}" rel="next">
        <span class="docs-pager-label">Вперёд</span>
        <span class="docs-pager-title">{{ following.title }}</span>
    </a>
    @endif
</nav>
@endif
