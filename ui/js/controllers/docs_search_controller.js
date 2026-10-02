// Поиск по документации: открытие окна по ⌘K, запрос по вводу, подмена
// списка ответов.
//
// Контроллер висит на самой модалке (шаблон `docs/search`): события
// Bootstrap приходят на её элемент, а поле ввода и список ответов лежат
// внутри — значит и то, и другое видно как цели, без поиска по документу.
//
// Ответ приходит готовой разметкой, а не данными: список находок рисует
// тот же шаблон, что стоит в окне при открытии. Собирать его второй раз
// здесь значило бы держать две вёрстки одного списка — и однажды
// поправить только одну.
//
// Открывает окно Bootstrap (кнопка с `data-bs-toggle`), закрывают его
// Esc, крестик и нажатие мимо окна — тоже Bootstrap. Своего кода здесь
// ровно столько, сколько Bootstrap не делает: сочетание клавиш, фокус
// в поле, запрос после паузы и уборка за собой перед уходом со страницы.

import { Controller } from '@hotwired/stimulus';
import { Modal } from 'bootstrap';

/**
 * Сколько ждать тишины после последнего нажатия, мс.
 *
 * Запрос на каждую букву искал бы по указателю по разу на знак: слово
 * из восьми букв — восемь поисков с разбором запроса морфологией, семь
 * из которых никто не увидит. Пауза заметно короче того, как человек
 * переводит взгляд на список, поэтому ожиданием не ощущается.
 */
const TYPING_PAUSE_MS = 220;

/** Подпись сочетания на клавиатуре без клавиши ⌘. */
const SHORTCUT_FALLBACK = 'Ctrl K';

export default class extends Controller {
    static targets = ['field', 'output'];
    static values = { url: String };

    connect() {
        /** @type {number} таймер паузы после нажатия */
        this.timer = 0;

        /** @type {AbortController|null} текущий запрос, если он ещё идёт */
        this.pending = null;

        this.nameShortcut();
    }

    disconnect() {
        // Turbo оставляет страницу в памяти и подключает контроллер
        // заново на каждом переходе: неснятый таймер выстрелил бы уже
        // по чужой разметке, а неотменённый запрос дотянул бы ответ
        // до страницы, которой он не предназначен.
        window.clearTimeout(this.timer);
        this.abort();
        this.teardown();
    }

    /**
     * Действие `keydown@window`: ⌘K и Ctrl+K открывают окно поиска.
     *
     * Слушатель у окна, а не у кнопки: сочетание обязано работать
     * с любого места страницы — из текста, из меню, из оглавления.
     *
     * @param {KeyboardEvent} event нажатие
     */
    open(event) {
        if (typeof event.key !== 'string' || event.key.toLowerCase() !== 'k') {
            return;
        }

        if (!event.metaKey && !event.ctrlKey) {
            return;
        }

        // Без этого Firefox уводит фокус в свою строку поиска, а Chrome
        // на части раскладок открывает своё окно.
        event.preventDefault();

        // Уже открытому окну `show()` ничего не делает, и фокус остался
        // бы там, где был: повторное сочетание — это «искать заново»,
        // и оно обязано вернуть курсор в поле.
        if (this.element.classList.contains('show')) {
            this.opened();

            return;
        }

        Modal.getOrCreateInstance(this.element).show();
    }

    /**
     * Действие `shown.bs.modal`: фокус в поле.
     *
     * Своими руками, потому что Bootstrap ставит фокус на саму модалку,
     * а не на поле с `autofocus`. Набранное выделяется целиком: окно
     * открывают, чтобы искать заново, и первая же буква должна затирать
     * прошлый запрос, а не дописываться к нему.
     */
    opened() {
        this.fieldTarget.focus();
        this.fieldTarget.select();
    }

    /** Действие `input`: запрос после паузы в наборе. */
    search() {
        window.clearTimeout(this.timer);

        this.timer = window.setTimeout(() => this.request(), TYPING_PAUSE_MS);
    }

