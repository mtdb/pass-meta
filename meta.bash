#!/bin/bash

META_START_DELIMITER="${PASSWORD_STORE_META_START_DELIMITER:-⊥}"
META_END_DELIMITER="${PASSWORD_STORE_META_END_DELIMITER:-⊤}"
ATTACHMENTS="${PASSWORD_STORE_ATTACHMENTS_DIR:-$PREFIX/.attachments}"
TOTP_KEY_IDENTIFIER="${PASSWORD_STORE_TOTP_KEY_IDENTIFIER:-otp}"
OS="$(uname)"

# Check required utilities
check_dependencies() {
  for cmd in yq oathtool gpg; do
    if ! command -v $cmd &>/dev/null; then
      echo "Error: Required command $cmd not found." >&2
      exit 1
    fi
  done
}
check_dependencies

cmd_meta_usage() {
  cat <<- EOF
Usage:
    $PROGRAM meta pass-name key-name [--clip,-c]
        Show the key value and optionally copy it to the clipboard.
        If the key value is a file, it will open using the xdg-open command.
EOF
  exit 0
}

# Main function to handle `meta` command
cmd_meta() {
  local opts clip=0  # Default clipboard flag to 0 (not copying to clipboard)

  # Parse command-line options, allowing `--clip` or `-c` for clipboard copy
  opts=$($GETOPT -o c -l clip -n "$PROGRAM" -- "$@")
  local err=$?
  eval set -- "$opts"   

  # Process options
  while true; do case $1 in
    -c|--clip) clip=1; shift ;;
    --) shift; break ;;
  esac done

  # Show usage if there’s an error in parsing
  [[ $err -ne 0 ]] && die "Usage: $PROGRAM $COMMAND [--clip,-c] [pass-name]"

  # Extract arguments
  local path="$1"
  local key="$2"
  local passfile="$PREFIX/$path.gpg"

  # Ensure path does not contain sneaky elements (such as ../)
  check_sneaky_paths "$path"

  # Check if the password file exists
  if [[ ! -f $passfile ]]; then
    die "Error: $path is not in the password store."
  elif [[ -z $key ]]; then
    cmd_meta_usage
  fi

  # Decrypt the password file to retrieve its contents
  local secret="$($GPG -d "${GPG_OPTS[@]}" "$passfile")" || die "Decryption failed"

  # Extract metadata section between delimiters, if present
  if [[ $(echo -e "$secret" | tr "\n" "\r") =~ (.*$META_START_DELIMITER.*$META_END_DELIMITER.*)$ ]]; then
    meta=$(echo -e "$secret" | tr "\n" "\r" | sed -e "s/.*$META_START_DELIMITER\r\(.*\)$META_END_DELIMITER.*/\1/"  | tr "\r" "\n")
  fi

  # Use `yq` to extract the value for the specific key from the metadata
  secret=$(echo -e "$meta" | yq -r .$key)
  if [[ "$secret" == "null" ]]; then
    die "Error: $key is not in the password file." # Key not found in metadata
  fi

  handle_secret "$secret" "$key" "$path" "$clip"
}

handle_secret() {
  local secret="$1"
  local key="$2"
  local path="$3"
  local clip="$4"

  # Manage special cases where the secret start with //, indicating an embedded file, or the key is otp, which signifies a TOTP code
  if [[ "$secret" =~ ^\/\/([a-zA-Z0-9]+).gpg$ ]]; then
    # If key points to an encrypted file (starts with `//`)
    local encrypted_file=$(echo "$ATTACHMENTS/$(echo "$secret" | sed -e "s/\/\///")")
    tmpdir # Set up secure temporary directory ($SECURE_TMPDIR)
    local tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXXX")-${path//\//-}"
    $GPG -d -o "$tmp_file" "${GPG_OPTS[@]}" "$encrypted_file" || exit 1
    open_file "$tmp_file"
    read -p "Press [Enter] after you have finished viewing the file."
    rm $tmp_file
    exit 0
  elif [[ "$key" == "$TOTP_KEY_IDENTIFIER" ]]; then
    # Generate a TOTP code if the key is identified as a TOTP key
    secret=$(oathtool --base32 --totp "$secret")
  fi

  # Output or copy the secret based on `clip` flag
  if [[ $clip -eq 0 ]]; then
    echo -e "$secret"  # Output to terminal
  else
    clip "$secret" # Copy to clipboard
  fi
}

open_file() {
    local file="$1"
    if [[ "$OS" == "Linux" ]]; then
        xdg-open "$file"
    elif [[ "$OS" == "Darwin" ]]; then
      case "$(file -b --mime-type $file | cut -d'/' -f1)" in
        image) open -a Preview $file ;;
        text) open -a TextEdit $file ;;
        application) open -a Preview $file ;;  # pdf
        *) echo "Unsupported filetype." ;;
      esac
    else
        echo "Unsupported OS: $OS"
        exit 1
    fi
}

# Execute `cmd_meta` with all passed arguments
cmd_meta "$@"
