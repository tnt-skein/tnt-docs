// Плавная прокрутка по нажатию: `click->scroll#go`.
//
// Без `data-scroll-to-value` прокручивает страницу наверх — это кнопка
// «Наверх» в подвале; с ним — к названному узлу (`#anchor`), как ссылка
// на раздел, но без прыжка и без записи в историю браузера.

import { Controller } from '@hotwired/stimulus';

/**
 * Узел, к которому прокручивать.
 *
 * `#имя` ищется по `id`, а не селектором: якоря страниц документации
 * собраны из заголовков (`#1-три-оговорки`), а селектор, начинающийся
 * с цифры, для CSS негоден — `querySelector` на нём падает, и вместе
 * с ним падает обработчик нажатия.
 *
 * @param {string} selector значение `data-scroll-to-value`
 * @returns {Element|null} узел либо ничего
 */
function targetOf(selector) {
    if (selector.startsWith('#')) {
        return document.getElementById(selector.slice(1));
    }

    return document.querySelector(selector);
}

export default class extends Controller {
    static values = { to: String };

    /** @param {Event} event нажатие; переход по ссылке отменяется */
    go(event) {
        event.preventDefault();

        const target = this.hasToValue ? targetOf(this.toValue) : null;

        if (target !== null) {
            target.scrollIntoView({ behavior: 'smooth' });

            return;
        }

        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}
