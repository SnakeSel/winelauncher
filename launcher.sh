#!/bin/bash

# Linux Wine Launcher
# Script to simplify wine environment creation and run games.
#
# Author: SnakeSel
# Download wine:
#   * PlayOnLinux: https://www.playonlinux.com/wine/binaries/phoenicis/staging-linux-amd64/
#   * wine-tkg: https://github.com/Frogging-Family/wine-tkg-git
#
# sudo winetricks --self-update

version=20230501

#### NOT EDIT ##############
script_name=${0##*/}
# каталог в котором лежит скрипт
work_dir=$(dirname $(readlink -e "$0"))

#DEFAULT_CONFIG_BEGIN
# show debug msg
debugging=0

# Запускать 1 копию игры. (Убивает прочие копии при запуске.)
onerun=1

# Параметры игры
_gamename="$(basename "${work_dir}")"
_gameexe="game.exe"
_gamedir="${work_dir}"

# Компоненты необходимые для игры. Ставятся через winetriks
#_wt_components="xna40"

# Настройки dll
# dll["<имя библиотеки>"]="<режим работы>"
# режим работы: builtin|native|default|disabled
declare -A dll
#dll["winegstreamer"]="disabled"
#dll["quartz"]="builtin"

## Параметры WINE
#WINE="wine"
WINE="${HOME}/.local/wine/wine-tkg/bin/wine64"
WINEPREFIX="${HOME}/.local/winepfx/${_gamename}/"

# win64 | win32
WINEARCH=win64

WINEESYNC=0
WINEFSYNC=0

#DEFAULT_CONFIG_END
######################################################

help(){
    cat << EOF
$script_name [command] <args>
command:
    r  run game
    n  create new wineprefix
    cfg  start winecfg
    dxvk install dxvk
    adxvk install dxvk-async
    desc create desktop entry
    exe execute exe file in wineprefix
    save save game config from wineprefix
    load load game config to wineprefix
    v show version and variables
EOF
}

debug() {
    if [ "${debugging:-0}" -eq 1 ]; then
        #echo "$(date +'%Y-%m-%d %H:%M:%S')" "$@" >> "${logfile}/${script_name}.log"
        echo "[DBG:${BASH_LINENO[0]}] $*"
    fi
}

common_override_dll()
{
    _W_mode="$1"
    module="$2"

    debug "override ${module} ${_W_mode}"

    case "${_W_mode}" in
        "default")
            # To delete a registry key, give an unquoted dash as value
            echo "\"*${module}\"=-" >> "${W_TMP}"/override-dll.reg
        ;;

        "disabled")
            echo "\"*${module}\"=\"\"" >> "${W_TMP}"/override-dll.reg
        ;;
        *)
            echo "\"*${module}\"=\"${_W_mode}\"" >> "${W_TMP}"/override-dll.reg
        ;;
    esac

}

