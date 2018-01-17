#!/usr/bin/env bash
#
# tag - a tool for using tags in files
#
# @author Aryel Mota Góis
# @license MIT

#
# Utils
#

# Split a string into an array
#   $1 string to be splitted (byref)
#   $2 char delimiter (default to x1F)
function array_parse {
    local -n ARR=$1
    local IFS=${2:-$'\x1f'}
    ARR=($ARR)
}

# Remove all occurrences of a value in an array
#   $1 array (byref)
#   $2 value to be removed
function array_remove {
    local -n ARR=$1
    local DELETE=$2
    local TMP=()
    for i in "${ARR[@]}"; do [[ $i != $DELETE ]] && TMP+=($i); done
    ARR=("${TMP[@]}")
}

# Join an array items with a single character
#   $1 array to be joined (byref)
#   $2 char delimiter (default to x1F)
function array_stringify {
    local -n ARR=$1
    local IFS=${2:-$'\x1f'}
    ARR=("${ARR[*]}")
}

# Remove repeated items in array
#   $1 array (byref)
#   $2 char delimiter used during array rebuild (default to x1F)
#
# NOTE:
#   - It removes null values
#   - Result is unordered
function array_unique {
    local -n TMP1=$1
    local -A TMP2
    local SEP=${2:-$'\x1f'}
    SEP="${SEP::1}"
    for i in "${TMP1[@]}"; do [[ -n $i ]] && TMP2["$i"]=1; done
    TMP1="$(printf "%s$SEP" "${!TMP2[@]}")"
    array_parse TMP1 $SEP
}

