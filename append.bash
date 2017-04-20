#!/bin/bash

META_START_DELIMITER="${PASSWORD_STORE_META_START_DELIMITER:-⊥}"
META_END_DELIMITER="${PASSWORD_STORE_META_END_DELIMITER:-⊤}"

cmd_append_usage() {
  cat <<- EOF
Usage:
    $PROGRAM append pass-name key-name [value|file-path]
        Add a new key/value pair in the document metadata
EOF
  exit 0
}

cmd_append() {
  local path="$1"
  local key="$2"
  local value="$3"
  local passfile="$PREFIX/$path.gpg"
  check_sneaky_paths "$path"

  if [[ -z $key || -z $path ]]; then
    cmd_append_usage
  elif [[ ! -f $passfile ]]; then
    die "Error: $path is not in the password store."
  elif [[ -n $key && -z $value ]]; then
    read -r -p "Write the vaue for $key: " value || exit 1
  fi

  local path="${1%/}"
  check_sneaky_paths "$path"
  mkdir -p -v "$PREFIX/$(dirname "$path")"
  set_gpg_recipients "$(dirname "$path")"+
  local passfile="$PREFIX/$path.gpg"
  set_git "$passfile"

  tmpdir #Defines $SECURE_TMPDIR
  local tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXXX")-${path//\//-}.txt"
  $GPG -d -o "$tmp_file" "${GPG_OPTS[@]}" "$passfile" || exit 1

  secret=$(cat "$tmp_file" | tr "\n" "\r" | sed -e "s/$META_START_DELIMITER\(.*\)$META_END_DELIMITER//"  | tr "\r" "\n")
  if [[ $(cat "$tmp_file" | tr "\n" "\r") =~ (.*$META_START_DELIMITER.*$META_END_DELIMITER.*)$ ]]; then
    meta=$(cat "$tmp_file" | tr "\n" "\r" | sed -e "s/.*$META_START_DELIMITER\r\(.*\)$META_END_DELIMITER.*/\1/"  | tr "\r" "\n")
  fi

  previous_value=$(echo -e "$meta" | yaml r - $key)
  if [ $? -ne 0 ]; then
    die "$previous_value"
  elif [[ "$previous_value" != "null" ]]; then
    yesno "This key exists in the document, would you replace it?"
  fi

  local new_meta=$(echo -e "$meta" | yaml w - $key $value)

  echo -e "$secret\n$META_START_DELIMITER\n$new_meta\n$META_END_DELIMITER" > "$tmp_file"

  while ! $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" "$tmp_file"; do
      yesno "GPG encryption failed. Would you like to try again?"
  done
}

cmd_append "$@"
