#!/bin/bash
set -euo pipefail
main_dir="$(pwd)"
. ./bashaspec.sh

before_each() {
  rm -rf test-gather-symlinks
  mkdir -p test-gather-symlinks
  pushd test-gather-symlinks
  testing_dir_abs_path="$(pwd -P)"

  mkdir ./test1
  echo ./test1/c >./test1/c
  ln -s c ./test1/a
  mkdir ./test1/dir1
  echo ./test1/dir1/foo >./test1/dir1/foo
  echo ./test1/dir1/quux >./test1/dir1/quux
  ln -s ../dir3/baz ./test1/dir1/baz
  ln -s ../dir2/bar ./test1/dir1/bar
  ln -s ../../test2/d ./test1/dir1/d
  mkdir ./test1/dir2
  echo ./test1/dir2/bar >./test1/dir2/bar
  ln -s ../../test2/j ./test1/dir2/j
  ln -s ../dir3/baz ./test1/dir2/baz
  ln -s ../dir1/foo ./test1/dir2/foo
  ln -s ../../test2/e ./test1/dir2/e
  mkdir ./test1/dir3
  echo ./test1/dir3/baz >./test1/dir3/baz
  ln -s ../f ./test1/dir3/f
  ln -s ../dir2/bar ./test1/dir3/bar
  ln -s ../dir1/foo ./test1/dir3/foo
  ln -s ../../test2/a ./test1/dir3/i
  ln -s ../../test2/d ./test1/dir3/d
  ln -s ../../test2/a\ space ./test1/dir3/a\ space
  ln -s ../../test2/quux ./test1/dir3/quux
  ln -s dir1/foo ./test1/foo
  ln -s dir2/baz ./test1/baz
  echo ./test1/f >./test1/f
  ln -s a ./test1/g
  ln -s ../test2/a ./test1/b
  ln -s ../test2/d ./test1/d
  mkdir ./test2
  ln -s a\ space ./test2/a
  echo ./test2/d >./test2/d
  echo ./test2/e >./test2/e
  echo ./test2/j >./test2/j
  ln -s ../test1/c ./test2/a\ space
  ln -s ../test1/dir1/quux ./test2/quux

  before_files="$(find . -exec ls -ogdp --time-style=+ '{}' + | sed 's/1 [^.]*//')"

  # Original state
  cat <<EOF >/dev/null
drwxr-xr-x ./
drwxr-xr-x ./test1/
lrwxrwxrwx ./test1/a -> c
lrwxrwxrwx ./test1/b -> ../test2/a
lrwxrwxrwx ./test1/baz -> dir2/baz
-rw-r--r-- ./test1/c
lrwxrwxrwx ./test1/d -> ../test2/d
drwxr-xr-x ./test1/dir1/
lrwxrwxrwx ./test1/dir1/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir1/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir1/d -> ../../test2/d
-rw-r--r-- ./test1/dir1/foo
-rw-r--r-- ./test1/dir1/quux
drwxr-xr-x ./test1/dir2/
-rw-r--r-- ./test1/dir2/bar
lrwxrwxrwx ./test1/dir2/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir2/e -> ../../test2/e
lrwxrwxrwx ./test1/dir2/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir2/j -> ../../test2/j
drwxr-xr-x ./test1/dir3/
lrwxrwxrwx ./test1/dir3/a space -> ../../test2/a space
lrwxrwxrwx ./test1/dir3/bar -> ../dir2/bar
-rw-r--r-- ./test1/dir3/baz
lrwxrwxrwx ./test1/dir3/d -> ../../test2/d
lrwxrwxrwx ./test1/dir3/f -> ../f
lrwxrwxrwx ./test1/dir3/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir3/i -> ../../test2/a
lrwxrwxrwx ./test1/dir3/quux -> ../../test2/quux
-rw-r--r-- ./test1/f
lrwxrwxrwx ./test1/foo -> dir1/foo
lrwxrwxrwx ./test1/g -> a
drwxr-xr-x ./test2/
lrwxrwxrwx ./test2/a -> a space
lrwxrwxrwx ./test2/a space -> ../test1/c
-rw-r--r-- ./test2/d
-rw-r--r-- ./test2/e
-rw-r--r-- ./test2/j
lrwxrwxrwx ./test2/quux -> ../test1/dir1/quux
EOF
}

