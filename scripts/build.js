// Сборка вида раздела: SCSS → CSS, модули → сценарии, картинки и шрифты —
// всё в модуль Lua.
//
// Страницы здесь не собираются: их рисует узел шаблонами, и в сборку
// идёт только то, что уходит в браузер файлом, — оформление, сценарии,
// значки и шрифты. Собранное сразу пакуется в `tnt/docs/public/bundle.lua`:
// рок несёт вид с собой, узел раздаёт его из памяти процесса, и ни
// отдельного веб-сервера для статики, ни сети доставки (CDN), ни
// расхождения версий вида и узла не бывает. Метку версии в адрес файла
// ставит сам узел — по содержимому, при загрузке модуля.
//
//   bun run build    разовая сборка
//   bun run watch    пересборка при правке ui/

import { watch } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

/** Корень пакета: сценарий лежит в scripts/. */
const ROOT = join(import.meta.dir, '..');

/** Исходники вида. */
const SOURCE_DIR = join(ROOT, 'ui');

/** Зависимости сборки. */
const MODULES_DIR = join(ROOT, 'node_modules');

/** Модуль, в который пакуется собранное. */
const TARGET = join(ROOT, 'tnt', 'docs', 'public', 'bundle.lua');

/** Сколько ждать тишины после правки, мс: редактор пишет файл несколькими событиями. */
const SETTLE_MS = 100;

/**
 * Предупреждения Sass, которые чинит не пакет, а Bootstrap: 5.3 собран
 * на `@import` и встроенных функциях, и без этого списка сборка тонула бы
 * в сотнях строк о чужом коде. `import` — и о своём: переопределение
 * переменных Bootstrap работает только через `@import`.
 */
const SILENCED = ['import', 'global-builtin', 'color-functions', 'if-function'];

/**
 * Шрифты: переменные файлы по одному на алфавит, из пакетов шрифтов.
 * Имя в разделе — то, что называет `ui/styles/_fonts.scss`.
 */
const FONTS = {
    'fonts/inter-cyrillic.woff2': '@fontsource-variable/inter/files/inter-cyrillic-wght-normal.woff2',
    'fonts/inter-latin.woff2': '@fontsource-variable/inter/files/inter-latin-wght-normal.woff2',
    'fonts/raleway-cyrillic.woff2': '@fontsource-variable/raleway/files/raleway-cyrillic-wght-normal.woff2',
    'fonts/raleway-latin.woff2': '@fontsource-variable/raleway/files/raleway-latin-wght-normal.woff2',
};

/** Картинки, которые уходят байтами: растр строкой Lua не записать. */
const IMAGES = ['favicon-32x32.png', 'apple-touch-icon.png'];

/**
 * Вставка встроенного стиля полосы загрузки Turbo.
 *
 * Turbo кладёт в <head> свой `<style>` сразу при загрузке сценария,
 * а правило источников раздела (`style-src 'self'`) встроенных стилей
 * не пускает: браузер отвергал бы его на каждой странице с ошибкой
 * в консоли. Вставка убирается при сборке, а правила полосы стоят
 * в `ui/styles/_site.scss`. Строка сверяется дословно: изменись она
 * в новом выпуске Turbo, сборка откажет, а не соберёт вид с ошибкой
 * в консоли.
 */
const TURBO_STYLE = 'document.head.insertBefore(this.stylesheetElement, document.head.firstChild);';

/** Подмена модуля Turbo при сборке сценария: без вставки стиля. */
const TURBO_WITHOUT_STYLE = {
    name: 'turbo-without-inline-style',
    setup(build) {
        build.onLoad({ filter: /@hotwired[\\/]turbo[\\/]dist[\\/].*\.js$/ }, async ({ path }) => {
            const source = await readFile(path, 'utf8');

            if (!source.includes(TURBO_STYLE)) {
                throw new Error(`в ${path} нет вставки стиля полосы загрузки — сверьте выпуск Turbo`);
            }

            return { contents: source.replace(TURBO_STYLE, ''), loader: 'js' };
        });
    },
};

/**
 * Собирает стили: dart-sass поверх исходников Bootstrap из node_modules.
 *
 * @returns {Promise<string>} готовый CSS
 */
