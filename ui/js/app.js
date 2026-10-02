// Точка входа сценариев раздела: Turbo, Stimulus и поведение Bootstrap.

import * as Turbo from '@hotwired/turbo';
import { Application } from '@hotwired/stimulus';
import * as bootstrap from 'bootstrap';

import controllers from './controllers/index.js';

// Turbo запускается сам при импорте и перехватывает переходы по ссылкам.
// В `window` он кладётся, чтобы страница могла позвать `Turbo.visit(…)`,
// а разработчик — посмотреть состояние из консоли браузера.
window.Turbo = Turbo;

// Bootstrap импортируется целиком, а не ради побочного действия:
// `import 'bootstrap'` сборщик вправе выбросить как неиспользуемый,
// а так модалки и выпадающие меню заодно доступны как `bootstrap.Modal`.
window.bootstrap = bootstrap;

const application = Application.start();

for (const [name, controller] of Object.entries(controllers)) {
    application.register(name, controller);
}

window.Stimulus = application;