    /**
     * Действие `keydown` в поле: Enter открывает первый ответ.
     *
     * Набрав запрос, человек жмёт Enter — и если не открыть первое
     * найденное, окно выглядит сломанным. Мыши и стрелок это не
     * отменяет: ссылки списка обходятся табуляцией как обычно.
     *
     * @param {KeyboardEvent} event нажатие в поле
     */
    jump(event) {
        if (event.key !== 'Enter') {
            return;
        }

        event.preventDefault();

        const first = this.outputTarget.querySelector('.docs-search-result');

        if (first === null) {
            return;
        }

        // Окно закрывается до перехода: Turbo унесёт разметку вместе
        // с модалкой, и подложку под ней снимать было бы уже некому.
        this.teardown();
        first.click();
    }

    /** Спрашивает узел и подменяет список ответов присланным. */
    async request() {
        const text = this.fieldTarget.value;

        this.abort();

        const attempt = new AbortController();

        this.pending = attempt;

        try {
            const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(text)}`, {
                signal: attempt.signal,
                headers: { accept: 'text/html' },
            });

            if (!response.ok) {
                throw new Error(`поиск ответил ${response.status}`);
            }

            const markup = await response.text();

            // Пока ответ шёл, читатель мог набрать ещё: поздний ответ
            // прежнего запроса затирать новый не должен.
            if (this.pending !== attempt) {
                return;
            }

            this.outputTarget.innerHTML = markup;
        } catch (error) {
            // Прерванный запрос — не сбой, а наш же отказ от прежнего
            // ответа; про него сообщать нечего.
            if (error.name === 'AbortError') {
                return;
            }

            // Сообщение — тем же путём, каким о себе говорит остальной
            // сайт: контейнер всплывающих сообщений стоит в рамке
            // страницы и лежит выше модалки.
            window.dispatchEvent(
                new CustomEvent('toast', {
                    detail: { message: 'Поиск сейчас не отвечает — попробуйте ещё раз', level: 'warning' },
                }),
            );
        } finally {
            if (this.pending === attempt) {
                this.pending = null;
            }
        }
    }

    /** Отменяет запрос, который ещё идёт. */
    abort() {
        if (this.pending !== null) {
            this.pending.abort();
            this.pending = null;
        }
    }

    /**
     * Действие `turbo:before-cache@document`: закрыть окно без анимации.
     *
     * Turbo снимает копию страницы перед уходом и показывает её при
     * возврате назад. Открытое окно попало бы в эту копию вместе
     * с классом на `<body>`, а подложка под ним — нет: страница
     * вернулась бы затенённой и не принимающей нажатий. Анимации здесь
     * взяться неоткуда — её некому доигрывать на уходящей странице, —
     * поэтому класс перехода снимается до закрытия.
     *
     * Снимается он и с подложки. Признак её анимации Bootstrap запоминает
     * в её настройках, когда заводит окно, и класс на окне его уже
     * не меняет: подложка гасла бы с анимацией, после `dispose`, и её
     * поздний обратный вызов падал бы на снесённом окне, не вернув
     * `<body>` прокрутку. Поля публичного у неё нет; выпуск Bootstrap
     * закреплён в `bun.lock`, и сборка с другим выпуском сверяется
     * снимками раздела.
     */
    teardown() {
        const modal = Modal.getInstance(this.element);

        if (modal === null) {
            return;
        }

        this.element.classList.remove('fade');

        if (modal._backdrop?._config) {
            modal._backdrop._config.isAnimated = false;
        }

        modal.hide();
        modal.dispose();
        this.element.classList.add('fade');
    }

    /**
     * Называет сочетание клавиш так, как оно набирается на этой
     * клавиатуре: `⌘K` у Apple, `Ctrl K` у остальных.
     *
     * Подпись стоит на кнопках вне модалки, поэтому ищется по документу,
     * а не среди целей контроллера.
     */
    nameShortcut() {
        if (/Mac|iPhone|iPad/i.test(navigator.platform || navigator.userAgent)) {
            return;
        }

        for (const shortcut of document.querySelectorAll('.docs-search-shortcut')) {
            shortcut.textContent = SHORTCUT_FALLBACK;
        }
    }
}
