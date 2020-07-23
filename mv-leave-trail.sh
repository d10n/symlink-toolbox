#!/bin/bash

set -euo pipefail


# if $2 is a directory or a symlink to a directory, move $1 inside $2

# if $2 is a directory:
#    move $1 inside $2
# elif $2 is a symlink:
#    if $2 is a symlink to a directory:
#       move $1 inside $2
#    else:
#       move $1 to $2
# else:
#    move $1 to $2

# if $1 is a symlink, retarget it to $2 and symlink $2 to the original target

#set -v
set -x
# factored 2
if [[ -d "$2/." ]]; then
    : '$2 is a dir. move $1 inside $2'
    if [[ -L "$1" ]]; then
        : '$1 is a link'
        original_link_target="$(readlink "$1")"
        if [[ "$original_link_target" = '/'* ]]; then
            : '$1 link is absolute'
            absolute_path_to_2="$(realpath -s -m "$2/$(basename "$1")")"
            set -x
            mv -i -- "$1" "$2"
            ln -s -- "$absolute_path_to_2" "$1"
        else
            : '$1 link is relative'
            target_relative_to_2="$(realpath -m "$1" --relative-to="$2")"
            a2_relative_to_1="$(realpath -m "$2/$(basename "$1")" --relative-to="$(dirname "$1")")"
            set -x
            mv -- "$1" "$1.mv-leave-trail.bak"
            ln -s -- "$target_relative_to_2" "$2"
            ln -s -- "$a2_relative_to_1" "$1"
            rm -- "$1.mv-leave-trail.bak"
        fi
    else
        : '$1 is not a link'
        a2_relative_to_1="$(realpath -m "$2/$(basename "$1")" --relative-to="$(dirname "$1")")"
        set -x
        mv -i -- "$1" "$2"
        ln -s -- "$a2_relative_to_1" "$1"
    fi
else
    : '$2 is not a dir. move $1 to $2'
    a2_relative_to_1="$(realpath -m "$2" --relative-to="$(dirname "$1")")"
    set -x
    mv -i -- "$1" "$2"
    ln -s -- "$a2_relative_to_1" "$1"
fi