after_each() {
  popd
}

after_all() { :;
  rm -rf test-gather-symlinks
}

gather_symlinks_fn() {
  "$main_dir/../gather-symlinks.sh" "$@"
}

compare_output_and_state() {
  out="$1"
  expected_out="$2"
  expected_after_files="$3"
  after_files="$(find . -exec ls -ogdp --time-style=+ '{}' + | sed 's/1 [^.]*//')"

#  echo "$out"
#  echo "$after_files"

  # Compare output
  diff <(printf %s "$out") <(printf %s "$expected_out") || return 99
  # All file paths still exist
  diff <(printf %s "$before_files" | sed 's/^[^.]*//;s/ -> .*$//') \
       <(printf %s "$after_files" | sed 's/^[^.]*//;s/ -> .*$//') || return 97
  # Compare full state
  diff <(printf %s "$after_files") <(printf %s "$expected_after_files") || return 96

  broken_links="$(find . -xtype l)"
  # No broken links
  [[ -z "$broken_links" ]] || return 95
}

test_gather_root_does_nothing() {
  out="$(gather_symlinks_fn -v)"
  expected_out="# Gathering symlinks in ${testing_dir_abs_path}"
  expected_after_files="$before_files"
  compare_output_and_state "$out" "$expected_out" "$expected_after_files"
}

test_gather_test1_recursive_updates_subdirs() {
  cd test1
  out="$(gather_symlinks_fn)"
  cd ..
  expected_out="$(
    cat <<EOF
# Gathering symlinks in ${testing_dir_abs_path}/test1
# relinking ./b to c directly
# swapping ./baz <---> dir3/baz
# swapping ./d <---> ../test2/d
# swapping ./foo <---> dir1/foo
# relinking ./g to c directly
# relinking ./dir3/quux to dir1/quux directly
# relinking ./dir3/i to c directly
# relinking ./dir3/foo to foo directly
# relinking ./dir3/d to d directly
# relinking ./dir3/a\ space to c directly
# swapping ./dir2/j <---> ../test2/j
# relinking ./dir2/foo to foo directly
# swapping ./dir2/e <---> ../test2/e
# relinking ./dir2/baz to baz directly
# relinking ./dir1/d to d directly
# relinking ./dir1/baz to baz directly
EOF
  )"
  expected_after_files="$(
    cat <<EOF
drwxr-xr-x ./
drwxr-xr-x ./test1/
lrwxrwxrwx ./test1/a -> c
lrwxrwxrwx ./test1/b -> c
-rw-r--r-- ./test1/baz
-rw-r--r-- ./test1/c
-rw-r--r-- ./test1/d
drwxr-xr-x ./test1/dir1/
lrwxrwxrwx ./test1/dir1/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir1/baz -> ../baz
lrwxrwxrwx ./test1/dir1/d -> ../d
lrwxrwxrwx ./test1/dir1/foo -> ../foo
-rw-r--r-- ./test1/dir1/quux
drwxr-xr-x ./test1/dir2/
-rw-r--r-- ./test1/dir2/bar
lrwxrwxrwx ./test1/dir2/baz -> ../baz
-rw-r--r-- ./test1/dir2/e
lrwxrwxrwx ./test1/dir2/foo -> ../foo
-rw-r--r-- ./test1/dir2/j
drwxr-xr-x ./test1/dir3/
lrwxrwxrwx ./test1/dir3/a space -> ../c
lrwxrwxrwx ./test1/dir3/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir3/baz -> ../baz
lrwxrwxrwx ./test1/dir3/d -> ../d
lrwxrwxrwx ./test1/dir3/f -> ../f
lrwxrwxrwx ./test1/dir3/foo -> ../foo
lrwxrwxrwx ./test1/dir3/i -> ../c
lrwxrwxrwx ./test1/dir3/quux -> ../dir1/quux
-rw-r--r-- ./test1/f
-rw-r--r-- ./test1/foo
lrwxrwxrwx ./test1/g -> c
drwxr-xr-x ./test2/
lrwxrwxrwx ./test2/a -> a space
lrwxrwxrwx ./test2/a space -> ../test1/c
lrwxrwxrwx ./test2/d -> ../test1/d
lrwxrwxrwx ./test2/e -> ../test1/dir2/e
lrwxrwxrwx ./test2/j -> ../test1/dir2/j
lrwxrwxrwx ./test2/quux -> ../test1/dir1/quux
EOF
  )"

  compare_output_and_state "$out" "$expected_out" "$expected_after_files" || return $?

  # No symlink should escape the directory gather-symlinks was run in
  ! printf %s "$after_files" | grep './test1/.*-> \.\./test' || return 3
}

