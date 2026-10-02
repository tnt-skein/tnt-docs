// Класс, пока элемент виден в окне.
//
// Пока элемент попадает в окно, на нём висит класс из
// `data-viewport-entrance-toggle-class-value`; ушёл за край — класс снят.
// На этом держится кнопка «Наверх»: её обёртка высотой в экран стоит
// у начала страницы, и пока начало видно, кнопка спрятана.
//
// Наблюдатель, а не событие `scroll`: обработчик прокрутки зовётся на
// каждый кадр и на каждой странице, а IntersectionObserver будит браузер
// только на пересечении границы.

import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
    static values = { class: String };

    initialize() {
        this.observer = new IntersectionObserver((entries) => {
            for (const entry of entries) {
                this.element.classList.toggle(this.classValue, entry.isIntersecting);
            }
        });
    }

    connect() {
        this.observer.observe(this.element);
    }

    disconnect() {
        this.observer.unobserve(this.element);
    }
}
