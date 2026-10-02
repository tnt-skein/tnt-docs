{{-- Соседние страницы раздела — для узкого экрана.

     Колонка меню слева уходит ниже `lg`, и без этого куска читатель
     с телефона не мог бы перейти к соседней странице вовсе: ссылки
     внутри текста ведут по смыслу, а не по порядку чтения.

     Показываются страницы только той группы, в которой стоит читатель,
     и ссылка на все разделы следом: на план, если он есть, иначе
     на главную раздела. Всё меню целиком сюда не переносится нарочно:
     сотня пунктов — это четверть веса страницы.

     Данные: `navigation` — группы, `opened` — название группы открытой
     страницы, `entry` — её пункт (пусто на главной и 404), `path` — путь
     запроса. --}}
<details class="docs-nearby d-block d-lg-none mb-3">
    <summary>
        <span>
            <span class="docs-toc-label">Раздел «{{ opened }}»</span>
            <span class="docs-nearby-current">{{ entry and entry.title or site.title }}</span>
        </span>
        <span class="docs-toc-chevron" aria-hidden="true"></span>
    </summary>

    <div class="docs-nearby-body">
        <ul class="docs-menu-links list-unstyled">
            @for (_, group in ipairs(navigation.groups))
            @if (group.title == opened)
            @for (_, item in ipairs(group.entries))
            <li>
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
            @endif
            @endfor

            @if (navigation.plan)
            <li>
                <a href="{{ navigation.plan.address }}" class="text-decoration-none">Все разделы документации</a>
            </li>
            @elseif (site.start == nil)
            <li>
                <a href="{{ site.home }}" class="text-decoration-none">Все разделы документации</a>
            </li>
            @endif
        </ul>
    </div>
</details>