test_gather_test1_non_recursive_only_updates_current_dir() {
  cd test1
  out="$(gather_symlinks_fn --non-recursive)"
  cd ..
  expected_out="$(
    cat <<EOF
# Gathering symlinks in ${testing_dir_abs_path}/test1
# relinking ./b to c directly
# swapping ./baz <---> dir3/baz
# swapping ./d <---> ../test2/d
# swapping ./foo <---> dir1/foo
# relinking ./g to c directly
EOF
  )"
  expected_after_files="$(
    cat <<EOF
drwxr-xr-x ./
drwxr-xr-x ./test1/
lrwxrwxrwx ./test1/a -> c
lrwxrwxrwx ./test1/b -> c
-rw-r--r-- ./test1/baz
-rw-r--r-- ./test1/c
-rw-r--r-- ./test1/d
drwxr-xr-x ./test1/dir1/
lrwxrwxrwx ./test1/dir1/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir1/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir1/d -> ../../test2/d
lrwxrwxrwx ./test1/dir1/foo -> ../foo
-rw-r--r-- ./test1/dir1/quux
drwxr-xr-x ./test1/dir2/
-rw-r--r-- ./test1/dir2/bar
lrwxrwxrwx ./test1/dir2/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir2/e -> ../../test2/e
lrwxrwxrwx ./test1/dir2/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir2/j -> ../../test2/j
drwxr-xr-x ./test1/dir3/
lrwxrwxrwx ./test1/dir3/a space -> ../../test2/a space
lrwxrwxrwx ./test1/dir3/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir3/baz -> ../baz
lrwxrwxrwx ./test1/dir3/d -> ../../test2/d
lrwxrwxrwx ./test1/dir3/f -> ../f
lrwxrwxrwx ./test1/dir3/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir3/i -> ../../test2/a
lrwxrwxrwx ./test1/dir3/quux -> ../../test2/quux
-rw-r--r-- ./test1/f
-rw-r--r-- ./test1/foo
lrwxrwxrwx ./test1/g -> c
drwxr-xr-x ./test2/
lrwxrwxrwx ./test2/a -> a space
lrwxrwxrwx ./test2/a space -> ../test1/c
lrwxrwxrwx ./test2/d -> ../test1/d
-rw-r--r-- ./test2/e
-rw-r--r-- ./test2/j
lrwxrwxrwx ./test2/quux -> ../test1/dir1/quux
EOF
  )"

  compare_output_and_state "$out" "$expected_out" "$expected_after_files" || return $?

  # All file paths still exist
  diff <(printf %s "$before_files" | sed 's/^[^.]*//;s/ -> .*$//') \
       <(printf %s "$after_files" | sed 's/^[^.]*//;s/ -> .*$//') || return 4
}

