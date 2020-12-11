#!/usr/bin/env bash
scriptName=bootstrap.sh
scriptVersion=0.4.3-SNAPSHOT

# Levels:
# 0: prints nothing
# 1: prints included deps on one line (currently not implemented, equal to verboseness level 2)
# 2: print stree of included deps, concisely but on each dep on one line
_DEP_VERBOSENESS_LEVEL="${_DEP_VERBOSENESS_LEVEL:-2}"

# Define as non-empty to show operation internals (output of git, etc.) intermixed with dep messages
# Ignored when _DEP_VERBOSENESS_LEVEL is 0
#_DEP_INTERNALS_SHOWN=

if (( _DEP_VERBOSENESS_LEVEL == 0 )) ; then
    _DEP_INTERNALS_SHOWN=
fi

_capitalize() {
    local message="$*"
    echo "${message^}"
}

_emit_log_line_string() {
    local message="$*"
    if (( _DEP_VERBOSENESS_LEVEL > 0 )) ; then
        >&2 echo -n "$message"
    fi
}

_emit_log_line() {
    local message="$*"
    _emit_log_line_string "- $(_capitalize "$message")"
    _emit_log_line_newline
}

_LOG_LINE_WATCHER_INDENT_COUNT=0

_emit_log_line_start() {
    local message="$*"
    if (( _LOG_LINE_WATCHER_INDENT_COUNT > 0 )) ; then
        _emit_log_line_newline
    fi
    _emit_log_line_string "$(printf "%${_LOG_LINE_WATCHER_INDENT_COUNT}s" "")- ${message^} ... "
    _LOG_LINE_WATCHER_ITEMS=0
    _LOG_LINE_WATCHER_INDENT_COUNT=$(( _LOG_LINE_WATCHER_INDENT_COUNT + 2 ))
}

_emit_log_line_part() {
    local message="$*"
    if (( _LOG_LINE_WATCHER_ITEMS > 0 )) ; then
        _emit_log_line_string ", "
    fi

    _emit_log_line_string "$message"
    _LOG_LINE_WATCHER_ITEMS=$(( _LOG_LINE_WATCHER_ITEMS + 1 ))
}

_emit_log_line_end() {
    if (( _LOG_LINE_WATCHER_ITEMS > 0 )) ; then
        _emit_log_line_string ". "
    fi
    _emit_log_line_newline
    _LOG_LINE_WATCHER_INDENT_COUNT=$(( _LOG_LINE_WATCHER_INDENT_COUNT - 2 ))
}

_emit_log_line_newline() {
    if (( _DEP_VERBOSENESS_LEVEL > 0 )) ; then
        >&2 echo
    fi
}

_mute() {
    local parameters=("$@")
    if [ -z "$_DEP_INTERNALS_SHOWN" ]; then
        "${parameters[0]}" "${parameters[@]:1}" >/dev/null 2>&1
    else
        "${parameters[0]}" "${parameters[@]:1}"
    fi
}

_emit_log_line "running $scriptName version=$scriptVersion"

shellName="${SHELL##*/}"
case $shellName in
    "ash")
        _emit_log_line "using fallback shell 'sh' to serve current shell 'ash"
        shellNameFallback="sh"
        ;;
    *)
        shellNameFallback=$shellName
        ;;
esac

basherDir="${BASHER_ROOT:-$HOME/.basher}"
basherExecutable="$basherDir/bin/basher"
# shellcheck disable=SC2016
rcFileLine1='export PATH="'$(dirname "$basherExecutable")':$PATH"'
# shellcheck disable=SC2016
rcFileLine2='eval "$(_mute '$basherExecutable' init - '$shellName')"'

