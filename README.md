# pass-meta

A [pass](https://www.passwordstore.org/) extension that provides a schema to organize the metadata in yaml format, the idea is to have an valid yaml document within a `⊥` and `⊤` delimiters, is not relevant the content out of them, then you can edit the document following the yaml rules inside the delimiters or write without rules outside them.

## Features

  - Add and copy metadata in yaml format
  - Attachments support
  - Basic TOTP support

## Requerements

  - pass 1.7.0 or later for extension support
  - oathtool for TOTP support
  - yaml binary provided by [mikefarah/yaml](https://github.com/mikefarah/yaml)

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
SuP3rH4rDPasSw0rD
this is a secret note
```

`pass append Super/Secret username individuo7`

`pass Super/Secret`

```
SuP3rH4rDPasSw0rD
this is a secret note
⊥
username: individuo7
⊤
```

`pass meta Super/Secret username`  _(use -c to copy instead show)_

```
individuo7
```

`pass append Super/Secret secretimage /a/real/file/patch.png`

`pass Super/Secret`

```
SuP3rH4rDPasSw0rD
this is a secret note
⊥
username: individuo7
secretimage: //sFDuY8jez8H2rful.gpg
⊤
```

`pass meta Super/Secret secretimage` _(show the image)_

When you try to show a file this do it following the mailcap rules.

`pass append Super/Secret otp BASE32SECRET3232`

`pass Super/Secret`

```
SuP3rH4rDPasSw0rD
this is a secret note
⊥
username: individuo7
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
- Add this repo as a submodule to your password store and create a symlink to append.bash and meta.bash in `~/password-store/.extensions`

Note: make sure the `yaml` and `oathtool` commands are available in your console


## Run tests

docker-compose -f test.yml up