test_gather_test2() {
  cd test2
  out="$(gather_symlinks_fn)"
  cd ..
  expected_out="$(
    cat <<EOF
# Gathering symlinks in ${testing_dir_abs_path}/test2
# swapping ./a <---> ../test1/c
# relinking ./a\ space to a directly
# swapping ./quux <---> ../test1/dir1/quux
EOF
  )"
  expected_after_files="$(
    cat <<EOF
drwxr-xr-x ./
drwxr-xr-x ./test1/
lrwxrwxrwx ./test1/a -> c
lrwxrwxrwx ./test1/b -> ../test2/a
lrwxrwxrwx ./test1/baz -> dir2/baz
lrwxrwxrwx ./test1/c -> ../test2/a
lrwxrwxrwx ./test1/d -> ../test2/d
drwxr-xr-x ./test1/dir1/
lrwxrwxrwx ./test1/dir1/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir1/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir1/d -> ../../test2/d
-rw-r--r-- ./test1/dir1/foo
lrwxrwxrwx ./test1/dir1/quux -> ../../test2/quux
drwxr-xr-x ./test1/dir2/
-rw-r--r-- ./test1/dir2/bar
lrwxrwxrwx ./test1/dir2/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir2/e -> ../../test2/e
lrwxrwxrwx ./test1/dir2/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir2/j -> ../../test2/j
drwxr-xr-x ./test1/dir3/
lrwxrwxrwx ./test1/dir3/a space -> ../../test2/a space
lrwxrwxrwx ./test1/dir3/bar -> ../dir2/bar
-rw-r--r-- ./test1/dir3/baz
lrwxrwxrwx ./test1/dir3/d -> ../../test2/d
lrwxrwxrwx ./test1/dir3/f -> ../f
lrwxrwxrwx ./test1/dir3/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir3/i -> ../../test2/a
lrwxrwxrwx ./test1/dir3/quux -> ../../test2/quux
-rw-r--r-- ./test1/f
lrwxrwxrwx ./test1/foo -> dir1/foo
lrwxrwxrwx ./test1/g -> a
drwxr-xr-x ./test2/
-rw-r--r-- ./test2/a
lrwxrwxrwx ./test2/a space -> a
-rw-r--r-- ./test2/d
-rw-r--r-- ./test2/e
-rw-r--r-- ./test2/j
-rw-r--r-- ./test2/quux
EOF
  )"

  compare_output_and_state "$out" "$expected_out" "$expected_after_files" || return $?

  # No symlink should escape the directory gather-symlinks was run in
  ! printf %s "$after_files" | grep './test2/.*-> \.\./test' || return 3
}

