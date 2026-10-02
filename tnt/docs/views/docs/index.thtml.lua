{{-- Главная раздела: группы меню, в группе — карточки страниц.

     Открывается на начале раздела, когда начальной страницы (`start`)
     у раздела нет: меню слева показывает одну группу, а главная — все
     разом, с первым абзацем каждого документа.

     Карточка — ссылка целиком: по ней щёлкают в любом месте, а не только
     по заголовку. Пункт, за которым страницы ещё нет, остаётся карточкой
     с подписью «скоро» — как в меню.

     Данные: `navigation` — группы с пунктами. --}}
@extends('docs.layout')

@section('title'){{ site.title }}@endsection

@section('docs')
<h1 class="fw-bold text-body-emphasis">{{ site.title }}</h1>

<p class="lead mt-3">
    Страницы по разделам: выберите нужную или найдите её поиском.
</p>

@for (index, group in ipairs(navigation.groups))
<section class="docs-index-group" aria-labelledby="docs-index-{{ index }}">
    <h2 id="docs-index-{{ index }}">{{ group.title }}</h2>

    <ul class="docs-index-cards">
        @for (_, item in ipairs(group.entries))
        <li>
            <a href="{{ item.address }}" class="docs-index-card">
                <span class="docs-index-card-title">{{ item.title }}</span>
                @if (item.description ~= '')
                <span class="docs-index-card-note">{{ item.description }}</span>
                @endif
                @unless (item.written)
                <span class="badge rounded-pill text-bg-secondary fw-normal">скоро</span>
                @endunless
            </a>
        </li>
        @endfor
    </ul>
</section>
@endfor
@endsection
