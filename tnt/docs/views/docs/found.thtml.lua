{{-- Страница выдачи поиска: `?q=…` на начале раздела.

     Рисуется на узле и работает без сценариев: это и ссылка, которой
     делятся, и поиск там, где окно ⌘K не откроется. Поле — того же вида,
     что в окне, а список — тот же кусок `docs.search-results`, только
     без своей прокрутки.

     Данные: `results` — выдача (`items`, `total`, `partial`), `query` —
     запрос. --}}
@extends('docs.layout')

@section('title')Поиск: {{ query }}@endsection

@section('docs')
<h1 class="fw-bold text-body-emphasis mb-4">Поиск</h1>

<div class="docs-found">
    <form action="{{ site.home }}" method="get" role="search">
        <label for="docs-found-input" class="visually-hidden">Что искать</label>

        <div class="docs-search-field docs-found-field">
            @include('partials.icon', { icon = 'search' })

            <input class="form-control"
                   id="docs-found-input"
                   name="q"
                   type="search"
                   value="{{ query }}"
                   autocomplete="off"
                   maxlength="{{ site.query_length }}">

            <button class="btn btn-primary btn-sm" type="submit">Найти</button>
        </div>
    </form>

    @if (results.total > 0)
    <p class="docs-found-total">
        Нашлось разделов: {{ results.total }}@if (results.total > #results.items), показаны первые {{ #results.items }}@endif.
    </p>
    @endif

    @include('docs.search-results', { asked = true })
</div>
@endsection
