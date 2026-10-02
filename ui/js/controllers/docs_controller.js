// Раздел документации: меню-гармошка, оглавление и блоки кода.
//
// Контроллер один на весь раздел (`data-controller="docs"` стоит
// на контейнере страницы), потому что все четыре его дела — про одну
// страницу целиком: меню в левой колонке, оглавление в правой и в липком
// `<details>` посередине, подсветка и кнопки копирования в тексте.
// Три контроллера на трёх колонках пришлось бы связывать событиями ради
// одной строки «какой раздел читают сейчас».
//
// Подсветка кода здесь одна и клиентская. Второй, серверной, нет
// нарочно: две системы подсветки на одну страницу — это два набора
// классов и два места, где правится цвет ключевого слова, а расходятся
// они молча.
//
// Блоки кода собираются на клиенте по той же причине, по какой их не
// собирает разбор разметки: полоска с подписью и кнопка — это
// оформление, а разбор markdown отдаёт `<pre><code>` и не обязан знать
// ни про кнопки, ни про буфер обмена.

import { Controller } from '@hotwired/stimulus';
import Prism from 'prismjs/components/prism-core.js';

// Языки перечислены поимённо, а не взяты «все»: полный набор Prism —
// под три сотни грамматик, и они утроили бы бандл ради языков, которых
// в документации нет. Здесь ровно те, которыми написаны ограды кода
// в документах. Псевдонимы грамматики заводят сами: `markup` отвечает
// за `html`, `bash` — за `sh` и `shell`, `javascript` — за `js`.
import 'prismjs/components/prism-markup.js';
import 'prismjs/components/prism-css.js';
// `clike` — не язык документации, а основа, которую расширяет
// `javascript`: без неё грамматика JS падает при загрузке.
import 'prismjs/components/prism-clike.js';
import 'prismjs/components/prism-javascript.js';
import 'prismjs/components/prism-bash.js';
import 'prismjs/components/prism-json.js';
import 'prismjs/components/prism-yaml.js';
import 'prismjs/components/prism-sql.js';
import 'prismjs/components/prism-lua.js';
import 'prismjs/components/prism-diff.js';
import 'prismjs/components/prism-ini.js';
import 'prismjs/components/prism-toml.js';
import 'prismjs/components/prism-http.js';
import 'prismjs/components/prism-nginx.js';
import 'prismjs/components/prism-makefile.js';

// Ограды пишут `make`, а грамматика зовётся `makefile` и такого
// псевдонима себе не заводит.
Prism.languages.make = Prism.languages.makefile;

// Подсветку зовёт контроллер, а не сам Prism. Своя автоподсветка у него
// висит на `DOMContentLoaded` и на первом кадре — то есть срабатывает
// один раз за загрузку документа, а Turbo меняет страницы без
// перезагрузки, и второй документ остался бы неподсвеченным.
Prism.manual = true;

/**
 * Подпись над блоком кода по языку ограды.
 *
 * Словами, а не именем языка как есть: `sh` и `console` читателю ничего
 * не говорят, а «Командная строка» и «Вывод команды» говорят, что перед
 * ним — то, что набирают, или то, что печатается в ответ.
 */
const CODE_LABELS = {
    lua: 'Lua',
    bash: 'Командная строка',
    sh: 'Командная строка',
    shell: 'Командная строка',
    console: 'Вывод команды',
    yaml: 'YAML',
    json: 'JSON',
    sql: 'SQL',
    javascript: 'JavaScript',
    js: 'JavaScript',
    css: 'CSS',
    scss: 'SCSS',
    html: 'HTML',
    markup: 'HTML',
    make: 'Makefile',
    nginx: 'nginx',
    diff: 'Изменения',
    text: 'Текст',
};

/** Подпись ограды, язык которой не назван либо незнаком. */
const CODE_LABEL_DEFAULT = 'Фрагмент кода';

/** Сколько кнопка держит отметку «скопировано», мс. */
const COPIED_MS = 1600;

/**
 * «Линия чтения»: раздел считается текущим, когда его заголовок ушёл
 * выше этой отметки от верха окна.
 *
 * Не ноль и не середина экрана: у верхнего края отметка перескакивала бы
 * на следующий раздел, едва его заголовок показался, а у середины —
 * держалась бы на предыдущем, когда его текст уже дочитан. Доля от
 * высоты окна с пределом: на телефоне четверть экрана — это полторы
 * строки, а на большом мониторе — половина абзаца.
 */
const READING_LINE_MAX = 180;
const READING_LINE_SHARE = 0.25;

