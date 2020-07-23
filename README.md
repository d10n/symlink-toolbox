# symlink toolbox

Committing some ancient scripts that I still use. They might have some details specific to me, but feel free to edit for your use.

The stuff works, but I only recently started to write unit tests. The target platform is Linux, but it should work where readlink and realpath are available.

## mv-leave-trail

Move a file or directory to a destination, and leave a breadcrumb symlink at the original location pointing to the new location.

```
Usage: mv-leave-trail <src> <dst>
```


## gather-symlinks

For each symlink in the current directory: replace the symlink in this directory with the actual file, then place a symlink at the original location pointing to the new location. Recursive by default.

```
Usage:
  gather-symlinks [--help]
  gather-symlinks [-n|--dry-run] [-v|--verbose]
                  [(--recursive|--no-recursive)]
```
