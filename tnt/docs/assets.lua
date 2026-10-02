--- Файлы вида раздела: стили, сценарии, значки и шрифты — с меткой
--- версии в адресе.
---
---     assets.files['docs.css']   -- содержимое для раздачи
---     assets.VERSION             --> '1a2b3c4d'
---     -- адрес: <начало раздела>/assets/1a2b3c4d/docs.css
---
--- Вид едет роком в модуле `tnt.docs.public.bundle` и раздаётся из
--- памяти процесса. Метка версии — crc32 всего вида — стоит в адресе:
--- адрес меняется вместе с содержимым, и браузеру можно держать файл
--- год, не спрашивая узел (`immutable`). Новый выпуск пакета даёт новые
--- адреса, а не старые адреса с новым содержимым, которое застряло бы
--- в кэше браузера до конца срока.
---
--- Метка считается при загрузке модуля, а не при сборке вида: так она
--- не может разойтись с тем, что лежит в модуле, кто бы его ни правил.
---
--- Текст лежит в модуле строкой, байты — таблицей `{ base64 = … }`:
--- длинная строка Lua меняет перевод строки `\r\n` на `\n`, и шрифт
--- с такими байтами пришёл бы испорченным. Раскрываются они здесь же,
--- один раз, при загрузке.

local digest = require('digest')

local bundle = require('tnt.docs.public.bundle')

local Module = {}

--- Метка версии файлов: crc32 имён и содержимого по порядку имён.
---
--- Имя входит в метку наравне с содержимым: файл, переименованный без
--- правки, — другой вид, и страница прошлой версии искала бы его
--- под прежним именем.
---@param files table<string, string> Имя файла → содержимое
---@return string
function Module.version_of(files)
    local names = {}

    for name in pairs(files) do
        table.insert(names, name)
    end

    table.sort(names)

    local parts = {}

    for _, name in ipairs(names) do
        table.insert(parts, name)
        table.insert(parts, files[name])
    end

    return ('%08x'):format(digest.crc32(table.concat(parts, '\0')))
end

--- Файлы набора: строка — как есть, таблица — байты в base64.
---@param packed table<string, string|{ base64: string }>
---@return table<string, string>
function Module.unpacked(packed)
    local files = {}

    for name, body in pairs(packed) do
        if type(body) == 'table' then
            body = digest.base64_decode(body.base64)
        end

        files[name] = body
    end

    return files
end

--- Файлы вида: имя → содержимое.
Module.files = Module.unpacked(bundle)

--- Метка версии вида.
Module.VERSION = Module.version_of(Module.files)

return Module
