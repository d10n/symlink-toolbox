#!/bin/bash

usage() {
  gather_symlinks="$(basename "$0")"
  [[ -z "$1" ]] && cmd=(cat) || cmd=(awk -v "error=$1" '/^Usage:$/{p=1} p{print} p&&/^$/{print error;exit}')
  "${cmd[@]}" <<EOF
$gather_symlinks: Gather and clean symlinks of current directory.
Recursive by default.

Usage:
  $gather_symlinks [--help]
  $gather_symlinks [-n|--dry-run] [-v|--verbose]
                   [(--recurisve|--non-recursive)]
                   [(--deterministic|--non-deterministic)]

Options:
  -h --help           Show this information
  -n --dry-run        Simulate actions without changing disk
  -v --verbose        Show commands that modify the filesystem
  -r --recursive      [default] Gather symlinks of subdirectories too
  --non-recursive     Do not gather symlinks of subdirectories
  -d --deterministic  [default] Sort files before acting
  --non-deterministic Act immediately as each file is scanned
EOF
}

# parameters
PARAMS=""
DRY_RUN=
VERBOSE=
RECURSIVE=
DETERMINISTIC=

# parse arguments
while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -r|--recursive)
      if [[ "$RECURSIVE" = 0 ]]; then
        usage >&2 'Error: --recursive may not be specified with --non-recursive'
        exit 1
      fi
      RECURSIVE=1
      shift
      ;;
    --non-recursive)
      if [[ "$RECURSIVE" = 1 ]]; then
        usage >&2 'Error: --recursive may not be specified with --non-recursive'
        exit 1
      fi
      RECURSIVE=0
      shift
      ;;
    -d|--deterministic)
      if [[ "$DETERMINISTIC" = 0 ]]; then
        usage >&2 'Error: --deterministic may not be specified with --non-deterministic'
        exit 1
      fi
      DETERMINISTIC=1
      shift
      ;;
    --non-deterministic)
      if [[ "$DETERMINISTIC" = 1 ]]; then
        usage >&2 'Error: --deterministic may not be specified with --non-deterministic'
        exit 1
      fi
      DETERMINISTIC=0
      shift
      ;;
    #-f|--flag-with-argument)
    #  FARG=$2
    #  shift 2
    #  ;;
    #--) # end argument parsing
    #  shift
    #  break
    #  ;;
    -*) # unsupported flags
      usage >&2
      printf >&2 '\nError: Unsupported flag %s\n' "$1"
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done # set positional arguments in their proper place
eval set -- "$PARAMS"

# defaults
DRY_RUN="${DRY_RUN:-0}"
VERBOSE="${VERBOSE:-0}"
RECURSIVE="${RECURSIVE:-1}"
DETERMINISTIC="${DETERMINISTIC:-1}"

exec &> >(tee -a ~/gather-all-symlinks.log)
printf '# Gathering symlinks in %q\n' "$PWD"

set -euo pipefail

if [[ ! "$PWD" = "/media/"* ]]; then
  echo >&2 '# Preventing accidental moves outside of /media'
  exit 1
fi

(( DRY_RUN )) && echo '# Simulating...' || true

# If supporting moves outside /media later:
# relative_base="$(findmnt -n -T . -o TARGET)"
# realpath --relative-to="$PWD" --relative-base="$relative_base"

act() {
  if (( VERBOSE )); then
    printf '%q ' "$@" | sed 's/ $//'
    printf '\n'
  fi
  if ! (( DRY_RUN )); then
    "$@"
  fi
}

pwd_canonical="$(realpath -e "$PWD")"
find . -maxdepth 1 -mindepth 1 -type l -print0 |
if (( DETERMINISTIC )); then sort -z; else cat; fi |
while read -r -d $'\0' find_file; do
# in current directory
  # file: the symlink being processed
  # filetarget: the direct target of the symlink being processed
  # originalfile: the final target of the symlink being processed
  #
  # if file in current directory:
  #   if originalfile in current directory:
  #     if file indirect link to originalfile: relink
  #   if originalfile in other directory: swap

  target_canonical_file="$(readlink -e "$find_file")" || {
    # broken symlink
    continue
  }
  if [[ ! "$target_canonical_file" = "/media/"* ]]; then
    echo >&2 "# Skipping swap outside of /media/: $find_file <---> $target_canonical_file"
    continue
  fi

  find_file_temp="$find_file.gather-symlinks-backup"
  target_canonical_dir="$(dirname "$target_canonical_file")"

  if [[ "$target_canonical_dir" = "$pwd_canonical" ]]; then
    # link to file in current dir
    if [[ "$(readlink "$find_file")" != "$(realpath --relative-to="$PWD" "$find_file")" ]]; then
      # link is indirect
      # relink
      target="$(realpath --relative-to="$PWD" "$target_canonical_file")"
      printf '# relinking %q to %q directly\n' "$find_file" "$target"
      act mv -i -- "$find_file" "$find_file_temp"
      act ln -s -- "$target" "$find_file"
      act touch -hmr "$target_canonical_file" "$find_file"
      act rm -- "$find_file_temp"
    fi
  else
    # link is to file in other dir
    printf '# swapping %q <---> %q\n' "$find_file" "$(realpath --relative-to="$PWD" "$target_canonical_file")"
    act mv -i -- "$find_file" "$find_file_temp"
    act mv -i -- "$target_canonical_file" "$find_file"
    act ln -s -- "$(realpath --relative-to="$target_canonical_dir" "$find_file")" "$target_canonical_file"
    act touch -hmr "$find_file" "$target_canonical_file"
    act rm -- "$find_file_temp"
  fi
