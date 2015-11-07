if [[ ! -o interactive ]]; then
    return
fi

compctl -K _a2obrew a2obrew

_a2obrew() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(a2obrew commands)"
  else
    completions="$(a2obrew completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