/**
 * Имя языка ограды кода: `<code class="language-lua">` → `lua`.
 *
 * @param {HTMLElement} code содержимое ограды
 * @returns {string|null} имя языка либо ничего, если класса нет
 */
function languageOf(code) {
    const named = /(?:^|\s)language-([\w-]+)/.exec(code.className);

    return named === null ? null : named[1];
}

/**
 * Кладёт текст в буфер обмена.
 *
 * Запасной путь через `execCommand` — не дань прошлому: `navigator.clipboard`
 * есть только в защищённом окружении (https либо localhost), и на стенде,
 * открытом по http с соседней машины, кнопка без него молча ничего
 * не делала бы.
 *
 * @param {string} text что копировать
 * @returns {Promise<boolean>} удалось ли
 */
async function copyText(text) {
    if (navigator.clipboard !== undefined) {
        try {
            await navigator.clipboard.writeText(text);

            return true;
        } catch {
            // Отказ буфера обмена — не поломка: страница могла быть
            // открыта по http либо в фоновой вкладке, у которой нет
            // разрешения. Ниже запасной путь.
        }
    }

    const carrier = document.createElement('textarea');

    // Поле вне экрана, но не `display: none`: невидимое поле нельзя
    // выделить, а без выделения копировать нечего.
    carrier.value = text;
    carrier.setAttribute('readonly', '');
    carrier.style.cssText = 'position: fixed; top: -1000px; opacity: 0';

    document.body.append(carrier);
    carrier.select();

    const copied = document.execCommand('copy');

    carrier.remove();

    return copied;
}

export default class extends Controller {
    static targets = ['currentSection'];

    connect() {
        this.highlightCode();
        this.setupCodeBlocks();
        this.setupTableOfContents();
    }

    disconnect() {
        // Слушатели снимаются обязательно: Turbo оставляет страницу
        // в памяти и подключает контроллер заново на каждом переходе,
        // а неснятые слушатели копились бы по одному на переход — и все
        // они держали бы старую разметку, не давая её убрать.
        if (this.updateActiveSection === undefined) {
            return;
        }

        window.removeEventListener('scroll', this.updateActiveSection);
        window.removeEventListener('resize', this.updateActiveSection);

        this.updateActiveSection = undefined;
    }

    /**
     * Действие `click->docs#toggleSection`: раскрыть раздел меню
     * и свернуть остальные.
     *
     * Открыт всегда один раздел: колонка из восьми десятков пунктов
     * иначе не помещалась бы на экран, и до соседнего раздела
     * приходилось бы прокручивать её целиком.
     *
     * @param {PointerEvent} event нажатие на кнопку раздела
     */
    toggleSection(event) {
        const button = event.currentTarget;
        const expand = button.getAttribute('aria-expanded') !== 'true';

        if (expand) {
            for (const opened of this.element.querySelectorAll('.docs-menu-section[aria-expanded="true"]')) {
                if (opened !== button) {
                    this.setSectionState(opened, false);
                }
            }
        }

        this.setSectionState(button, expand);
    }

    /**
     * Ставит разделу меню состояние: кнопке — `aria-expanded`, панели —
     * `data-expanded` (по нему раскрывается грид), `aria-hidden` и `inert`.
     *
     * `inert` здесь не украшение: панель свёрнута прозрачностью и нулевой
     * высотой, но без него она осталась бы в обходе табуляцией, и
     * клавиатура уходила бы в невидимые ссылки.
     *
     * @param {HTMLElement} button кнопка раздела
     * @param {boolean} expanded раскрыт ли раздел
     */
    setSectionState(button, expanded) {
        const panel = document.getElementById(button.getAttribute('aria-controls'));

        if (panel === null) {
            return;
        }

        button.setAttribute('aria-expanded', String(expanded));
        panel.dataset.expanded = String(expanded);
        panel.setAttribute('aria-hidden', String(!expanded));
        panel.inert = !expanded;
    }

    /** Подсвечивает ограды кода, язык которых Prism знает. */
    highlightCode() {
        for (const code of this.element.querySelectorAll('.docs-content pre > code')) {
            const language = languageOf(code);

            // Незнакомый язык (`console`, `diff`) пропускается, а не
            // отдаётся Prism «на всякий случай»: без грамматики он
            // переписал бы содержимое тем же текстом — работа впустую
            // на каждой ограде каждой страницы.
            if (language === null || Prism.languages[language] === undefined) {
                continue;
            }

            Prism.highlightElement(code);
        }
    }

