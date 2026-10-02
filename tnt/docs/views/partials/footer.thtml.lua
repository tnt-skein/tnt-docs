{{-- Подвал: марка, колонки ссылок, переключатель темы и подпись.

     Тёмная полоса во всю ширину (`data-bs-theme="dark"` переключает
     переменные Bootstrap внутри неё, и светлая тема страницы подвала
     не касается), внутри — колонки. Подвал виден и на узком экране:
     переключатель темы живёт именно здесь, и колонки расходятся
     по точкам останова.

     Данные: `site.frame` — марка, описание, абзац (`note`, HTML
     из разметки приложения), колонки ссылок и подпись внизу. --}}
<div class="bg-dark-subtle text-white mt-5" data-bs-theme="dark">
    <div class="container py-5">
        <footer class="row py-md-5 g-4 justify-content-between navbar-dark">

            <div class="col-12 col-md-4">
                <a href="{{ site.frame.home }}" class="d-inline-flex align-items-center gap-2 link-body-emphasis text-decoration-none mb-3">
                    @include('partials.icon', { icon = 'logo', size = '1.75em', class = 'text-primary' })
                    <span class="fs-5 fw-bold">{{ site.frame.brand }}</span>
                </a>

                @if (site.frame.description)
                <p class="small text-muted mb-2">{{ site.frame.description }}</p>
                @endif

                {{-- Абзац собран разметкой при заведении раздела и выводится
                     сырым: `tnt-markdown` экранирует всё, что в нём написано. --}}
                @if (site.frame.note)
                <div class="small text-muted site-footer-note">{!! site.frame.note !!}</div>
                @endif
            </div>

            @for (_, column in ipairs(site.frame.columns))
            <div class="col-6 col-md-auto">
                <p class="fw-normal text-white">{{ column.title }}</p>

                <div class="navbar navbar-dark">
                    <ul class="nav flex-column navbar-nav">
                        @for (_, link in ipairs(column.links))
                        <li class="nav-item mb-2">
                            <a href="{{ link.href }}" class="nav-link p-0"@if (link.external) target="_blank" rel="noopener"@endif>{{ link.title }}</a>
                        </li>
                        @endfor
                    </ul>
                </div>
            </div>
            @endfor

            <div class="col-12 col-md-auto">
                <p class="fw-normal text-white">Тема оформления</p>

                {{-- Три положения: светлая, тёмная, как в системе. Выбор
                     помнится в localStorage; `data-turbo-permanent`
                     оставляет форму на месте при переходах Turbo, чтобы
                     отметка не прыгала на каждой странице. --}}
                <form class="btn-group"
                      role="group"
                      id="theme-switch"
                      aria-label="Тема оформления"
                      data-controller="theme"
                      data-action="change->theme#choose"
                      data-turbo-permanent>
                    <input type="radio"
                           value="auto"
                           class="btn-check"
                           name="theme-switch"
                           id="theme-switch-auto"
                           autocomplete="off"
                           data-theme-target="preferred"
                           checked>
                    <label class="btn btn-outline-secondary d-inline-flex align-items-center py-2" for="theme-switch-auto">
                        @include('partials.icon', { icon = 'theme-auto', size = '1rem', class = 'my-1' })
                        <span class="visually-hidden">Как в системе</span>
                    </label>

                    <input type="radio"
                           value="light"
                           class="btn-check"
                           name="theme-switch"
                           id="theme-switch-light"
                           autocomplete="off"
                           data-theme-target="preferred">
                    <label class="btn btn-outline-secondary d-inline-flex align-items-center py-2" for="theme-switch-light">
                        @include('partials.icon', { icon = 'theme-light', size = '1rem', class = 'my-1' })
                        <span class="visually-hidden">Светлая</span>
                    </label>

                    <input type="radio"
                           value="dark"
                           class="btn-check"
                           name="theme-switch"
                           id="theme-switch-dark"
                           autocomplete="off"
                           data-theme-target="preferred">
                    <label class="btn btn-outline-secondary d-inline-flex align-items-center py-2" for="theme-switch-dark">
                        @include('partials.icon', { icon = 'theme-dark', size = '1rem', class = 'my-1' })
                        <span class="visually-hidden">Тёмная</span>
                    </label>
                </form>
            </div>
        </footer>

        @if (site.frame.signature)
        <p class="small text-muted border-top pt-3 mb-0">{{ site.frame.signature }}</p>
        @endif
    </div>
</div>
