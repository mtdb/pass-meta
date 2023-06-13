# pass-meta

A [pass](https://www.passwordstore.org/) extension that provides a schema to organize the metadata in yaml format, the idea is to have a valid yaml document within `⊥` and `⊤` delimiters, it is not relevant the content out of them, then you can edit the document following the yaml rules inside the delimiters or write without rules outside them.

## Features

  - Add and copy metadata in yaml format
  - File attachment support
  - Basic TOTP support

## Requerements

  - pass 1.7.0 or later for extension support
  - oathtool for TOTP support
  - yq from https://pypi.org/project/yq/

To install the requirements in Ubuntu or MacOS systems are:

```
apt install oathtool yq
```

```
brew install oath-toolkit yq
```

## Ussage

```
Usage:
    pass append pass-name key-name [value|file-path]
        Add a new key/value pair in the document metadata
    pass meta pass-name key-name [--clip,-c]
        Show existing key and optionally put it on the clipboard.
        If the key value is a file then it opens following the mailcap rules
        http://linux.die.net/man/4/mailcap
```

## Example

`pass Super/Secret`

```
S3cr3tP4ssw0rd
this is a secret note
```

`pass append Super/Secret username mtdb`

`pass Super/Secret`

```
S3cr3tP4ssw0rd
this is a secret note
⊥
username: mtdb
⊤
```

`pass meta Super/Secret username`  _(use -c to copy instead show)_

```
mtdb
```

`pass append Super/Secret secretimage /secret/image.png`  _(the command detects if the file exists before executing)_

`pass Super/Secret`

```
S3cr3tP4ssw0rd
this is a secret note
⊥
username: mtdb
secretimage: //sFDuY8jez8H2rful.gpg
⊤
```

`pass meta Super/Secret secretimage` _(show the image)_

The command shows the file following the mailcap rules.

`pass append Super/Secret otp BASE32SECRET3232`

`pass Super/Secret`

```
S3cr3tP4ssw0rd
this is a secret note
⊥
username: mtdb
secretimage: //sFDuY8jez8H2rful.gpg
otp: BASE32SECRET3232
⊤
```

`pass meta Super/Secret otp` _(assume base32 standard totp secret)_

```
456123
```

## Options

Set these enviroment variables to configure the command behavior

- PASSWORD_STORE_META_START_DELIMITER _(default: ⊥)_
- PASSWORD_STORE_META_END_DELIMITER _(default: ⊤)_
- PASSWORD_STORE_ATTACHMENTS_DIR _(default: $PREFIX/.attachments)_
- PASSWORD_STORE_TOTP_KEY_IDENTIFIER _(default: otp)_
- PASSWORD_STORE_META_FALLBACK _(default: none)_ valid values: **pass**, **tail** or **none**

## Installation
- Enable password-store extensions by setting `PASSWORD_STORE_ENABLE_EXTENSIONS=true`
- Copy append.bash and meta.bash into `~/password-store/.extensions`

Note: make sure the `yq` and `oathtool` commands are available in your console


## Run tests

docker-compose -f test.yml up
