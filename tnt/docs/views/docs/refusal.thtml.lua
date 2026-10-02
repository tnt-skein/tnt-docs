{{-- Отказ — страницей на рамке раздела.

     Голый отказ роутера здесь не годится. Читатель пришёл по ссылке —
     из поисковика, из чужого документа, из закладки, — и строка про код
     ответа ему ничего не даёт. Страница на той же рамке оставляет рядом
     колонку меню: с неё видно, что раздел на месте, и можно уйти туда,
     куда читатель и шёл.

     От заглушки «скоро» 404 отличается смыслом: там страница будет,
     а здесь такого адреса не бывает. Остальные отказы — слово роутера
     и номер происшествия, по которому запись находят в журнале узла;
     подробности в страницу не идут — их читает дежурный в журнале.

     Данные: `failure` — отказ (`status`, `message`, `incident`), `path` —
     путь запроса, `navigation.plan` — сводная страница, если она есть. --}}
@extends('docs.layout')

@section('title'){{ failure.status == 404 and 'Страница не найдена' or failure.message }}@endsection
@section('description', 'В разделе документации нет страницы с таким адресом.')

@section('docs')
<p class="text-primary text-uppercase fw-semibold ls-xl small mb-2">{{ site.title }}</p>

@if (failure.status == 404)
<h1 class="fw-bold text-body-emphasis mb-3">Такой страницы нет</h1>

<p class="lead">
    В разделе документации нет страницы <code>{{ path }}</code>. Возможно,
    её переименовали или ссылка набрана с опечаткой.
</p>

<p class="mb-0">
    Оглавление раздела — в колонке слева; начать заново можно
    с <a href="{{ site.start or site.home }}" class="link-body-emphasis">начала раздела</a>@if (navigation.plan), а весь план раздела с отметками о готовности лежит
    на странице <a href="{{ navigation.plan.address }}" class="link-body-emphasis">{{ navigation.plan.title }}</a>@endif.
</p>
@else
<h1 class="fw-bold text-body-emphasis mb-3">{{ failure.message }}</h1>

<p class="lead">
    Раздел не смог ответить на этот запрос (код {{ failure.status }}).
</p>

@if (failure.incident)
<p class="mb-0">Происшествие <code>{{ failure.incident }}</code> — по этому номеру причину найдут в журнале узла.</p>
@endif
@endif
@endsection
