{{-- Рамка сайта: шапка, содержимое страницы, подвал.

     Документ целиком описан в `html`; рамка наследует его и наполняет
     кусок `body`: шапка, содержимое страницы, подвал, кнопка «Наверх»
     и всплывающие сообщения. Страницы наследуют рамку и дают только
     кусок `content`.

     Сообщения — последними: контейнер у них с `position: fixed`,
     и в разметке ему место после того, что он перекрывает. --}}
@extends('html')

@section('body')
@include('partials.navbar')

<main id="content">
@yield('content')
</main>

@include('partials.footer')
@include('partials.back-to-top')
@include('partials.toast')
@endsection
