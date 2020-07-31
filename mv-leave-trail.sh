#!/bin/bash

set -euo pipefail


# if $2 is a directory or a symlink to a directory, move $1 inside $2

# if $2 is a directory:
#   if $1 already exists in $2:
#     do nothing and exit 1
#   else:
#     move $1 inside $2
# elif $2 is a symlink:
#   if $2 is a symlink to a directory:
#     move $1 inside $2
#   else:
#     move $1 to $2
# else:
#   if $2 already exists:
#     do nothing and exit 1
#   else:
#     move $1 to $2

# if $1 is a symlink, retarget it to $2 and symlink $2 to the original target

exec &> >(tee -a ~/mv-leave-trail.log)

#set -v
set -x
# factored 2
if [[ -d "$2/." ]]; then
  : '$2 is a dir. move $1 inside $2'
  if [[ -e "$2/$(basename "$1")" ]]; then
    : 'destination already exists'
    false
  else
    if [[ -L "$1" ]]; then
      : '$1 is a link'
      original_link_target="$(readlink "$1")"
      if [[ "$original_link_target" = '/'* ]]; then
        : '$1 link is absolute'
        absolute_path_to_2="$(realpath -s -m "$2/$(basename "$1")")"
        set -x
        mv -i -- "$1" "$2"
        ln -s -- "$absolute_path_to_2" "$1"
        touch -hmr "$absolute_path_to_2" "$1"
      else
        : '$1 link is relative'
        _file_inside_2="$(realpath -s -m "$2/$(basename "$(realpath -s -m "$1")")")"
        target_relative_to_2="$(realpath -m "$1" --relative-to="$2")"
        _2_relative_to_1="$(realpath -m "$2/$(basename "$1")" --relative-to="$(dirname "$1")")"
        set -x
        mv -- "$1" "$1.mv-leave-trail.bak"
        ln -s -- "$target_relative_to_2" "$_file_inside_2"
        ln -s -- "$_2_relative_to_1" "$1"
        touch -hmr "$1.mv-leave-trail.bak" "$_file_inside_2"
        touch -hmr "$1.mv-leave-trail.bak" "$1"
        rm -- "$1.mv-leave-trail.bak"
      fi
    else
      : '$1 is not a link'
      _file_inside_2="$(realpath -s -m "$2/$(basename "$(realpath -s -m "$1")")")"
      _2_relative_to_1="$(realpath -m "$2/$(basename "$1")" --relative-to="$(dirname "$1")")"
      set -x
      mv -i -- "$1" "$2"
      ln -s -- "$_2_relative_to_1" "$1"
      touch -hmr "$_file_inside_2" "$1"
    fi
  fi
else
  if [[ -e "$2" ]]; then
    : 'destination already exists'
    false
  else
    : '$2 is not a dir. move $1 to $2'
    _2_relative_to_1="$(realpath -m "$2" --relative-to="$(dirname "$1")")"
    set -x
    mv -i -- "$1" "$2"
    ln -s -- "$_2_relative_to_1" "$1"
    touch -hmr "$2" "$1"
  fi
fi


