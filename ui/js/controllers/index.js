// Реестр контроллеров Stimulus: имя в разметке (`data-controller="…"`)
// — класс контроллера.
//
// Список явный, руками: имена файлов на диске `bun build` не
// разворачивает, а явный список к тому же честнее — что попадёт
// в сценарий раздела, видно в файле, а не выводится из маски.
//
// Новый контроллер добавляется двумя строками: импорт сверху
// и запись в таблице ниже.

import DocsController from './docs_controller.js';
import DocsSearchController from './docs_search_controller.js';
import ScrollController from './scroll_controller.js';
import ThemeController from './theme_controller.js';
import ToastController from './toast_controller.js';
import ViewportEntranceToggleController from './viewport_entrance_toggle_controller.js';

export default {
    docs: DocsController,
    'docs-search': DocsSearchController,
    scroll: ScrollController,
    theme: ThemeController,
    toast: ToastController,
    'viewport-entrance-toggle': ViewportEntranceToggleController,
};
