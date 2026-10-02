{{-- Значок по имени.

         @include('partials.icon', { icon = 'menu', class = 'me-2' })

     Поля: `icon` — какой (имена — `tnt.docs.frame`, `ICONS`), `class` —
     классы обёртки, `size` — ширина и высота (по умолчанию 1em, то есть
     по размеру шрифта рядом).

     Рисунки нарочно простые и штриховые; цвет берётся от текста
     (`currentColor`), так что значок слушается `text-primary` и темы. --}}
<svg class="{{ class or '' }}"
     width="{{ size or '1em' }}"
     height="{{ size or '1em' }}"
     viewBox="0 0 24 24"
     fill="none"
     stroke="currentColor"
     stroke-width="1.8"
     stroke-linecap="round"
     stroke-linejoin="round"
     aria-hidden="true"
     focusable="false">
@if (icon == 'logo')
    <rect x="2.5" y="2.5" width="19" height="19" rx="5"></rect>
    <path d="M8 9h8M12 9v7"></path>
@elseif (icon == 'menu')
    <path d="M4 7h16M4 12h16M4 17h16"></path>
@elseif (icon == 'book')
    <path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2V5Z"></path>
    <path d="M8 8h7M8 11.5h5"></path>
@elseif (icon == 'box')
    <path d="m12 3 8 4v10l-8 4-8-4V7l8-4Z"></path>
    <path d="m4 7 8 4 8-4M12 11v10"></path>
@elseif (icon == 'code')
    <path d="m9 8-4 4 4 4M15 8l4 4-4 4"></path>
@elseif (icon == 'search')
    <circle cx="11" cy="11" r="6"></circle>
    <path d="m15.5 15.5 4 4"></path>
@elseif (icon == 'route')
    <circle cx="6" cy="6" r="2.5"></circle>
    <circle cx="18" cy="18" r="2.5"></circle>
    <path d="M8.5 6H15a3 3 0 0 1 0 6H9a3 3 0 0 0 0 6h6.5"></path>
@elseif (icon == 'database')
    <ellipse cx="12" cy="6" rx="8" ry="3"></ellipse>
    <path d="M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6"></path>
    <path d="M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"></path>
@elseif (icon == 'bolt')
    <path d="M13 3 5 14h6l-1 7 8-11h-6l1-7Z"></path>
@elseif (icon == 'terminal')
    <rect x="3" y="4" width="18" height="16" rx="2.5"></rect>
    <path d="m7 10 2.5 2.5L7 15M13 15h4"></path>
@elseif (icon == 'mail')
    <rect x="3" y="5" width="18" height="14" rx="2.5"></rect>
    <path d="m4.5 7.5 7.5 5.5 7.5-5.5"></path>
@elseif (icon == 'clock')
    <circle cx="12" cy="12" r="9"></circle>
    <path d="M12 7.5V12l3.5 2"></path>
@elseif (icon == 'shield-check')
    <path d="m12 3 7 2.5V12c0 4.2-2.8 7.4-7 9-4.2-1.6-7-4.8-7-9V5.5L12 3Z"></path>
    <path d="m9 12 2.2 2.2L15.5 10"></path>
@elseif (icon == 'arrow-right')
    <path d="M5 12h13M13 6l6 6-6 6"></path>
@elseif (icon == 'angle-up')
    <path d="m6 14 6-6 6 6"></path>
@elseif (icon == 'circle-fill')
    <circle cx="12" cy="12" r="7" fill="currentColor" stroke="none"></circle>
@elseif (icon == 'theme-light')
    <circle cx="12" cy="12" r="4.2"></circle>
    <path d="M12 2.5v2M12 19.5v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2.5 12h2M19.5 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"></path>
@elseif (icon == 'theme-dark')
    <path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5Z"></path>
@elseif (icon == 'theme-auto')
    <circle cx="12" cy="12" r="9"></circle>
    <path d="M12 3a9 9 0 0 0 0 18Z" fill="currentColor" stroke="none"></path>
@endif
</svg>
