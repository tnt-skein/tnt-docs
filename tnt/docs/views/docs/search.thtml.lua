{{-- Окно поиска по документации: модалка Bootstrap на ⌘K.

     Стоит в рамке раздела, поэтому открывается с любой его страницы —
     и с документа, и с заглушки, и с 404: искать читателю чаще нужно
     как раз там, где он не нашёл нужного глазами.

     Открывают его двое: кнопка над меню (`partials.docs-search-button`)
     средствами самого Bootstrap (`data-bs-toggle`) и сочетание ⌘K либо
     Ctrl+K — его ловит контроллер `docs-search` слушателем у окна.
     Закрывает — Esc, крестик и нажатие мимо окна; всё три от Bootstrap.

     Формы вокруг поля нет: запрос уходит по вводу, через 220 мс тишины.
     Без сценариев окно и вовсе не открывается, а поиск без сценария —
     страница выдачи на начале раздела (`?q=`).

     Ответ на набранное — кусок `docs.search-results` с адреса
     `search.html`: тот же шаблон, что стоит в окне при открытии, и список
     в окне и список из ответа не могут разойтись вёрсткой.

     Данные: `site.found` — адрес ответов окна, `site.suggestions` —
     подсказки пустого окна. --}}
<div class="modal docs-search-modal fade"
     id="docs-search-modal"
     tabindex="-1"
     aria-labelledby="docs-search-title"
     aria-hidden="true"
     data-controller="docs-search"
     data-docs-search-url-value="{{ site.found }}"
     data-action="keydown@window->docs-search#open
                  shown.bs.modal->docs-search#opened
                  turbo:before-cache@document->docs-search#teardown">
    <div class="modal-dialog docs-search-dialog">
        <div class="modal-content docs-search-surface">
            <div class="modal-body">
                <div class="docs-search-header">
                    <div>
                        <h2 class="docs-search-title" id="docs-search-title">Поиск по документации</h2>
                        <p class="docs-search-note">По заголовкам и тексту разделов, в любой форме слова</p>
                    </div>

                    <button type="button"
                            class="btn-close docs-search-close"
                            data-bs-dismiss="modal"
                            aria-label="Закрыть поиск"></button>
                </div>

                {{-- Подпись поля спрятана от глаз, но не от чтеца:
                     подсказка внутри поля исчезает с первой набранной
                     буквой, а подпись остаётся. --}}
                <label for="docs-search-input" class="visually-hidden">Что искать</label>

                <div class="docs-search-field">
                    @include('partials.icon', { icon = 'search' })

                    {{-- `autofocus` — для того случая, когда окно уже
                         открыто при загрузке страницы; при показе
                         модалки фокус ставит контроллер. --}}
                    <input class="form-control"
                           id="docs-search-input"
                           name="q"
                           type="search"
                           placeholder="Введите слово или несколько"
                           autocomplete="off"
                           maxlength="{{ site.query_length }}"
                           autofocus
                           data-docs-search-target="field"
                           data-action="input->docs-search#search keydown->docs-search#jump">

                    <kbd aria-hidden="true">Esc</kbd>
                </div>

                {{-- Живая область — обёртка, а не сам список: список
                     подменяется целиком на каждый ответ, а чтец обязан
                     читать изменения в одном и том же месте страницы. --}}
                <div class="docs-search-output"
                     role="status"
                     aria-live="polite"
                     data-docs-search-target="output">
                    @include('docs.search-results', { results = { items = {} }, asked = false })
                </div>
            </div>
        </div>
    </div>
</div>