test_gather_test1_dry_run_updates_no_files() {
  cd test1
  out="$(gather_symlinks_fn --verbose --dry-run)"
  cd ..
  expected_out="$(
    cat <<EOF
# Gathering symlinks in ${testing_dir_abs_path}/test1
# Simulating...
# relinking ./b to c directly
mv -i -- ./b ./b.gather-symlinks-backup
ln -s -- c ./b
touch -hmr ${testing_dir_abs_path}/test1/c ./b
rm -- ./b.gather-symlinks-backup
# swapping ./baz <---> dir3/baz
mv -i -- ./baz ./baz.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/dir3/baz ./baz
ln -s -- baz ${testing_dir_abs_path}/test1/dir3/baz
touch -hmr ./baz ${testing_dir_abs_path}/test1/dir3/baz
rm -- ./baz.gather-symlinks-backup
# swapping ./d <---> ../test2/d
mv -i -- ./d ./d.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test2/d ./d
ln -s -- d ${testing_dir_abs_path}/test2/d
touch -hmr ./d ${testing_dir_abs_path}/test2/d
rm -- ./d.gather-symlinks-backup
# swapping ./foo <---> dir1/foo
mv -i -- ./foo ./foo.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/dir1/foo ./foo
ln -s -- foo ${testing_dir_abs_path}/test1/dir1/foo
touch -hmr ./foo ${testing_dir_abs_path}/test1/dir1/foo
rm -- ./foo.gather-symlinks-backup
# relinking ./g to c directly
mv -i -- ./g ./g.gather-symlinks-backup
ln -s -- c ./g
touch -hmr ${testing_dir_abs_path}/test1/c ./g
rm -- ./g.gather-symlinks-backup
# relinking ./dir3/quux to dir1/quux directly
mv -i -- ./dir3/quux ./dir3/quux.gather-symlinks-backup
ln -s -- ../dir1/quux ./dir3/quux
touch -hmr ${testing_dir_abs_path}/test1/dir1/quux ./dir3/quux
rm -- ./dir3/quux.gather-symlinks-backup
# relinking ./dir3/i to c directly
mv -i -- ./dir3/i ./dir3/i.gather-symlinks-backup
ln -s -- ../c ./dir3/i
touch -hmr ${testing_dir_abs_path}/test1/c ./dir3/i
rm -- ./dir3/i.gather-symlinks-backup
# swapping ./dir3/d <---> ../test2/d
mv -i -- ./dir3/d ./dir3/d.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test2/d ./dir3/d
ln -s -- d ${testing_dir_abs_path}/test2/d
touch -hmr ./dir3/d ${testing_dir_abs_path}/test2/d
rm -- ./dir3/d.gather-symlinks-backup
# relinking ./dir3/a\ space to c directly
mv -i -- ./dir3/a\ space ./dir3/a\ space.gather-symlinks-backup
ln -s -- ../c ./dir3/a\ space
touch -hmr ${testing_dir_abs_path}/test1/c ./dir3/a\ space
rm -- ./dir3/a\ space.gather-symlinks-backup
# swapping ./dir2/j <---> ../test2/j
mv -i -- ./dir2/j ./dir2/j.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test2/j ./dir2/j
ln -s -- j ${testing_dir_abs_path}/test2/j
touch -hmr ./dir2/j ${testing_dir_abs_path}/test2/j
rm -- ./dir2/j.gather-symlinks-backup
# swapping ./dir2/e <---> ../test2/e
mv -i -- ./dir2/e ./dir2/e.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test2/e ./dir2/e
ln -s -- e ${testing_dir_abs_path}/test2/e
touch -hmr ./dir2/e ${testing_dir_abs_path}/test2/e
rm -- ./dir2/e.gather-symlinks-backup
# swapping ./dir1/d <---> ../test2/d
mv -i -- ./dir1/d ./dir1/d.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test2/d ./dir1/d
ln -s -- d ${testing_dir_abs_path}/test2/d
touch -hmr ./dir1/d ${testing_dir_abs_path}/test2/d
rm -- ./dir1/d.gather-symlinks-backup
EOF
  )"
  expected_after_files="$before_files"

  compare_output_and_state "$out" "$expected_out" "$expected_after_files" || return $?
}


