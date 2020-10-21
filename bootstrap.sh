#!/usr/bin/env bash
scriptName=bootstrap.sh
scriptVersion=0.4.3
>&2 echo "Running $scriptName version=$scriptVersion"

shellName="${SHELL##*/}"
case $shellName in
    "ash")
        >&2 echo "using fallback shell 'sh' to serve current shell 'ash"
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
rcFileLine2='eval "$('$basherExecutable' init - '$shellName')"'

if [[ "$1" == "install" ]] ; then
    if [ -f "$basherExecutable" ]; then
        >&2 echo "Basher executable already present, skipping installation"
    else
        >&2 echo "Basher executable not found, cloning git repo..."
        git clone https://github.com/basherpm/basher.git "$HOME"/.basher
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
                >&2 echo "Unsupported shell $shellName"
                exit 1
                ;;
        esac
        echo "$rcFileLine1" >> "$HOME"/$rcFile
        echo "$rcFileLine2" >> "$HOME"/$rcFile
        >&2 echo "Basher installation completed"
    fi
    exit
fi

if [[ "$DEP_SOURCED" == 1  ]]; then 
    >&2 echo "Error invoking '$scriptName' (already sourced)"
    exit 1
fi

if [ -f "$basherExecutable" ]; then
    >&2 echo "Detected shell=$shellName basher=$basherExecutable"
    if ! command -v basher >/dev/null ; then
        >&2 echo "basher command not available, initializing..."
        eval "$rcFileLine1"
        eval "$rcFileLine2"
    fi
    # shellcheck disable=SC1090
    . "$(dirname "$basherExecutable")/../lib/include.$shellNameFallback"
    DEP_SOURCED=1
else
    >&2 echo "Unable to find basher executable, try installing using command: '$scriptName install'"
    exit 1
fi

checkBlanks() {
    # also check for other unsupported chars?
    for s in "$@"
    do
        if [[ $s = *[[:space:]]* ]] ; then
            >&2 echo "no blanks allowed in parameters/variables"
            exit 1
        fi
    done
}

repoBaseURL=${DEP_REPO_BASE_URL:-"https://github.com"}
checkBlanks "$repoBaseURL"

dep() {
    command=$1
    if [[ -z $command ]] ; then
        >&2 echo "usage: dep <command> <options> (currently available commands: define, include)"
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
        >&2 echo "usage: dep define <packageName:packageTag>"
        exit 1
    fi
    checkBlanks "$packageNameTag"
    local arr
    #shellcheck disable=SC2206
    arr=(${packageNameTag//:/ })
    local packageName=${arr[0]}
    local packageTag=${arr[1]}
    if [[ -z $packageName ]] || [[ -z $packageTag ]]; then
        >&2 echo "usage: dep define <packageName:packageTag>"
        exit 1
    fi
    
    local logSubstring="package '$packageNameTag'"
    >&2 echo "defining $logSubstring"

    includedValue=$(get_included_value "$packageName")
    if [[ -n "$includedValue" ]] ; then
        local includedTag=${includedValue%%:*}
        if [[ "$packageTag" != "$includedTag" ]] ; then
            >&2 echo "can't define '$packageNameTag', package already included with different version: $includedTag"
            exit 1
        fi
        >&2 echo "already defined, skipping"
    else
        DEP_INCLUDED="$DEP_INCLUDED $packageName:$packageTag"
        >&2 echo "defined $logSubstring"
    fi
}

dep_include() {
    local packageNameTag=$1
    local scriptName=$2
    if [[ -z $packageNameTag ]] || [[ -z $scriptName ]] ; then
        >&2 echo "usage: dep include <packageName[:packageTag]> <scriptName>"
        exit 1
    fi
    checkBlanks "$packageNameTag" "$scriptName"

    local logSubstring="script '$scriptName.sh' from package: '$packageNameTag'"
    >&2 echo "including $logSubstring"
    
    local arr
    #shellcheck disable=SC2206
    arr=(${packageNameTag//:/ })
    local packageName=${arr[0]}
    local packageTag=${arr[1]}
    
    includedValue=$(get_included_value "$packageName")
    if [[ -n "$includedValue" ]] ; then
        local includedTag=${includedValue%%:*}
        if [[ -z "$packageTag" ]] ; then
            >&2 echo "using defined package version: $includedTag"
            packageTag=$includedTag
        elif [[ "$packageTag" != "$includedTag" ]] ; then
            >&2 echo "can't include '$packageNameTag', package already included with different version: $includedTag"
            exit 1
        fi
        local includedScripts=${includedValue#*:}
        local includedScripts=":$includedScripts:"
        if [[ $includedScripts = *:$scriptName:* ]] ; then
            >&2 echo "already included, skipping"
            return
        fi
        local oldEntry=" $packageName:$includedValue"
        local newEntry="$oldEntry:$scriptName"
        DEP_INCLUDED=${DEP_INCLUDED/$oldEntry/$newEntry}
    elif [[ -z "$packageTag" ]] ; then
        >&2 echo "missing version"
        exit 1
    else
        DEP_INCLUDED="$DEP_INCLUDED $packageName:$packageTag:$scriptName"
    fi

    local versionedPackageName="$packageName-$packageTag"
    local localPackagePath="$HOME/.dep/repository/$packageName/$packageTag"
    if [[ $packageTag != *"-SNAPSHOT" ]] && [[ -d "$localPackagePath" ]] && $basherExecutable list | grep -q "$versionedPackageName" ; then
        >&2 echo "found existing local copy of: '$versionedPackageName'"
        existingTag=$(cd "$localPackagePath/.git" && git describe --exact-match --tags) || exit 1
        if [[ "$existingTag" != "$packageTag" ]] ; then
            >&2 echo "unexpected local tag found: '$existingTag'. Expected: '$packageTag'"
            exit 1
        fi
    else
        $basherExecutable uninstall "$versionedPackageName" 1>&2
        [ ! -d "$localPackagePath" ] && mkdir -p "$localPackagePath"
        rm -rf "$localPackagePath"
        git -c advice.detachedHead=false clone --depth 1 --branch "$packageTag" "$repoBaseURL/$packageName" "$localPackagePath" || exit 1
        $basherExecutable link "$localPackagePath" "$versionedPackageName" || exit 1
    fi

    include "$versionedPackageName" "lib/$scriptName.sh" || exit 1

    >&2 echo "inclued $logSubstring"
}
