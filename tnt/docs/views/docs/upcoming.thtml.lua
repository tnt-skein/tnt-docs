{{-- Заглушка страницы, которой ещё нет.

     Открытие такой страницы даёт не 404, а рассказ о том, что здесь
     будет: 404 сказал бы «такого раздела не бывает», а раздел будет —
     просто позже. Слова берутся из плана страниц (`plan.pages` настроек
     раздела), а не пишутся здесь: заглушка одна на все ненаписанные
     страницы.

     Первая фраза одна и та же у всех заглушек нарочно: читатель узнаёт
     её с первого взгляда и не перечитывает абзац, чтобы понять,
     дочитался он до сути или нет.

     Данные: `entry` — пункт меню с состоянием и планом (`about`,
     `missing`, `tasks`, `note`),
     `navigation.plan` — сводная страница, если она есть. --}}
@extends('docs.layout')

@section('title'){{ entry.title }}@endsection
@section('description'){{ 'Раздел «' .. entry.title .. '» документации ' .. site.frame.brand .. ' ещё не написан: что в нём будет и чего для этого не хватает.' }}@endsection

@section('docs')
<p class="text-primary text-uppercase fw-semibold ls-xl small mb-2">{{ entry.group }}</p>

<h1 class="fw-bold text-body-emphasis mb-2">{{ entry.title }}</h1>

<p class="text-body-secondary mb-4">
    Состояние возможности по плану раздела — <strong>{{ entry.state_title }}</strong>.
</p>

{{-- Черта слева вместо рамки: врезка должна читаться как замечание
     на полях, а не как отдельная карточка поверх страницы. --}}
<div class="border-start border-primary border-3 bg-body-secondary rounded-end p-4">
    <p class="mb-0">
        <strong>Раздел скоро появится.</strong>
        @if (entry.about)Здесь будет рассказано про {{ entry.about }}.@endif
        @if (entry.state == 'later')Сейчас этой возможности в наборе нет@if (entry.missing): {{ entry.missing }}@endif.@elseif (entry.state == 'partial')Возможность в наборе есть, но не целиком@if (entry.missing): {{ entry.missing }}@endif.@else Возможность в наборе есть и проверена применением — нет пока самой страницы.@endif
        {{-- Там, где возможность уже готова, задача названа иначе: она не
             «на разработку», а та, которой план закрывает саму страницу. --}}
        @if (entry.tasks[1])
        @if (entry.state == 'ready'){{ #entry.tasks > 1 and 'По плану раздела её закрывают задачи' or 'По плану раздела её закрывает задача' }}@else{{ #entry.tasks > 1 and 'Задачи на разработку —' or 'Задача на разработку —' }}@endif @for (index, task in ipairs(entry.tasks))<code>{{ task }}</code>{{ index < #entry.tasks and ', ' or '.' }}@endfor
        @else
        Задачи на разработку у раздела нет; чем закрывается — {{ entry.note or 'план раздела' }}.
        @endif
    </p>
</div>

@if (navigation.plan)
<p class="mt-4 mb-0">
    Весь план раздела — на странице
    <a href="{{ navigation.plan.address }}" class="link-body-emphasis">{{ navigation.plan.title }}</a>:
    там видно, какие страницы уже написаны, а какие ждут своей задачи.
</p>
@endif
@endsection