test_gather_test1_dir3() {
  cd test1/dir3
  out="$(gather_symlinks_fn -v)"
  cd ../..
  expected_out="$(
    cat <<EOF
# Gathering symlinks in ${testing_dir_abs_path}/test1/dir3
# swapping ./a\ space <---> ../c
mv -i -- ./a\ space ./a\ space.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/c ./a\ space
ln -s -- dir3/a\ space ${testing_dir_abs_path}/test1/c
touch -hmr ./a\ space ${testing_dir_abs_path}/test1/c
rm -- ./a\ space.gather-symlinks-backup
# swapping ./bar <---> ../dir2/bar
mv -i -- ./bar ./bar.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/dir2/bar ./bar
ln -s -- ../dir3/bar ${testing_dir_abs_path}/test1/dir2/bar
touch -hmr ./bar ${testing_dir_abs_path}/test1/dir2/bar
rm -- ./bar.gather-symlinks-backup
# swapping ./d <---> ../../test2/d
mv -i -- ./d ./d.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test2/d ./d
ln -s -- ../test1/dir3/d ${testing_dir_abs_path}/test2/d
touch -hmr ./d ${testing_dir_abs_path}/test2/d
rm -- ./d.gather-symlinks-backup
# swapping ./f <---> ../f
mv -i -- ./f ./f.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/f ./f
ln -s -- dir3/f ${testing_dir_abs_path}/test1/f
touch -hmr ./f ${testing_dir_abs_path}/test1/f
rm -- ./f.gather-symlinks-backup
# swapping ./foo <---> ../dir1/foo
mv -i -- ./foo ./foo.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/dir1/foo ./foo
ln -s -- ../dir3/foo ${testing_dir_abs_path}/test1/dir1/foo
touch -hmr ./foo ${testing_dir_abs_path}/test1/dir1/foo
rm -- ./foo.gather-symlinks-backup
# relinking ./i to a\ space directly
mv -i -- ./i ./i.gather-symlinks-backup
ln -s -- a\ space ./i
touch -hmr ${testing_dir_abs_path}/test1/dir3/a\ space ./i
rm -- ./i.gather-symlinks-backup
# swapping ./quux <---> ../dir1/quux
mv -i -- ./quux ./quux.gather-symlinks-backup
mv -i -- ${testing_dir_abs_path}/test1/dir1/quux ./quux
ln -s -- ../dir3/quux ${testing_dir_abs_path}/test1/dir1/quux
touch -hmr ./quux ${testing_dir_abs_path}/test1/dir1/quux
rm -- ./quux.gather-symlinks-backup
EOF
  )"
  expected_after_files="$(
    cat <<EOF
drwxr-xr-x ./
drwxr-xr-x ./test1/
lrwxrwxrwx ./test1/a -> c
lrwxrwxrwx ./test1/b -> ../test2/a
lrwxrwxrwx ./test1/baz -> dir2/baz
lrwxrwxrwx ./test1/c -> dir3/a space
lrwxrwxrwx ./test1/d -> ../test2/d
drwxr-xr-x ./test1/dir1/
lrwxrwxrwx ./test1/dir1/bar -> ../dir2/bar
lrwxrwxrwx ./test1/dir1/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir1/d -> ../../test2/d
lrwxrwxrwx ./test1/dir1/foo -> ../dir3/foo
lrwxrwxrwx ./test1/dir1/quux -> ../dir3/quux
drwxr-xr-x ./test1/dir2/
lrwxrwxrwx ./test1/dir2/bar -> ../dir3/bar
lrwxrwxrwx ./test1/dir2/baz -> ../dir3/baz
lrwxrwxrwx ./test1/dir2/e -> ../../test2/e
lrwxrwxrwx ./test1/dir2/foo -> ../dir1/foo
lrwxrwxrwx ./test1/dir2/j -> ../../test2/j
drwxr-xr-x ./test1/dir3/
-rw-r--r-- ./test1/dir3/a space
-rw-r--r-- ./test1/dir3/bar
-rw-r--r-- ./test1/dir3/baz
-rw-r--r-- ./test1/dir3/d
-rw-r--r-- ./test1/dir3/f
-rw-r--r-- ./test1/dir3/foo
lrwxrwxrwx ./test1/dir3/i -> a space
-rw-r--r-- ./test1/dir3/quux
lrwxrwxrwx ./test1/f -> dir3/f
lrwxrwxrwx ./test1/foo -> dir1/foo
lrwxrwxrwx ./test1/g -> a
drwxr-xr-x ./test2/
lrwxrwxrwx ./test2/a -> a space
lrwxrwxrwx ./test2/a space -> ../test1/c
lrwxrwxrwx ./test2/d -> ../test1/dir3/d
-rw-r--r-- ./test2/e
-rw-r--r-- ./test2/j
lrwxrwxrwx ./test2/quux -> ../test1/dir1/quux
EOF
  )"

  compare_output_and_state "$out" "$expected_out" "$expected_after_files" || return $?

  # All file paths still exist
  diff <(printf %s "$before_files" | sed 's/^[^.]*//;s/ -> .*$//') \
       <(printf %s "$after_files" | sed 's/^[^.]*//;s/ -> .*$//') || return 4
}
