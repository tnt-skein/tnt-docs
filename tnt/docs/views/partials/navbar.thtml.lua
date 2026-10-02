{{-- Шапка сайта: марка, пункты, выпадающее меню и ссылки наружу.

     Что в шапке, решает приложение (`frame` в настройках раздела): марка,
     пункты по порядку — ссылка либо выпадающее меню колонками, — и ссылки
     справа. На узком экране пункты раскрываются списком на месте
     (`collapse`): отдельной страницы-меню у раздела нет.

     Данные: `site.frame` — рамка, `menu` — пункты для этой страницы
     с отметкой открытого (`frame.menu_at`). Ссылка справа со значком
     на узком экране показывается значком, без значка — уходит в список
     пунктов. --}}
<div class="container mt-md-4 mb-3">
    <div class="my-2 my-lg-4">
        <header class="d-flex flex-wrap align-items-center justify-content-between">

            {{-- Марка и кнопка меню на узком экране --}}
            <div class="col-md-auto d-lg-none me-2 me-sm-3">
                <a href="#site-menu"
                   class="nav-link link-body-emphasis text-decoration-none d-flex align-items-center"
                   role="button"
                   data-bs-toggle="collapse"
                   aria-controls="site-menu"
                   aria-expanded="false"
                   aria-label="Открыть главное меню">
                    @include('partials.icon', { icon = 'logo', size = '2em', class = 'text-primary me-2' })
                    @include('partials.icon', { icon = 'menu', size = '2em' })
                </a>
            </div>

            {{-- Марка на широком экране --}}
            <div class="col-md-auto me-auto me-lg-2">
                <a href="{{ site.frame.home }}"
                   class="d-none d-lg-inline-flex align-items-center gap-2 link-body-emphasis text-decoration-none"
                   aria-label="{{ site.frame.brand }} — главная">
                    @include('partials.icon', { icon = 'logo', size = '2.25em', class = 'text-primary' })
                    <span class="fs-4 fw-bold">{{ site.frame.brand }}</span>
                </a>
            </div>

            {{-- Пункты шапки --}}
            <ul class="nav col-12 col-md-auto mb-2 justify-content-center mb-md-0 d-none d-lg-flex">
                @for (_, item in ipairs(menu))
                @if (item.columns)
                {{-- `dropdown-menu-end` стоит на самом меню, а не на пункте
                     списка: оно широкое, и от правого края шапки его нужно
                     выравнивать по правому краю. --}}
                <li class="dropdown">
                    <a href="#"
                       class="nav-link px-3 link-body-emphasis dropdown-toggle"
                       data-bs-toggle="dropdown"
                       aria-expanded="false">
                        {{ item.title }}
                    </a>

                    <div class="dropdown-menu dropdown-menu-end bg-body-tertiary shadow-lg border-0 p-0">
                        <div class="d-lg-flex p-5 gap-4">
                            @for (_, column in ipairs(item.columns))
                            <ul class="list-unstyled d-flex flex-column gap-4 mega-menu-column">
                                @for (_, link in ipairs(column))
                                <li>
                                    <a href="{{ link.href }}"
                                       class="link-body-emphasis text-decoration-none rounded-2 d-flex align-items-start gap-3 lh-sm text-start">
                                        @include('partials.icon', { icon = link.icon, size = '2rem', class = 'text-primary' })
                                        <div class="col-10">
                                            <span class="d-block">{{ link.title }}</span>
                                            <small class="opacity-50 line-clamp-2 text-balance">{{ link.note }}</small>
                                        </div>
                                    </a>
                                </li>
                                @endfor
                            </ul>
                            @endfor
                        </div>
                    </div>
                </li>
                @else
                <li>
                    <a href="{{ item.href }}" class="nav-link px-3 link-body-emphasis {{ item.active and 'active' or '' }}"@if (item.external) target="_blank" rel="noopener"@endif>
                        {{ item.title }}
                    </a>
                </li>
                @endif
                @endfor
            </ul>

            {{-- Правая часть: то, что уводит со страницы. --}}
            <div class="nav text-end">
                @for (_, link in ipairs(site.frame.links))
                <a href="{{ link.href }}"
                   class="nav-link link-body-emphasis d-none d-md-inline-flex"@if (link.external)
                   target="_blank"
                   rel="noopener"@endif>
                    {{ link.title }}
                </a>
                @if (link.icon)

                <a href="{{ link.href }}"
                   class="nav-link link-body-emphasis d-md-none"@if (link.external)
                   target="_blank"
                   rel="noopener"@endif
                   aria-label="{{ link.title }}">
                    @include('partials.icon', { icon = link.icon, size = '1.5em' })
                </a>
                @endif
                @endfor
            </div>
        </header>

        {{-- Меню узкого экрана: те же пункты, колонки выпадающего меню
             подряд и ссылки справа без значка. --}}
        <div class="collapse d-lg-none" id="site-menu">
            <ul class="nav flex-column mt-3 border-top pt-3">
                @for (_, item in ipairs(menu))
                @if (item.columns)
                @for (_, column in ipairs(item.columns))
                @for (_, link in ipairs(column))
                <li class="nav-item">
                    <a href="{{ link.href }}" class="nav-link px-0 link-body-emphasis">{{ link.title }}</a>
                </li>
                @endfor
                @endfor
                @else
                <li class="nav-item">
                    <a href="{{ item.href }}" class="nav-link px-0 link-body-emphasis {{ item.active and 'active' or '' }}"@if (item.external) target="_blank" rel="noopener"@endif>{{ item.title }}</a>
                </li>
                @endif
                @endfor
                @for (_, link in ipairs(site.frame.links))
                @unless (link.icon)
                <li class="nav-item">
                    <a href="{{ link.href }}" class="nav-link px-0 link-body-emphasis"@if (link.external) target="_blank" rel="noopener"@endif>{{ link.title }}</a>
                </li>
                @endunless
                @endfor
            </ul>
        </div>
    </div>
</div>
