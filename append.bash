#!/bin/bash

META_START_DELIMITER="${PASSWORD_STORE_META_START_DELIMITER:-⊥}"
META_END_DELIMITER="${PASSWORD_STORE_META_END_DELIMITER:-⊤}"
ATTACHMENTS="${PASSWORD_STORE_ATTACHMENTS_DIR:-$PREFIX/.attachments}"

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
  set_git "$passfile"

  if [[ -z $key || -z $path ]]; then
    cmd_append_usage
  elif [[ ! -f $passfile ]]; then
    die "Error: $path is not in the password store."
  elif [[ -n $key && -z $value ]]; then
    read -r -p "Write the vaue for $key: " value || exit 1
  fi

  set_gpg_recipients "$(dirname "$path")"+

  if [[ -f $value ]]; then
    read -r -p "You want to attach the file? [y/N] " response
    if [[ $response == [yY] ]]; then
      local is_file=true
      local file_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
      mkdir -p $ATTACHMENTS
      while ! $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$ATTACHMENTS/$file_name.gpg" "${GPG_OPTS[@]}" "$value"; do
        yesno "GPG encryption failed. Would you like to try again?"
      done
      value="//$file_name.gpg"
    fi
  fi

  tmpdir #Defines $SECURE_TMPDIR
  local tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXXX")-${path//\//-}.txt"
  $GPG -d -o "$tmp_file" "${GPG_OPTS[@]}" "$passfile" || exit 1

  secret=$(cat "$tmp_file" | tr "\n" "\r" | sed -e "s/$META_START_DELIMITER\(.*\)$META_END_DELIMITER//"  | tr "\r" "\n")
  if [[ $(cat "$tmp_file" | tr "\n" "\r") =~ (.*$META_START_DELIMITER.*$META_END_DELIMITER.*)$ ]]; then
    meta=$(cat "$tmp_file" | tr "\n" "\r" | sed -e "s/.*$META_START_DELIMITER\r\(.*\)$META_END_DELIMITER.*/\1/"  | tr "\r" "\n")
  fi

  if [[ ! $meta ]]; then
    meta="null"
  fi

  previous_value=$(echo -e "$meta" | yq -r .$key)

  if [ $? -ne 0 ]; then
    die "$previous_value"
  elif [[ "$previous_value" != "null" ]]; then
    read -r -p "This key exists in the document, would you replace it? [y/N] " response
    if [[ $response != [yY] ]]; then
      [[ $is_file ]] && rm "$ATTACHMENTS/$file_name.gpg"
      exit 1
    fi

    if [[ $is_file ]]; then
      local old_path=$(echo "$ATTACHMENTS/$(echo "$previous_value" | sed -e "s/\/\///")")
      rm $old_path
      if [[ -n $INNER_GIT_DIR && ! -e $old_path ]]; then
        git -C "$INNER_GIT_DIR" rm -qr "$old_path"
      fi
    fi
  fi

  local new_meta=$(echo -e "$meta" | yq -y '.'$key'="'$value'"')

  echo -e "$secret\n$META_START_DELIMITER\n$new_meta\n$META_END_DELIMITER" > "$tmp_file"

  while ! $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" "$tmp_file"; do
      yesno "GPG encryption failed. Would you like to try again?"
  done
  if [[ is_file ]]; then
    git_add_file "$ATTACHMENTS/$file_name.gpg" "Add given attachment for $path to store."
  fi
  git_add_file "$passfile" "Edit metadata for $path."
}

cmd_append "$@"
