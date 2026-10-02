// Переключатель темы: светлая, тёмная и «как в системе».
//
// Тему держит атрибут `data-bs-theme` на <html> — это механизм самого
// Bootstrap 5.3: внутри `[data-bs-theme=dark]` пакет переопределяет
// переменные `--bs-*`, и ни одного своего правила для тёмной темы писать
// не надо.
//
// Выбор помнится в localStorage под ключом `theme`. Тот же ключ до
// отрисовки читает сценарий `theme.js` в <head>: без него страница
// успевала бы мигнуть светлой, а поправить её задним числом отсюда уже
// поздно — контроллер запускается после разбора разметки. Ключ общий
// с остальными страницами сайта: тема, выбранная на них, держится
// и в разделе документации.
//
// Контроллер висит на двух местах: на <body> — чтобы тема
// применялась на каждой странице и следовала за системной, — и на самой
// форме переключателя, чтобы ловить выбор. Радио внутри формы принадлежат
// форме: Stimulus отдаёт цель ближайшему контроллеру-предку того же имени.

import { Controller } from '@hotwired/stimulus';

/** Ключ памяти браузера; тот же читает сценарий в <head>. */
const STORAGE_KEY = 'theme';

/** Положение «как в системе». */
const AUTO = 'auto';

/** Что ставится в `data-bs-theme`, когда выбрана не системная тема. */
const DARK = 'dark';
const LIGHT = 'light';

export default class extends Controller {
    static targets = ['preferred'];

    #systemDark = window.matchMedia('(prefers-color-scheme: dark)');
    #reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

    /** Выбор человека: 'light', 'dark' или 'auto'. */
    #choice = AUTO;

    connect() {
        this.#choice = localStorage.getItem(STORAGE_KEY) ?? AUTO;
        this.#apply();

        this.#systemDark.addEventListener('change', this.#onSystemChange);
    }

    disconnect() {
        this.#systemDark.removeEventListener('change', this.#onSystemChange);
    }

    /** Действие переключателя: `change->theme#choose`. */
    choose() {
        const selected = this.preferredTargets.find((input) => input.checked);

        // Событие без отмеченного положения — не выбор: снятие отметки
        // радио браузер шлёт тем же `change`.
        if (selected === undefined) {
            return;
        }

        this.#choice = selected.value;
        localStorage.setItem(STORAGE_KEY, this.#choice);

        this.#apply();
    }

    /** Ставит видимую тему на <html> и отмечает нужное положение. */
    #apply() {
        const root = document.documentElement;
        const effective = this.#effective();

        const update = () => {
            root.setAttribute('data-bs-theme', effective);
            this.#syncInputs();
        };

        // Плавный переход — только когда видимая тема правда меняется
        // и человек не просил убрать анимации; `startViewTransition` есть
        // не во всех браузерах, поэтому проверяется и он.
        const changed = root.getAttribute('data-bs-theme') !== effective;

        if (changed && !this.#reducedMotion.matches && document.startViewTransition) {
            document.startViewTransition(update);
        } else {
            update();
        }
    }

    /** Какая тема видна сейчас: «как в системе» разворачивается в свою. */
    #effective() {
        if (this.#choice === AUTO) {
            return this.#systemDark.matches ? DARK : LIGHT;
        }

        return this.#choice;
    }

    #syncInputs() {
        // Отмечается выбор человека, а не видимая тема: «как в системе»
        // и «тёмная» рисуют одно и то же, но помнятся по-разному.
        for (const input of this.preferredTargets) {
            input.checked = input.value === this.#choice;
        }
    }

    #onSystemChange = () => {
        if (this.#choice === AUTO) {
            this.#apply();
        }
    };
}
