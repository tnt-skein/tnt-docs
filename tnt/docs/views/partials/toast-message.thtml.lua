{{-- Одно всплывающее сообщение: кусок для partials/toast.

     Отдельным файлом, а не двумя копиями разметки внутри контейнера:
     один и тот же вид нужен и сообщению, пришедшему со страницей,
     и заготовке в <template>, по которой контроллер `toast` собирает
     сообщение, пришедшее сценарием.

     Данные: `toast.message` — текст, `toast.level` — имя цвета Bootstrap
     (`success`, `danger`, `warning`, `info`, `primary`, `secondary`).
     Без уровня значок рисуется цветом текста: уровень — акцент,
     а смысл несёт само сообщение.

     Текст уходит через {{ }} и экранируется: в сообщение легко попадает
     то, что ввёл человек.

     Метки `data-toast-message` и `data-toast-level` — места, которые
     заполняет контроллер в клоне заготовки. Целями Stimulus они не
     сделаны нарочно: цели собираются со всех сообщений сразу, а заполнять
     надо одно, своё.

     `role="alert"` и `aria-live="assertive"` велят читалке прочесть
     сообщение сразу, `aria-atomic` — прочесть целиком.

     `data-turbo-temporary`: Turbo держит снимок страницы и показывает
     его при возврате назад, а сообщение о разовом действии в снимке
     всплыло бы второй раз.

     До сценария сообщение не видно: `.toast` без класса `show` Bootstrap
     прячет (`display: none`), а показывает его контроллер `toast`. --}}
<div class="toast border-0 rounded shadow-sm bg-body-tertiary"
     role="alert"
     aria-live="assertive"
     aria-atomic="true"
     data-toast-target="toast"
     data-bs-autohide="true"
     data-bs-delay="5000"
     data-turbo-temporary>
    <div class="toast-body d-flex align-items-start p-3">
        <span class="d-inline-flex flex-shrink-0 mt-1 me-2 {{ toast.level and ('text-' .. toast.level) or '' }}"
              data-toast-level>
            @include('partials.icon', { icon = 'circle-fill', size = '0.75em' })
        </span>

        <p class="mb-0 me-2" data-toast-message>{{ toast.message }}</p>

        <button type="button"
                class="btn-close flex-shrink-0 ms-auto"
                data-bs-dismiss="toast"
                aria-label="Закрыть сообщение"></button>
    </div>
</div>
