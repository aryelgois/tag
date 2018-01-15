#!/usr/bin/env bash
#
# tag - a tool for using tags in files
#
# @author Aryel Mota Góis
# @license MIT

#
# Utils
#

function errcho {
    >&2 echo "$@"
}

function file_exists {
    if [[ ! -e $1 ]]; then
        errcho "E: File '$1' does not exist or is inaccessible"
        return 3
    fi
}

function dir_exists {
    if [[ ! -d $1 ]]; then
        errcho "E: '$1' is not a directory, does not exist or is inaccessible"
        return 4
    fi
}

function read_tags {
    local TMP=
    if [[ -e $1 ]]; then
        TMP=$(grep "^$2" "$1" | tail -n 1)
        TMP="${TMP:((${#2} + 1))}"
    fi
    echo $TMP
}

function ere_quote {
    sed 's/[]\.|$(){}?+*^]/\\&/g' <<< "$*"
}

function unique {
    for i in "$@"; do echo $i; done | sort -u
}

#
# Commands
#

function help {
    echo "\
USAGE:
    tag [-h|--help]

    tag add|filter|remove TAGS [PATH]...

    tag find TAGS [DIRECTORY]...

    tag list [PATH]...

    tag copy|move SRC DEST

PATH and DIRECTORY can be passed with stdin"
    exit $1
}

function add {
    file_exists "$1" || return

    local BASENAME=$(basename "$1")
    local TAG_FILE="$(dirname "$1")/.tags"
    local OLD=$(read_tags "$TAG_FILE" "$BASENAME")
    local IFS=
    local NEW=

    IFS=','  ; NEW=($OLD $2)
    IFS=$'\n'; NEW=($(unique "${NEW[@]}"))
    IFS=','  ; NEW="${NEW[*]}"
    unset IFS

    sed -i "/^$BASENAME/ d" "$TAG_FILE"
    echo "$BASENAME/$NEW" >> $TAG_FILE
}

function filter {
    :
}

function find {
    dir_exists "$1" || return

    local IFS=','
    local TAGS=($(ere_quote "$2"))
    local LIST=
    unset IFS

    for i in "${TAGS[@]}"; do
        LIST="$LIST && /.*\/.*$i(,|$)/"
    done
    LIST="${LIST:4}"

    command find "$1" -type f -name .tags | while read dotTAGS; do
        DIRNAME="$(dirname "$dotTAGS")"
        awk "$LIST" "$dotTAGS" | cut -d / -f 1 | while read FILE; do
            echo "$DIRNAME/$FILE"
        done
    done
}

function remove {
    :
}

function list {
    :
}

function copy {
    :
}

function move {
    :
}

#
# Main
#

if [[ ! -t 0 ]]; then
    IFS=$'\n'; STDIN=($(</dev/stdin)); unset IFS
fi

while [[ $# -gt 0 ]]; do
    KEY="$1"
    NEXT="$2"
    case $KEY in
    -h|--help)
        help
        ;;
    add|filter|find|remove)
        shift 2
        if [[ -z $NEXT || $# -eq 0 && -z $STDIN ]]; then
            if [[ -n $NEXT && $KEY == 'find' ]]; then
                STDIN=('.')
            else
                help 1
            fi
        fi

        if [[ $# -gt 0 ]]; then
            FILES=("$@")
        else
            FILES=("${STDIN[@]}")
        fi

        for FILE in "${FILES[@]}"
        do
            $KEY "$FILE" "$NEXT"
        done
        exit
        ;;
    copy|move)
        shift
        if [[ $# -eq 2 ]]; then
            $KEY "$1" "$2"
        else
            help 1
        fi
        exit
        ;;
    list)
        shift
        if [[ $# -gt 0 ]]; then
            list "$@"
        else
            help 1
        fi
        exit
        ;;
    *)
        errcho "E: unexpected argument '$1'"
        exit 2
        ;;
    esac
done

help 1
