// Всплывающие сообщения: показать пришедшее со страницей и собрать новое.
//
// Разметку даёт кусок `partials/toast` пакета: контейнер
// с образцом сообщения в <template> и сообщениями, которые положил
// в страницу обработчик. Сам вид — Bootstrap (`.toast`), поэтому без
// сценария сообщение скрыто: `.toast` без класса `show` Bootstrap прячет.
//
// Показ висит на подключении цели, а не на `connect`, и это главное
// решение файла: так одинаково показываются и сообщения, приехавшие
// со страницей, и добавленные потом — этим контроллером или подменой
// разметки у Turbo. С показом в `connect` второе сообщение на уже
// подключённом контейнере осталось бы невидимым.

import { Controller } from '@hotwired/stimulus';
import { Toast } from 'bootstrap';

/**
 * Уровни сообщения — имена цветов Bootstrap.
 *
 * Список закрытый: уровень попадает в имя класса, и слово со стороны
 * там быть не должно. Незнакомое — не ошибка: сообщение покажется
 * цветом текста, как и сообщение без уровня.
 */
const LEVELS = ['primary', 'secondary', 'success', 'danger', 'warning', 'info'];

export default class extends Controller {
    static targets = ['toast', 'template'];

    /**
     * Показывает сообщение, как только оно оказалось в контейнере.
     *
     * @param {HTMLElement} element сообщение целиком (`.toast`)
     */
    toastTargetConnected(element) {
        // Показанное сообщение убирается из разметки: иначе контейнер
        // копил бы за визит десятки невидимых узлов, а Turbo уносил бы
        // их в снимок страницы.
        element.addEventListener('hidden.bs.toast', () => element.remove(), { once: true });

        Toast.getOrCreateInstance(element).show();
    }

    /**
     * Отпускает сообщение, ушедшее из разметки.
     *
     * Без этого таймер автоскрытия досчитал бы до конца уже на
     * оторванном узле и держал бы его в памяти до конца визита.
     *
     * @param {HTMLElement} element сообщение целиком (`.toast`)
     */
    toastTargetDisconnected(element) {
        Toast.getInstance(element)?.dispose();
    }

    /**
     * Действие `toast@window->toast#notify`: показать сообщение,
     * присланное сценарием страницы.
     *
     * @param {CustomEvent<{ message?: string, level?: string }>} event
     */
    notify(event) {
        const detail = event.detail ?? {};
        const message = typeof detail.message === 'string' ? detail.message.trim() : '';

        if (message === '') {
            // Тихо пропустить — значит спрятать опечатку в том коде,
            // который хотел что-то сказать человеку и не сказал.
            console.warn('событие toast без detail.message: показывать нечего');

            return;
        }

        this.show(message, detail.level);
    }

    /**
     * Собирает сообщение по образцу из <template> и кладёт в контейнер;
     * показывает его `toastTargetConnected`.
     *
     * @param {string} message текст сообщения
     * @param {string} [level] уровень — имя цвета Bootstrap из LEVELS
     */
    show(message, level) {
        if (!this.hasTemplateTarget) {
            console.warn('в контейнере сообщений нет образца: partials/toast без <template>');

            return;
        }

        const element = this.templateTarget.content.querySelector('.toast')?.cloneNode(true);
        const body = element?.querySelector('[data-toast-message]');
        const icon = element?.querySelector('[data-toast-level]');

        if (!body || !icon) {
            console.warn('образец сообщения не тот: нужны .toast, [data-toast-message] и [data-toast-level]');

            return;
        }

        // `textContent`, а не `innerHTML`: текст сообщения приходит
        // из кода страницы и может нести имя, адрес или причину отказа,
        // введённые человеком, — разметкой они здесь не станут.
        body.textContent = message;

        if (LEVELS.includes(level)) {
            icon.classList.add(`text-${level}`);
        } else if (level) {
            console.warn(`уровень сообщения «${level}» неизвестен; знаю: ${LEVELS.join(', ')}`);
        }

        this.element.append(element);
    }
}