    /** Оборачивает каждую ограду кода в блок с полоской и кнопкой. */
    setupCodeBlocks() {
        for (const pre of this.element.querySelectorAll('.docs-content pre')) {
            // Уже обёрнутое пропускается: Turbo умеет вернуть страницу
            // из памяти вместе с тем, что мы к ней дописали, и вторая
            // обёртка дала бы вторую полоску.
            if (pre.closest('.docs-code-block') !== null) {
                continue;
            }

            const code = pre.querySelector('code');

            if (code === null) {
                continue;
            }

            const block = document.createElement('div');

            block.className = 'docs-code-block';

            pre.before(block);
            block.append(pre);
            block.prepend(this.codeToolbar(code));
        }
    }

    /**
     * Полоска над оградой: подпись слева, кнопка «скопировать» справа.
     *
     * @param {HTMLElement} code содержимое ограды
     * @returns {HTMLElement} полоска
     */
    codeToolbar(code) {
        const toolbar = document.createElement('div');
        const label = document.createElement('span');

        toolbar.className = 'docs-code-toolbar';
        label.textContent = CODE_LABELS[languageOf(code)] ?? CODE_LABEL_DEFAULT;

        toolbar.append(label, this.copyButton(code));

        return toolbar;
    }

    /**
     * Кнопка «скопировать» для одной ограды.
     *
     * @param {HTMLElement} code содержимое ограды
     * @returns {HTMLElement} кнопка
     */
    copyButton(code) {
        const button = document.createElement('button');
        const icon = document.createElement('span');

        button.type = 'button';
        button.className = 'docs-code-copy';
        icon.className = 'docs-code-copy-icon';
        icon.setAttribute('aria-hidden', 'true');
        button.append(icon);

        this.setCopyLabel(button, 'Скопировать код');

        // Таймер держится замыканием кнопки: два быстрых нажатия иначе
        // завели бы два таймера, и первый снял бы отметку со второго
        // копирования раньше срока.
        let reset = 0;

        button.addEventListener('click', async () => {
            // `textContent`, а не разметка: подсветка Prism разложила
            // код по тегам, и копировать надо то, что видит человек,
            // а не `<span class="token">` вокруг каждого слова.
            const copied = await copyText(code.textContent);

            if (!copied) {
                this.setCopyLabel(button, 'Не удалось скопировать код');

                return;
            }

            button.dataset.copied = 'true';
            this.setCopyLabel(button, 'Код скопирован');

            window.clearTimeout(reset);

            reset = window.setTimeout(() => {
                button.dataset.copied = 'false';
                this.setCopyLabel(button, 'Скопировать код');
            }, COPIED_MS);
        });

        return button;
    }

    /**
     * Подпись кнопки копирования: для чтеца и для подсказки мышью сразу.
     *
     * Своего текста у кнопки нет — в ней один значок, — поэтому без
     * `aria-label` чтец прочёл бы её как «кнопка» и ничего больше.
     *
     * @param {HTMLElement} button кнопка
     * @param {string} label что она сейчас значит
     */
    setCopyLabel(button, label) {
        button.setAttribute('aria-label', label);
        button.title = label;
    }

    /** Подсвечивает в оглавлении тот раздел, который читают сейчас. */
    setupTableOfContents() {
        const headings = Array.from(this.element.querySelectorAll('.docs-content h2[id], .docs-content h3[id]'));

        if (headings.length === 0) {
            return;
        }

        // Ссылок оглавления на странице два набора: колонка справа
        // и липкий `<details>` посередине. Отмечаются оба — на широком
        // экране виден первый, на узком второй, и кто из них сейчас
        // на экране, решает таблица стилей.
        const links = Array.from(this.element.querySelectorAll('.anchors a'));

        this.updateActiveSection = () => {
            const readingLine = Math.min(READING_LINE_MAX, window.innerHeight * READING_LINE_SHARE);

            // Текущий — последний заголовок, ушедший выше линии чтения;
            // пока не ушёл ни один, текущим считается первый: в начале
            // страницы читатель всё равно находится в первом разделе.
            const active = headings.reduce(
                (found, heading) => (heading.getBoundingClientRect().top <= readingLine ? heading : found),
                headings[0],
            );

            for (const link of links) {
                // Сравнивается атрибут, а не `link.hash`: якоря русские
                // (`#как-пользоваться`), и `hash` отдаёт их
                // percent-кодированными — совпасть с `id` заголовка
                // такая строка не может.
                if (link.getAttribute('href') === `#${active.id}`) {
                    link.setAttribute('aria-current', 'location');
                } else {
                    link.removeAttribute('aria-current');
                }
            }

            for (const target of this.currentSectionTargets) {
                target.textContent = active.textContent.trim();
            }
        };

        window.addEventListener('scroll', this.updateActiveSection, { passive: true });
        window.addEventListener('resize', this.updateActiveSection);

        this.updateActiveSection();
    }
}
