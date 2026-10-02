{{-- Сводная страница плана: весь план раздела одной таблицей.

     Таблица собирается из того же меню, что стоит слева, и из плана
     страниц, — и потому сходится с меню пункт в пункт. Писать её руками
     значило бы завести второй план, который разойдётся с первым
     на первой же закрытой задаче.

     Данные: `items` — пункты меню со своим планом и все ненаписанные
     (`navigation.planned`), `written` — сколько из них уже написано,
     `entry` — пункт самой сводной страницы. --}}
@extends('docs.layout')

@section('title'){{ entry.title }}@endsection
@section('description', 'План раздела документации: какие страницы уже написаны, каких возможностей в наборе пока нет и какой задачей закрывается каждая из них.')

@section('docs')
<h1 class="fw-bold text-body-emphasis mb-3">{{ entry.title }}</h1>

<p class="lead">
    Раздел документации показывает весь план: и написанное, и то, что появится.
    Состояние в таблице — про готовность самой возможности в наборе, а подпись
    «скоро» — про то, что страница о ней ещё не написана.
</p>

<ul>
    <li><strong>есть</strong> — возможность готова и проверена применением;</li>
    <li><strong>частично</strong> — возможность есть не целиком, чего не хватает — сказано в столбце справа;</li>
    <li><strong>позже</strong> — возможности в наборе пока нет.</li>
</ul>

<p>
    Всего страниц в своде — {{ #items }}; написано — {{ written }}; впереди — {{ #items - written }}.
</p>

<table>
    <thead>
        <tr>
            <th>Раздел</th>
            <th>Страница</th>
            <th>Состояние</th>
            <th>Чем закрывается</th>
        </tr>
    </thead>
    <tbody>
        @for (_, item in ipairs(items))
        <tr>
            <td>{{ item.group }}</td>
            <td>
                <a href="{{ item.address }}">{{ item.title }}</a>
                @unless (item.written)
                <span class="badge rounded-pill text-bg-secondary fw-normal align-text-bottom">скоро</span>
                @endunless
            </td>
            <td>{{ item.state_title }}</td>
            <td>
                @if (item.note ~= nil){{ item.note }}@endif@if (item.note ~= nil and item.tasks[1] ~= nil) — @endif@for (index, task in ipairs(item.tasks))<code>{{ task }}</code>@if (index < #item.tasks), @endif@endfor
            </td>
        </tr>
        @endfor
    </tbody>
</table>
@endsection