override_dlls()
{

    if [ ${#dll[@]} -eq 0 ]; then
        echo "No dll override, return."
        return 0
    fi

    W_TMP="${WINEPREFIX}/drive_c/windows/temp"

    # Создаем шапку
    cat > "${W_TMP}"/override-dll.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
_EOF_

    # Добавляем значения для dll
    for module in "${!dll[@]}"; do
        common_override_dll "${dll[$module]}" "${module}"
    done

    debug 'regedit "/S" "C:\windows\Temp\override-dll.reg"'
    env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" ${WINE} regedit "/S" "C:\windows\Temp\override-dll.reg"

    unset W_TMP
}

createwineprefix(){
    debug "wine: ${WINE}"
    type "${WINE}" >/dev/null 2>&1 || { echo >&2 "[ERR] Wine not found. Aborting."; return; }

    #winever=$("${WINE}" --version)
    if ! winever=$("${WINE}" --version);then
        echo "[ERR] Wine not found"
        read -r -p "Any key to continue"
        return
    fi

    echo "Create new wineprefix..."
    echo "${winever}, WINEARCH=${WINEARCH}"
    echo ""
    echo "Enter patch to wineprefix or empty to default"
    read -e -r -p "(default patch: ${WINEPREFIX}) :"  ptch
    if [ "${ptch}" != "" ];then
        WINEPREFIX=${ptch}
    fi

    if [ -f "${WINEPREFIX}/system.reg" ];then
        while true; do
            read -r -p "Remove ${WINEPREFIX}? (y\n):" yn
            case $yn in
                [Yy]* )
                    rm -rf "${WINEPREFIX}"
                    break;;
                [Nn]* ) return 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    echo "Init wine to ${WINEPREFIX}"

    if ! [ -d "${WINEPREFIX}" ]; then
        mkdir -p "${WINEPREFIX}"
    fi

    #WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" wineboot --init
    if ! env WINEARCH="${WINEARCH}" WINEDEBUG="-all" WINEPREFIX="${WINEPREFIX}" ${WINE} wineboot -u;then
        echo "[ERR] Create wineprefix"
        read -r -p "Any key to continue"
        return
    fi

    # install compoments
    if [ ${#_wt_components[@]} -ne 0 ]; then
        type winetricks >/dev/null 2>&1 || { echo >&2 "[Warn] No winetricks found.  Aborting."; return; }

        echo "Install components"
        env WINEARCH="${WINEARCH}" WINEDEBUG="-all" WINEPREFIX="${WINEPREFIX}" WINE="${WINE}" winetricks -q ${_wt_components}
    fi

    echo "Override dlls"
    override_dlls

    echo "
wineprefix created success!
"

    return

}

rungame(){
    if [ "${onerun:-0}" -eq 1 ]; then
        killall "${_gameexe}"
    fi

    if [ "${debugging:-0}" -eq 1 ]; then
        local PARAM=(DXVK_HUD="devinfo,fps,version,memory,gpuload," DXVK_LOG_LEVEL="info")
        local WINEDEBUG="fixme-all,err+loaddll,err+dll,err+file,err+reg"
        local out="${work_dir}/${_gamename}.log"
    else
        local PARAM=(DXVK_LOG_LEVEL="none")
        local WINEDEBUG="-all"
        local out="/dev/null"
    fi

    if [ "${WINEESYNC:-0}" -eq 1 ]; then
        local limit
        limit=$(ulimit -Hn)
        if [[ "$limit" -ge "524288" ]];then
            PARAM=("${PARAM[@]}" "WINEESYNC=1")
        else
            cat << EOF


ESYNC не поддерживается!
Текущий лимит: $limit

Увеличьте лимит:

* Если используется systemd:
в файлы
/etc/systemd/system.conf
/etc/systemd/user.conf
добавить DefaultLimitNOFILE=524288

* Если используется pam-limits:
echo "$USER soft nofile 524288" | sudo tee --append /etc/security/limits.conf && echo "$USER hard nofile 524288" | sudo tee --append /etc/security/limits.conf

Подробнее:
https://github.com/lutris/docs/blob/master/HowToEsync.md


EOF
            read -n 1 -s -r -p "Нажмите любую кнопку для продолжения"
        fi
    fi

    if [ "${WINEFSYNC:-0}" -eq 1 ]; then
        PARAM=("${PARAM[@]}" "WINEFSYNC=1")
    fi

    cd "${_gamedir}" || { echo "[err] cd to ${_gamedir}";exit 1; }
    debug "env \"${PARAM[@]}\" WINEARCH=\"${WINEARCH}\" WINEDEBUG=\"${WINEDEBUG}\" WINEPREFIX=\"${WINEPREFIX}\" nohup ${WINE} ${_gameexe} &>${out} &"
    env "${PARAM[@]}" WINEARCH="${WINEARCH}" WINEDEBUG="${WINEDEBUG}" WINEPREFIX="${WINEPREFIX}" nohup ${WINE} ${_gameexe} &>${out} &
    sleep 2

}

install_dxvk(){
    type winetricks >/dev/null 2>&1 || { echo >&2 "[Warn] No winetricks found.  Aborting."; return; }
    env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" WINE="${WINE}" winetricks -q -f dxvk
}

install_exe(){
    echo ""
    echo "Select exe file to run"

    if (type zenity >/dev/null 2>&1);then
        ptch=$(zenity --file-selection --title="Select exe file to run" --file-filter=*.exe)
    else
        read -e -r -p "Enter full patch to exe file: "  ptch
    fi

    if [ -f "${ptch}" ]; then
        env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" ${WINE} "${ptch}"
    else
        echo "File not found."
        exit 1
    fi

    exit 0
}

save(){
    echo "the function must be implemented in the game config"
}

load(){
    echo "the function must be implemented in the game config"
}

create_desktop(){
# Если нет иконки, пытаемся создать
if [ ! -f "${work_dir}/${_gamename}.ico" ]; then
    if (type wrestool >/dev/null 2>&1);then
        debug "Create ${_gamename}.ico"
        wrestool -x --output="${_gamedir}/${_gamename}.ico" -t14 "${_gamedir}/${_gameexe}"
    else
        debug "No install wrestool."
    fi
fi

echo "Create ${_gamename}.desktop"

cat << EOF > ${_gamename}.desktop
[Desktop Entry]
Type=Application
Name=${_gamename}
Comment=${_gamename} Linux Launcher
Exec=${work_dir}/launcher.sh
Icon=${work_dir}/${_gamename}.ico
Terminal=true
EOF

chmod +x ${_gamename}.desktop

}

# $1 - "{owner}/{repo}"
get_latest_release() {
    if which -a jq >/dev/null; then
        wget --quiet -O - "https://api.github.com/repos/$1/releases/latest" | jq -r '.tag_name'
    else
        wget --quiet -O - "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
        grep '"tag_name":' |                                            # Get tag line
        sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
    fi
}

install_adxvk(){
    repo="Sporif/dxvk-async"

    echo "Get release DXVK-async ..."
    latestTag=$(get_latest_release "$repo")
    echo "Latest version: ${latestTag}"

    echo "Remove old dxvk*"
    rm -R "${_gamedir}"/dxvk-*

    taginfo=$(wget --quiet -O - "https://api.github.com/repos/${repo}/releases/tags/${latestTag}")
    debug "$taginfo"
    file_uri=$(echo "$taginfo" | jq -r '.assets[0].browser_download_url')
    file_name=$(echo "$taginfo" | jq -r '.assets[0].name')

    echo "Download ${latestTag} to ${_gamedir}/${file_name}"
    debug "from ${file_uri}"
    echo ""

    wget -c -nH -q --show-progress -P "${_gamedir}" "${file_uri}"

    echo "Extract tar.gz ..."

    if [ ! -s "${_gamedir}/${file_name}" ];then
        echo "[ERR] dxvk not found. (${data_dir}/${file_name})"
        read -r -p "Any key to exit"
        #return
        exit 1
    fi

    tar -C "${_gamedir}" -xvf "${_gamedir}/${file_name}"
    if [ $? -ne 0 ];then
        echo "[ERR] extract ${_gamedir}/${file_name}"
        read -r -p "Any key to continue"
        exit 1
    fi

    cd "${_gamedir}"/dxvk-*/ || { echo "[err] cd to ${_gamedir}/dxvk-*/";exit 1; }
    chmod +x ./setup_dxvk.sh
    WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" WINE="${WINE}" ./setup_dxvk.sh install

    echo "Clean..."
    rm -f "${_gamedir}"/"${file_name}"
    rm -R "${_gamedir}"/dxvk-*

}

show_version() {
    echo -e "
$script_name - wine launcher from SnakeSel
version: $version

game:\t${_gamename}
dir:\t${_gamedir}
exe:\t${_gameexe}

wine:\t$WINE
pfx:\t$WINEPREFIX
arch:\t$WINEARCH
ESYNC:\t$WINEESYNC
FSYNC:\t$WINEFSYNC
"
    if [ ${#_wt_components[@]} -ne 0 ]; then
        echo "winetricks install: ${_wt_components[@]}"
    fi

}

#####################################################################################
debug "Start ${script_name}. version: ${version}"

cfgname="${_gamename}.lcfg"
# Загружаем настройки для игры
if [[ -f "${work_dir}/${cfgname}" ]]; then
  debug "Loading config from ${work_dir}/${cfgname}"
  . "${work_dir}/${cfgname}"
fi


#Если параметр 1 не существует, запуск
if [ -z "$1" ]
then
    if ! [ -d "${WINEPREFIX}" ]; then
        createwineprefix
    fi
    rungame
    exit 0
fi

case "$1" in
    n) createwineprefix;;
    r) rungame;;
    cfg) env WINEARCH="${WINEARCH}" WINEDEBUG="-all" WINEPREFIX="${WINEPREFIX}" ${WINE} winecfg;;
    reg) env WINEARCH="${WINEARCH}" WINEDEBUG="-all" WINEPREFIX="${WINEPREFIX}" ${WINE} regedit;;
    dxvk) install_dxvk;;
    adxvk) install_adxvk;;
    dll) override_dlls;;
    desc) create_desktop;;
    exe) install_exe;;
    save) save;;
    load) load;;
    v) show_version;;
    *) help;;
esac

exit 0