if [[ "$1" == "install" ]] ; then
    if [ -f "$basherExecutable" ]; then
        _emit_log_line "Basher executable already present, skipping installation"
    else
        _emit_log_line_start "Basher executable not found, cloning git repo"
        _mute git clone https://github.com/basherpm/basher.git "$HOME"/.basher
        case $shellNameFallback in
            "bash")
                rcFile=".bashrc"
                ;;
            "dash")
                rcFile=".bashrc"
                ;;
            "sh")
                rcFile=".profile"
                ;;
            "zsh")
                rcFile=".zshrc"
                ;;
            *)
                _emit_log_line "Unsupported shell $shellName"
                exit 1
                ;;
        esac
        echo "$rcFileLine1" >> "$HOME"/$rcFile
        echo "$rcFileLine2" >> "$HOME"/$rcFile
        _emit_log_line_part "Basher installation completed"
        _emit_log_line_end
    fi
    exit
fi

if [[ "$DEP_SOURCED" == 1  ]]; then 
    _emit_log_line "Error invoking '$scriptName' (already sourced)"
    exit 1
fi

if [ -f "$basherExecutable" ]; then
    _emit_log_line "Detected shell=$shellName basher=$basherExecutable"
    if ! command -v basher >/dev/null ; then
        _emit_log_line "basher command not available, initializing..."
        eval "$rcFileLine1"
        eval "$rcFileLine2"
    fi
    # shellcheck disable=SC1090
    . "$(dirname "$basherExecutable")/../lib/include.$shellNameFallback"
    DEP_SOURCED=1
else
    _emit_log_line "Unable to find basher executable, try installing using command: '$scriptName install'"
    exit 1
fi

checkBlanks() {
    # also check for other unsupported chars?
    for s in "$@"
    do
        if [[ $s = *[[:space:]]* ]] ; then
            _emit_log_line "no blanks allowed in parameters/variables"
            exit 1
        fi
    done
}

repoBaseURL=${DEP_REPO_BASE_URL:-"https://github.com"}
checkBlanks "$repoBaseURL"

dep() {
    command=$1
    if [[ -z $command ]] ; then
        _emit_log_line "usage: dep <command> <options> (currently available commands: define, include)"
        exit 1
    fi
    shift
    "dep_$command" "$@"
}