# Get FILE array from arguments or stdin
#   $@ files
#
# If any argument is provided, FILES will contain them. Otherwise, FILES will
# contain the stdin, if it's not a TTY
function get_files {
    FILES=()
    if [[ $# -gt 0 ]]; then
        FILES=("$@")
    elif [[ ! -t 0 ]]; then
        FILES="$(</dev/stdin)"
        array_parse FILES $'\n'
    fi
}

# Echo to stderr
#   $@ output message
function errcho {
    >&2 echo "$@"
}

# Test if file exists
#   $1 path to file
#
# Error code:
#   3 file does not exist or is inaccessible
function file_exists {
    if [[ ! -e $1 ]]; then
        errcho "E: File '$1' does not exist or is inaccessible"
        return 3
    fi
}

# Test if directory exists
#   $1 path to directory
#
# Error code:
#   4 not a directory or 3 in file_exists()
function dir_exists {
    if [[ ! -d $1 ]]; then
        errcho "E: '$1' is not a directory, does not exist or is inaccessible"
        return 4
    fi
}

# Test if file has tags and stdout them
#   $1 path to file
#
# Error code:
#   5 file has no tags
function has_tag {
    local TAGS="$(list "$1")"
    if [[ -z $TAGS ]]; then
        errcho "E: '$1' has no tags"
        return 5
    fi
    echo $TAGS
}

# Escape string to embed in grep
#   $* string to be escaped
function ere_quote {
    sed 's/[][\/\.|$(){}?+*^]/\\&/g' <<< "$*"
}

# Get tags associated to a file in a .tags
#   $1 path to .tags
#   $2 file name to
function read_tags {
    local TMP=
    if [[ -e $1 ]]; then
        TMP=$(grep "^$(ere_quote "$2")/" "$1" | tail -n 1)
        TMP="${TMP:((${#2} + 1))}"
    fi
    echo $TMP
}

#
# Commands
#

# Output short help about the script
#   $1 status code to return
function help {
    echo "\
USAGE:
    tag [-h|--help]

    tag add|filter|remove TAGS [PATH]...

    tag clear [DIRECTORY|.tags]...

    tag find TAGS [DIRECTORY]...

    tag list [PATH]...

    tag copy|move SRC DEST

PATH and DIRECTORY can be passed with stdin"
    exit $1
}

# Add a tag to a file
#   $1 path to file
#   $2 tags to add
#
# NOTE:
#   - Tags are listed in '.tags' at the file's directory
function add {
    file_exists "$1" || return

    local BASENAME=$(basename "$1")
    local TAG_FILE="$(dirname "$1")/.tags"
    local TAGS="$(read_tags "$TAG_FILE" "$BASENAME"),$2"

    array_parse TAGS ,
    array_unique TAGS ,
    array_stringify TAGS ,

    [[ -e $TAG_FILE ]] && sed -i "/^$(ere_quote "$BASENAME")\// d" "$TAG_FILE"
    echo "$BASENAME/$TAGS" >> "$TAG_FILE"
}

# Filter file with a tag
#   $1 path to file
#   $2 tags to match
#
# stdout $1 if it has all tags
function filter {
    file_exists "$1" || return

    local BASENAME=$(basename "$1")
    local TAG_FILE="$(dirname "$1")/.tags"
    local TAGS="$(ere_quote "$2")"
    local LIST="/^$(ere_quote "$BASENAME")\//"
    local FOUND=

    array_parse TAGS ,
    for i in "${TAGS[@]}"; do
        LIST="$LIST && /(^[^\/]*\/|,)$i(,|$)/"
    done

    FOUND=$(awk "$LIST" "$TAG_FILE")

    [[ -n $FOUND ]] && echo "$1"
}

# Find files with a tag inside a directory
#   $1 path to directory
#   $2 tags to search
#
# stdout list of files found with all tags
function find {
    dir_exists "$1" || return

    local TAGS="$(ere_quote "$2")"
    local LIST=

    array_parse TAGS ,
    for i in "${TAGS[@]}"; do
        LIST="$LIST && /(^[^\/]*\/|,)$i(,|$)/"
    done
    LIST="${LIST:4}"

    command find "$1" -type f -name .tags | while read TAG_FILE; do
        DIRNAME=$(dirname "$TAG_FILE")
        awk "$LIST" "$TAG_FILE" | cut -d / -f 1 | while read FILE; do
            echo "$DIRNAME/$FILE"
        done
    done
}

# Remove tags associated to a file
#   $1 path to file
#   $2 tags to remove
#
# NOTE:
#   - The file does not need to exist, but the .tags file does
function remove {
    local TAG_FILE="$(dirname "$1")/.tags"
    file_exists "$TAG_FILE" || return

    local BASENAME=$(basename "$1")
    local TAGS=$(read_tags "$TAG_FILE" "$BASENAME")
    local REMOVE="$2"

    array_parse TAGS ,
    array_parse REMOVE ,
    for i in "${REMOVE[@]}"; do
        array_remove TAGS "$i"
    done
    array_stringify TAGS ,

    sed -i "/^$(ere_quote "$BASENAME")\// d" "$TAG_FILE"

    if [[ -n $TAGS ]]; then
        echo "$BASENAME/$TAGS" >> $TAG_FILE
    elif [[ ! -s $TAG_FILE ]]; then
        rm "$TAG_FILE"
    fi
}

# Clear .tags files listing nonexistent files
#   $1 path to directory or .tags file
#
# Error code:
#   6 file is not a .tags file
#
# NOTE:
#   - If a directory is passed, all .tags inside it are cleared
function clear {
    file_exists "$1" || return

    local BASENAME=$(basename "$1")

    if [[ -d $1 ]]; then
        command find "$1" -type f -name .tags | while read TAG_FILE; do
            clear "$TAG_FILE"
        done
        return
    elif [[ $BASENAME != '.tags' ]]; then
        errcho "E: File '$1' is not a .tags file"
        return 6
    fi

    local DIRNAME=$(dirname "$1")

    cat "$1" | cut -d / -f 1 | while read FILE; do
        [[ -e "$DIRNAME/$FILE" ]] || sed -i "/^$(ere_quote "$FILE")\// d" "$1"
    done

    [[ ! -s $1 ]] && rm "$1"
}

# List file tags
#   $1 path to file
function list {
    file_exists "$1" || return

    local BASENAME=$(basename "$1")
    local TAG_FILE="$(dirname "$1")/.tags"
    local TAGS=$(read_tags "$TAG_FILE" "$BASENAME")

    array_parse TAGS ,
    array_unique TAGS ,
    array_stringify TAGS ,

    echo "$TAGS"
}

# Copy tags from one file to another
#   $1 path to source file
#   $2 path to destiny file
#
# Error code:
#   5 source has no tags
#
# NOTE:
#   - Also copy the file if destiny does not exist
function copy {
    file_exists "$1" || return

    local BASENAME=$(basename "$2")
    local TAG_FILE="$(dirname "$2")/.tags"
    local TAGS="$(has_tag "$1")"

    [[ -n $TAGS ]] || return 5

    [[ -e $2 ]] || cp -T "$1" "$2"

    add "$2" "$TAGS"
}

# Move tags from one file to another
#   $1 path to source file
#   $2 path to destiny file
#
# Error code:
#   5 source has no tags
#
# NOTE:
#   - Also move the file if destiny does not exist
function move {
    file_exists "$1" || return

    local BASENAME=$(basename "$2")
    local TAG_FILE="$(dirname "$2")/.tags"
    local TAGS="$(has_tag "$1")"

    [[ -n $TAGS ]] || return 5

    remove "$1" "$TAGS"

    [[ -e $2 ]] || mv -T "$1" "$2"

    add "$2" "$TAGS"
}

#
# Main
#

while [[ $# -gt 0 ]]; do
    KEY="$1"
    NEXT="$2"
    shift
    case $KEY in
    -h|--help)
        help
        ;;
    add|filter|find|remove)
        [[ -n $NEXT ]] && shift || help 1

        get_files "$@"
        if [[ ${#FILES[@]} -eq 0 ]]; then
            [[ $KEY == 'find' ]] && FILES=('.') || help 1
        fi

        for FILE in "${FILES[@]}"; do
            $KEY "$FILE" "$NEXT"
        done
        exit
        ;;
    clear|list)
        get_files "$@"
        if [[ ${#FILES[@]} -eq 0 ]]; then
            [[ $KEY == 'clear' ]] && FILES=('.') || help 1
        fi

        for FILE in "${FILES[@]}"; do
            $KEY "$FILE"
        done
        exit
        ;;
    copy|move)
        if [[ $# -eq 2 ]]; then
            $KEY "$1" "$2"
        else
            help 1
        fi
        exit
        ;;
    *)
        errcho "E: unexpected argument '$KEY'"
        exit 2
        ;;
    esac
done

help 1