async function buildStyles() {
    const sass = await import('sass');

    const result = sass.compile(join(SOURCE_DIR, 'styles', 'app.scss'), {
        loadPaths: [MODULES_DIR],
        style: 'compressed',
        // Карта исходников не нужна: файл отдаётся из памяти узла,
        // и того, на что карта ссылается, рядом нет.
        sourceMap: false,
        silenceDeprecations: SILENCED,
        quietDeps: true,
    });

    // Знак порядка байтов, который Sass ставит перед текстом с не-ASCII,
    // браузеру не нужен: тип и кодировку называет заголовок ответа.
    return result.css.replace(/^﻿/, '');
}

/**
 * Собирает сценарий из модулей в один файл.
 *
 * @param {string} entry имя файла в ui/js
 * @returns {Promise<string>} готовый JS
 */
async function buildScript(entry) {
    const result = await Bun.build({
        entrypoints: [join(SOURCE_DIR, 'js', entry)],
        minify: true,
        target: 'browser',
        format: 'iife',
        plugins: [TURBO_WITHOUT_STYLE],
    });

    if (!result.success) {
        throw new AggregateError(result.logs, `сценарий ${entry} не собран`);
    }

    return await result.outputs[0].text();
}

/**
 * Длинная скобка Lua, которой нет в содержимом: файлы вида сами
 * содержат квадратные скобки, и обычная строка порвалась бы на первой.
 *
 * @param {string[]} bodies
 * @returns {string} знаки равенства уровня скобки
 */
function levelFor(bodies) {
    let level = '==';

    while (bodies.some((body) => body.includes(`]${level}]`))) {
        level += '=';
    }

    return level;
}

/**
 * Модуль Lua с файлами вида: имя → содержимое.
 *
 * Текст ложится длинной строкой как есть. Байты — строкой base64
 * в таблице `{ base64 = … }`: длинная строка Lua меняет перевод строки
 * `\r\n` на `\n`, и шрифт с такими байтами пришёл бы в браузер
 * испорченным. Раскрывает base64 модуль `tnt.docs.assets`.
 *
 * @param {Record<string, string>} texts
 * @param {Record<string, Buffer>} binaries
 * @returns {string}
 */
function moduleOf(texts, binaries) {
    const encoded = Object.fromEntries(Object.entries(binaries).map(([name, body]) => [name, body.toString('base64')]));
    const level = levelFor([...Object.values(texts), ...Object.values(encoded)]);
    const lines = [
        '--- Файлы вида раздела документации, упакованные в модуль.',
        '---',
        '--- Файл собирает `bun run build` из каталога ui пакета: править его руками',
        '--- бесполезно, правки затрёт следующая сборка.',
        '',
        'return {',
    ];

    for (const name of [...Object.keys(texts), ...Object.keys(encoded)].sort()) {
        // Перевод строки сразу за открывающей скобкой Lua отбрасывает сама:
        // содержимое начинается со следующей строки и доходит до закрывающей.
        if (name in texts) {
            lines.push(`    ['${name}'] = [${level}[\n${texts[name]}]${level}],`);
        } else {
            lines.push(`    ['${name}'] = { base64 = [${level}[\n${encoded[name]}]${level}] },`);
        }
    }

    lines.push('}', '');

    return lines.join('\n');
}

/** Собирает вид целиком. */
async function build() {
    const texts = {
        'docs.css': await buildStyles(),
        'docs.js': await buildScript('app.js'),
        'theme.js': await buildScript('theme.js'),
        'favicon.svg': await readFile(join(SOURCE_DIR, 'img', 'favicon.svg'), 'utf8'),
        'fonts/OFL.txt': await readFile(join(SOURCE_DIR, 'fonts', 'OFL.txt'), 'utf8'),
    };

    const binaries = {};

    for (const name of IMAGES) {
        binaries[name] = await readFile(join(SOURCE_DIR, 'img', name));
    }

    for (const [name, path] of Object.entries(FONTS)) {
        binaries[name] = await readFile(join(MODULES_DIR, path));
    }

    await writeFile(TARGET, moduleOf(texts, binaries));

    const sizes = [...Object.entries(texts), ...Object.entries(binaries)].map(
        ([name, body]) => `${name} ${Math.round(body.length / 1024)} КБ`,
    );

    console.log(`Вид собран: ${sizes.join(', ')} → tnt/docs/public/bundle.lua`);
}

await build();

if (process.argv.includes('--watch')) {
    let timer = null;

    watch(SOURCE_DIR, { recursive: true }, () => {
        clearTimeout(timer);
        timer = setTimeout(() => {
            build().catch((failure) => console.error(failure.message));
        }, SETTLE_MS);
    });

    console.log('Жду правок в ui/…');
}
