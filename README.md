# winelauncher
Запуск игр через wine.

Если вы хотите иметь полный контроль над своими префиксами.

Скрипт создает wineprefix, ставит указанные компоненты и замещения библиотек.

Параметры:
 - **r** запуск игры
 - **n** создать новый wineprefix и установить компоненты
 - **cfg** запустить winecfg в wineprefix
 - **dxvk** установка dxvk
 - **adxvk** установка [dxvk-async](https://github.com/Sporif/dxvk-async)
 - **desc** создать ярлык запуска
 - **exe** выполнить exe в wineprefix
 - **save** сохранить записи игры (только при наличии конфиг файла)
 - **load** загрузить записи игры (только при наличии конфиг файла)
 - **v** показать версию скрипта и переменные

**Требуется [winetricks](https://github.com/Winetricks/winetricks)**

## Установка
1. Скачать файл `launcher.sh`;
2. Положить его в папку с игрой (например $HOME/WoSB);
3. Настроить скрипт указав необходимые компоненты и замещения;
4. Дать права на исполнение `launcher.sh`;
5. Запустить `launcher.sh`;

## Файлы конфигурации для игр
Скрипт содержит настройки по умолчанию.
Поддерживаются индивидуальные файлы настроек для игр.
Файл должен лежать в директории скрипта и иметь название: *<имяигры>.lcfg*
По умолчанию **<имяигры> = название папки** в которой лежит скрипт.

Доступны настройки для игр:
 - CSP.lcfg [Corsairs Ship Pack](https://discord.gg/dmYPfdUq9d)
 - WoSB.lcfg [WorldofSeaBattle](https://www.worldofseabattle.com)