done

if (( RECURSIVE )); then
  find . -mindepth 2 -type l -print0 |
  if (( DETERMINISTIC )); then
    sort -z |
    awk '
      BEGIN { RS="\0"; FS="/"; depth=0; }
      {
        if(NF>depth) { depth=NF }
        depth_item_count[NF]++
        depth_items[NF,depth_item_count[NF]]=$0
      }
      END {
        for(d=depth;d>0;d--) {
          for(r=depth_item_count[d];r>0;r--) {
            printf "%s\0",depth_items[d,r]
          }
        }
      }
    '
  else
    cat
  fi |
  while read -r -d $'\0' find_file; do
    target_canonical_file="$(readlink -e "$find_file")" || {
      # broken symlink
      continue
    }

    if [[ ! "$target_canonical_file" = "/media/"* ]]; then
      echo >&2 "# Skipping swap outside of /media/: $find_file <---> $target_canonical_file"
      continue
    fi

    find_file_temp="$find_file.gather-symlinks-backup"
    target_canonical_dir="$(dirname "$target_canonical_file")"

    #if [[ "$(basename "$find_file")" = "d" ]]; then
    #  set -x
    #fi

    # if file in subdirectory:
    #   if originalfile in current directory:
    #     if file indirect link to originalfile: relink
    #   if originalfile in subdirectory:
    #     if filetarget outside of current directory: relink
    #   if originalfile outside current directory: swap
    if [[ "$target_canonical_dir" = "$pwd_canonical" ]]; then
      # originalfile in current directory
      target="$(realpath --relative-to="$(dirname "$find_file")" "$target_canonical_file")"
      if [[ "$(readlink "$find_file")" != "$target" ]]; then
        # link is indirect, relink
        display_target="$(realpath --relative-to="$PWD" "$target_canonical_file")"
        printf '# relinking %q to %q directly\n' "$find_file" "$display_target"
        act mv -i -- "$find_file" "$find_file_temp"
        act ln -s -- "$target" "$find_file"
        act touch -hmr "$target_canonical_file" "$find_file"
        act rm -- "$find_file_temp"
      fi
    elif [[ "$target_canonical_dir" = "$pwd_canonical/"* ]]; then
      # originalfile in subdirectory
      file_target_real="$(realpath -ms "$(dirname "$find_file")/$(readlink "$find_file")")"
      if [[ "$file_target_real" != "$pwd_canonical"* ]]; then
        # file target is outside current directory, relink
        display_target="$(realpath --relative-to="$PWD" "$target_canonical_file")"
        target="$(realpath --relative-to="$(dirname "$find_file")" "$target_canonical_file")"
        printf '# relinking %q to %q directly\n' "$find_file" "$display_target"
        act mv -i -- "$find_file" "$find_file_temp"
        act ln -s -- "$target" "$find_file"
        act touch -hmr "$target_canonical_file" "$find_file"
        act rm -- "$find_file_temp"
      fi
    elif [[ "$(realpath --relative-to="$PWD" "$target_canonical_file")" = '../'* ]]; then
      # originalfile is outside current directory
      # link is to file in other dir
      printf '# swapping %q <---> %q\n' "$find_file" "$(realpath --relative-to="$PWD" "$target_canonical_file")"
      act mv -i -- "$find_file" "$find_file_temp"
      act mv -i -- "$target_canonical_file" "$find_file"
      act ln -s -- "$(realpath --relative-to="$target_canonical_dir" "$find_file" )" "$target_canonical_file"
      act touch -hmr "$find_file" "$target_canonical_file"
      act rm -- "$find_file_temp"
    fi
    #set +x
  done
fi
