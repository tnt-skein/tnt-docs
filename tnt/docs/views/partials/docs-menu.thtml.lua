{{-- Колонка меню раздела документации: группы-гармошка.

     Уровней ровно два: группа меню и список её страниц. Своды третьим
     уровнем над ними не стоят: читателю важно, о чём страница, а не
     в каком каталоге лежит её файл.

     Открыта одна группа — та, в которой стоит читатель; остальные
     свёрнуты, и открытие соседней закрывает прежнюю (контроллер `docs`).
     Иначе колонка из сотни пунктов не помещалась бы на экран.

     Раскрывается группа не Bootstrap Collapse, а гридом: панель — это
     `grid-template-rows: 0fr`, которое становится `1fr`. Collapse считает
     высоту сценарием и ставит её стилем; грид делает то же самое без
     единой строки сценария, и высота не «застревает» на числе, если
     содержимое поменялось.

     Свёрнутая панель получает `inert` и `aria-hidden`: спрятанная
     прозрачностью, она осталась бы в обходе табуляцией.

     Меню показывает весь план, а не только написанное: пункт, за которым
     страницы ещё нет, рисуется приглушённо и с подписью «скоро», но
     остаётся ссылкой — открывается заглушка.

     Над меню стоит кнопка поиска: колонка — первое, куда смотрит
     читатель, пришедший искать.

     Данные: `navigation` — группы, `opened` — название раскрытой группы,
     `path` — путь запроса, по нему отмечается открытая страница. --}}
@include('partials.docs-search-button', { extra_class = 'mb-3' })

<nav aria-label="Разделы документации">
    <ul class="docs-menu-list list-unstyled">
        @for (index, group in ipairs(navigation.groups))
        <li>
            {{-- Номер группы в `id` панели — от порядка в меню: названия
                 русские, и собранное из них имя пришлось бы переводить
                 в латиницу. --}}
            <button type="button"
                    class="docs-menu-section btn d-flex align-items-center border-0 w-100 text-start"
                    data-action="click->docs#toggleSection"
                    aria-controls="docs-menu-panel-{{ index }}"
                    aria-expanded="{{ group.title == opened and 'true' or 'false' }}">
                {{ group.title }}
            </button>

            <div class="docs-menu-panel"
                 id="docs-menu-panel-{{ index }}"
                 data-expanded="{{ group.title == opened and 'true' or 'false' }}"
                 aria-hidden="{{ group.title == opened and 'false' or 'true' }}"
                 @unless (group.title == opened)inert @endunless>
                <div class="docs-menu-panel-inner">
                    <ul class="docs-menu-links list-unstyled">
                        @for (_, item in ipairs(group.entries))
                        <li>
                            {{-- Открытой странице подложку и насыщенность
                                 даёт `aria-current`, а не отдельный класс:
                                 два имени одного состояния однажды
                                 разойдутся. --}}
                            <a href="{{ item.address }}"
                               class="text-decoration-none {{ item.written and '' or 'docs-menu-upcoming' }}"
                               aria-current="{{ item.address == path and 'page' or 'false' }}">
                                <span>{{ item.title }}</span>
                                @unless (item.written)
                                <span class="badge rounded-pill text-bg-secondary fw-normal">скоро</span>
                                @endunless
                            </a>
                        </li>
                        @endfor
                    </ul>
                </div>
            </div>
        </li>
        @endfor
    </ul>
</nav>
