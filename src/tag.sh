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
    :
}

function filter {
    :
}

function find {
    :
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
