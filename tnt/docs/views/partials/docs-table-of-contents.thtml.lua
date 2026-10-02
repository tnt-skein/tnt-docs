{{-- Оглавление страницы на узком экране: липкий `<details>`.

     Колонки справа на узком экране нет, а знать, где ты в длинном
     документе, нужно и там. Поэтому оглавление едет с текстом полоской
     сверху: свёрнутая, она занимает одну строку и показывает название
     того раздела, который читатель видит прямо сейчас (название ставит
     контроллер `docs`); развёрнутая — весь список.

     `<details>`, а не своя кнопка с панелью: раскрытие, состояние
     и работа с клавиатуры у него уже есть, и повторять их сценарием
     значило бы делать хуже готового.

     Данные: `outline` — заголовки страницы. --}}
<details class="docs-table-of-contents d-block d-xxl-none mt-3 mb-4">
    <summary>
        <span>
            <span class="docs-toc-label">На этой странице</span>
            <span class="docs-toc-current" data-docs-target="currentSection"></span>
        </span>
        <span class="docs-toc-chevron" aria-hidden="true"></span>
    </summary>

    <div class="docs-table-of-contents-body">
        @include('partials.docs-anchors')
    </div>
</details>
