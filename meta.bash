#!/bin/bash

META_START_DELIMITER="${PASSWORD_STORE_META_START_DELIMITER:-⊥}"
META_END_DELIMITER="${PASSWORD_STORE_META_END_DELIMITER:-⊤}"
ATTACHMENTS="${PASSWORD_STORE_ATTACHMENTS_DIR:-$PREFIX/.attachments}"
TOTP_KEY_IDENTIFIER="${PASSWORD_STORE_TOTP_KEY_IDENTIFIER:-otp}"
FALLBACK="${PASSWORD_STORE_META_FALLBACK:-none}" # pass/tail/none

cmd_meta_usage() {
  cat <<- EOF
Usage:
    $PROGRAM meta pass-name key-name [--clip,-c]
        Show existing key and optionally put it on the clipboard.
        If the key value is a file then it opens following the mailcap rules
        http://linux.die.net/man/4/mailcap
EOF
  exit 0
}

cmd_meta() {
  local opts clip=0
  opts=$($GETOPT -o c -l clip -n "$PROGRAM" -- "$@")
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -c|--clip) clip=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 ]] && die "Usage: $PROGRAM $COMMAND [--clip,-c] [pass-name]"

  local path="$1"
  local key="$2"
  local passfile="$PREFIX/$path.gpg"
  check_sneaky_paths "$path"

  if [[ ! -f $passfile ]]; then
    die "Error: $path is not in the password store."
  elif [[ -z $key ]]; then
    if [[ $FALLBACK == "pass" ]]; then
      run="$PROGRAM $1"
      if [[ clip -eq 1 ]]; then
        run+=" --clip"
      fi
      eval $run
      exit 0
    elif [[ $FALLBACK == "tail" ]]; then
      : # no-op
    else
      cmd_meta_usage
    fi
  fi

  local secret="$($GPG -d "${GPG_OPTS[@]}" "$passfile")"

  if [[ $(echo -e "$secret" | tr "\n" "\r") =~ (.*$META_START_DELIMITER.*$META_END_DELIMITER.*)$ ]]; then
    meta=$(echo -e "$secret" | tr "\n" "\r" | sed -e "s/.*$META_START_DELIMITER\r\(.*\)$META_END_DELIMITER.*/\1/"  | tr "\r" "\n")
  fi

  secret=$(echo -e "$meta" | yq -r .$key)
  if [[ "$secret" == "null" ]]; then
    die "Error: $key is not in the password file."
  fi
  if [ $? -ne 0 ]; then
    die "$secret"
  elif [[ "$secret" =~ ^\/\/([a-zA-Z0-9]+).gpg$ ]]; then
    local encrypted_file=$(echo "$ATTACHMENTS/$(echo "$secret" | sed -e "s/\/\///")")
    tmpdir #Defines $SECURE_TMPDIR
    local tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXXX")-${path//\//-}"
    $GPG -d -o "$tmp_file" "${GPG_OPTS[@]}" "$encrypted_file" || exit 1
    see $tmp_file
    rm $tmp_file
    exit 0
  elif [[ "$key" == "$TOTP_KEY_IDENTIFIER" ]]; then
    secret=$(oathtool --base32 --totp "$secret")
  fi
  if [[ $clip -eq 0 ]]; then
    echo -e "$secret"
  else
    clip "$secret"
  fi
}

cmd_meta "$@"
