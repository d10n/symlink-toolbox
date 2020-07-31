#!/bin/bash
set -o pipefail
cd "$(dirname "$0")" || exit 1

mv-leave-trail() {
  ../../mv-leave-trail.sh "$@" 2>&1
}

after_all() { :
  rm -rf test-mv-leave-trail
}

before_each() { :
  rm -rf test-mv-leave-trail
  mkdir -p test-mv-leave-trail
  pushd test-mv-leave-trail
  mkdir 'test1'
  mkdir 'test1/sub dir1'
  touch 'test1/file1'
  touch 'test1/sub dir1/space file1'
  mkdir 'test2'
  mkdir 'test2/sub dir2'
  touch 'test2/sub dir2/space file2'
  ln -s 'bad target1' 'test1/bad symlink1'
  ln -s '../test2/sub dir2/space file2' 'test1/space file2'
}
after_each() { :
  popd
}

test_mv_file_to_dir() { :
  touch a
  src='a'
  dst='test1/a'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # src is a link
  [[ ! -L "$dst" && -f "$dst" ]] || return 2 # dst is a file
  [[ "$src" -ef "$dst" ]] || return 3 # a links to dst
  [[ $(readlink "$src") != '/'* ]] || return 4 # src is not a link to an absolute path
}
test_mv_dir_to_file() { :
  src='test1'
  dst='test3'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # src is a link
  [[ ! -L "$dst" && -d "$dst" ]] || return 2 # dst is a file
  [[ "$src" -ef "$dst" ]] || return 3 # a links to dst
  [[ $(readlink "$src") != '/'* ]] || return 4 # src is not a link to an absolute path
}
test_mv_dir_to_dir() { :
  mkdir test3
  src='test1'
  dst='test3'
  dst_result='test3/test1'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # test1 is a link
  [[ ! -L "$dst_result" && -d "$dst_result" ]] || return 2 # test3 is a dir
  [[ "$src" -ef "$dst_result" ]] || return 3 # test1 links to test3
  [[ $(readlink "$src") != '/'* ]] || return 4 # test1 is not a link to an absolute path
  true
}
test_mv_file_to_symdir() { :
  touch a
  ln -s test1 test3
  src='a'
  dst='test3'
  dst_result='test3/a'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # a is a link
  [[ ! -L "$dst_result" && -f "$dst_result" ]] || return 2 # dst_result is a file
  [[ "$src" -ef "$dst_result" ]] || return 3 # src links to dst_result
  [[ $(readlink "$src") != '/'* ]] || return 4 # src is not a link to an absolute path
}
test_mv_file_to_file() { :
  src='test1/sub dir1/space file1'
  dst='test2/sub dir2/space file1a'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # src is a link
  [[ ! -L "$dst" && -f "$dst" ]] || return 2 # dst is a file
  [[ "$src" -ef "$dst" ]] || return 3 # a links to dst
  [[ $(readlink "$src") != '/'* ]] || return 4 # src is not a link to an absolute path
}
test_mv_file_to_symfile() { :;
  src='test1/sub dir1/space file1'
  dst='test2/sub dir2/space file2a'
  ln -s 'space file2' "$dst"
  yes no | mv-leave-trail "$src" "$dst"
  [[ "$?" -eq 0 ]] && return 1 # dst already existed, should fail
  true
}
test_mv_dir_to_symfile() { :;
  ln -s 'space file2' 'test2/sub dir2/space file2a'
  src='test1/sub dir1'
  dst='test2/sub dir2/space file2a'
  yes no | mv-leave-trail "$src" "$dst"
  [[ "$?" -eq 0 ]] && return 1 # dst already existed, should fail
  true
}
test_mv_dir_to_symdir() { :
  mkdir test3
  ln -s '../test2/sub dir2' 'test3/sub dir2'
  src='test1/sub dir1'
  dst='test3/sub dir2'
  dst_result='test2/sub dir2/sub dir1'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # test1 is a link
  [[ ! -L "$dst_result" && -d "$dst_result" ]] || return 2 # test3 is a dir
  [[ "$src" -ef "$dst_result" ]] || return 3 # test1 links to test3
  [[ $(readlink "$src") != '/'* ]] || return 4 # test1 is not a link to an absolute path
}
test_mv_dir_to_badsym() { :;
  ln -s 'space file3' 'test2/sub dir2/space file2a'
  src='test1/sub dir1'
  dst='test2/sub dir2/space file2a'
  yes no | mv-leave-trail "$src" "$dst"
  [[ "$?" -eq 0 ]] && return 1 # dst already existed, should fail
  true
}
test_mv_file_to_badsym() { :;
  ln -s 'space file3' 'test2/sub dir2/space file2a'
  src='test1/sub dir1/space file1'
  dst='test2/sub dir2/space file2a'
  yes no | mv-leave-trail "$src" "$dst"
  [[ "$?" -eq 0 ]] && return 1 # dst already existed, should fail
  true
}
test_mv_relsymdir_to_symdir() { :
  mkdir 'test3'
  mkdir 'test3/sub dir3'
  ln -s '../test2/sub dir2' 'test3/sub dir2'
  ln -s '../test1/sub dir1' 'test2/sub dir1a'

  src='test3/sub dir2'
  dst='test2/sub dir1a'
  dst_result='test1/sub dir1/sub dir2'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # src is a link
  [[ -L "$dst_result" && -d "$dst_result" ]] || return 2 # dst_result is a symlink to a dir
  [[ -L "$dst/sub dir2" && -d "$dst/sub dir2" ]] || return 3 # dst/sub dir2 is a dir
  [[ "$src" -ef "$dst_result" ]] || return 4 # src links to test3
  [[ "$src" -ef "$dst/sub dir2" ]] || return 5 # src links to test3
  [[ $(readlink "$src") != '/'* ]] || return 6 # src is not a link to an absolute path
}
test_mv_abssymdir_to_symdir() { :
  mkdir 'test3'
  mkdir 'test3/sub dir3'
  ln -s "$(realpath -e 'test2/sub dir2')" 'test3/sub dir2'
  ln -s '../test1/sub dir1' 'test2/sub dir1a'

  src='test3/sub dir2'
  dst='test2/sub dir1a'
  dst_result='test1/sub dir1/sub dir2'
  mv-leave-trail "$src" "$dst"
  [[ -L "$src" ]] || return 1 # src is a link
  [[ -L "$dst_result" && -d "$dst_result" ]] || return 2 # dst_result is a symlink to a dir
  [[ -L "$dst/sub dir2" && -d "$dst/sub dir2" ]] || return 3 # dst/sub dir2 is a dir
  [[ "$src" -ef "$dst_result" ]] || return 4 # src links to test3
  [[ "$src" -ef "$dst/sub dir2" ]] || return 5 # src links to test3
  [[ $(readlink "$src") = '/'* ]] || return 6 # src is a link to an absolute path
  [[ $(readlink "$dst") != '/'* ]] || return 7 # src remains a link to a relative path
}

. ./bashaspec.sh
