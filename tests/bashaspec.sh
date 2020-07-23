#!/bin/bash
# bashaspec - MIT licensed. Copyright 2020 d10n. Feel free to copy around.

# Verbose? true: TAP 12 output; false: dot per test; default false
[[ ${VERBOSE:-false} = true ]] && verbose=1 || verbose=0

# Runs all the test files
run_test_files() {
  while IFS= read -r -d '' cmd; do
    printf '%s\n' "$cmd"
    "$cmd" || code=1
  done < <(find . -executable -type f -name '*-spec.sh' -print0)
  exit "$code"
}

# Runs all the test functions
# hooks: (before|after)_(all|each)
run_test_functions() {
  temp="$(mktemp)"
  exec {FD_W}>"$temp"
  exec {FD_R}<"$temp"
  rm "$temp"
  functions="$(compgen -A function | grep '^test_')"
  echo "1..$(printf '%s\n' "$functions" | wc -l)"
  test_index=0
  failed=0
  run_fn before_all || return
  while IFS= read -r -d $'\n' fn; do
    run_fn before_each || continue
    ((test_index += 1))
    run_fn "$fn" print || failed=1
    run_fn after_each || continue
  done <<<"$functions"
  run_fn after_all || return
  return $failed
}

# Run a function if it exists.
# Buffer its output, and if the function failed, print the output
run_fn() {
  declare -F "$1" >/dev/null || return 0
  [[ "${2:-}" = print ]] && print=1 || print=0
  "$1" >&$FD_W
  status=$?
  IFS= read -r -d '' -u $FD_R out
  if [[ $status -ne 0 ]] && ((print)); then
    echo "not ok $test_index $1"
    echo "# $1 returned $status"
    if [[ -n "$out" ]]; then printf %s "$out" | sed 's/^/# /'; fi
  elif ((print)); then
    echo "ok $test_index $1"
  fi
  return $status
}

# If not verbose, format TAP generated by run_test_functions to a dot summary
format() {
  if ((verbose)); then cat; else
    awk '
    !head&&/1\.\.[0-9]/{sub(/^1../,"");printf "Running %s tests\n",$0}{head=1}
    /^ok/{printf ".";system("");oks++;next}
    /^not ok/{printf "x";system("")not_oks++;fail_body=0;next}
    /^[^#]/{next}
    {sub(/^# /,"")}
    fail_body{sub(/^/,"  ")}
    {fail_lines[fail_line_count++]=$0;fail_body=1}
    END{
      printf "\n%d of %d tests passed\n", oks, oks + not_oks
      if(fail_line_count){print "Failures:"}
      for(i=0;i<fail_line_count;i++){printf "  %s\n",fail_lines[i]}
      if(not_oks){exit 1}
    }'
  fi
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  run_test_files
else
  trap 'run_test_functions | format; exit $?' EXIT
fi