get_included_value(){
    packageName=$1
    if [[ $DEP_INCLUDED = *" $packageName:"* ]] ; then
        local includedValue=${DEP_INCLUDED#*" $packageName:"}
        echo "${includedValue%%" "*}"
    fi
}

dep_define(){
    local packageNameTag=$1
    if [[ -z $packageNameTag ]] ; then
        _emit_log_line "usage: dep define <packageName:packageTag>"
        exit 1
    fi
    checkBlanks "$packageNameTag"
    local arr
    #shellcheck disable=SC2206
    arr=(${packageNameTag//:/ })
    local packageName=${arr[0]}
    local packageTag=${arr[1]}
    if [[ -z $packageName ]] || [[ -z $packageTag ]]; then
        _emit_log_line "usage: dep define <packageName:packageTag>"
        exit 1
    fi
    
    local logSubstring="package '$packageNameTag'"
    _emit_log_line_start "defining $logSubstring"

    includedValue=$(get_included_value "$packageName")
    if [[ -n "$includedValue" ]] ; then
        local includedTag=${includedValue%%:*}
        if [[ "$packageTag" != "$includedTag" ]] ; then
            if [ -z "$VERBOSE_DEP" ]; then
                _emit_log_line_part "can't define, package already included with different version: $includedTag"
            else
                _emit_log_line_part "can't define '$packageNameTag', package already included with different version: $includedTag"
            fi
            _emit_log_line_end
            exit 1
        fi
        _emit_log_line_part "already defined, skipping"
    else
        DEP_INCLUDED="$DEP_INCLUDED $packageName:$packageTag"
        if [ -z "$VERBOSE_DEP" ]; then
            _emit_log_line_part "defined"
        else
            _emit_log_line_part "defined $logSubstring"
        fi
    fi
    _emit_log_line_end
}

dep_include() {
    local packageNameTag=$1
    local scriptName=$2
    if [[ -z $packageNameTag ]] || [[ -z $scriptName ]] ; then
        _emit_log_line "usage: dep include <packageName[:packageTag]> <scriptName>"
        exit 1
    fi
    checkBlanks "$packageNameTag" "$scriptName"

    local logSubstring="script '$scriptName.sh' from package: '$packageNameTag'"
    _emit_log_line_start "including $logSubstring"
    
    local arr
    #shellcheck disable=SC2206
    arr=(${packageNameTag//:/ })
    local packageName=${arr[0]}
    local packageTag=${arr[1]}
    
    includedValue=$(get_included_value "$packageName")
    if [[ -n "$includedValue" ]] ; then
        local includedTag=${includedValue%%:*}
        if [[ -z "$packageTag" ]] ; then
            _emit_log_line_part "using defined package version: $includedTag"
            packageTag=$includedTag
        elif [[ "$packageTag" != "$includedTag" ]] ; then
            if [ -z "$VERBOSE_DEP" ]; then
                _emit_log_line_part "can't include, package already included with different version: $includedTag"
            else
                _emit_log_line_part "can't include '$packageNameTag', package already included with different version: $includedTag"
            fi
            _emit_log_line_end
            exit 1
        fi
        local includedScripts=${includedValue#*:}
        local includedScripts=":$includedScripts:"
        if [[ $includedScripts = *:$scriptName:* ]] ; then
            _emit_log_line_part "already included, skipping"
            _emit_log_line_end
            return
        fi
        local oldEntry=" $packageName:$includedValue"
        local newEntry="$oldEntry:$scriptName"
        DEP_INCLUDED=${DEP_INCLUDED/$oldEntry/$newEntry}
    elif [[ -z "$packageTag" ]] ; then
        _emit_log_line_part "missing version"
        _emit_log_line_end
        exit 1
    else
        DEP_INCLUDED="$DEP_INCLUDED $packageName:$packageTag:$scriptName"
    fi

    local versionedPackageName="$packageName-$packageTag"
    local localPackagePath="$HOME/.dep/repository/$packageName/$packageTag"
    if [[ $packageTag != *"-SNAPSHOT" ]] && [[ -d "$localPackagePath" ]] && $basherExecutable list | grep -q "$versionedPackageName" ; then
        if [ -z "$VERBOSE_DEP" ]; then
            _emit_log_line_part "found existing local copy"
        else
            _emit_log_line_part "found existing local copy of: '$versionedPackageName'"
        fi
        existingTag=$(cd "$localPackagePath/.git" && git describe --exact-match --tags) || exit 1
        if [[ "$existingTag" != "$packageTag" ]] ; then
            _emit_log_line_part "unexpected local tag found: '$existingTag'. Expected: '$packageTag'"
            _emit_log_line_end
            exit 1
        fi
    else
        _mute "$basherExecutable" uninstall "$versionedPackageName" 1>&2
        _emit_log_line_part "cloning"
        [ ! -d "$localPackagePath" ] && mkdir -p "$localPackagePath"
        rm -rf "$localPackagePath"
        _mute git -c advice.detachedHead=false clone --depth 1 --branch "$packageTag" "$repoBaseURL/$packageName" "$localPackagePath" || exit 1
        _emit_log_line_part "linking"
        if _mute "$basherExecutable" link "$localPackagePath" "$versionedPackageName" ; then 
            true
        else
            _emit_log_line_part "could not link using basher!"
            _emit_log_line_end
            exit 1
        fi
    fi

    if include "$versionedPackageName" "lib/$scriptName.sh" ; then
        true # Correctly included
    else 
        _emit_log_line_part "could not include ${logSubstring}"
        _emit_log_line_end
        exit 1
    fi

    if [ -z "$VERBOSE_DEP" ]; then
        _emit_log_line_part "included"
    else
        _emit_log_line_part "included $logSubstring"
    fi
    _emit_log_line_end
}
