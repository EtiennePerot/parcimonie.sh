# `parcimonie.sh`

This is a reimplementation of [Parcimonie], written completely in a si{mp,ng}le Bash script.

## What does it do?

`parcimonie.sh` refreshes keys in your [GnuPG] keyring at randomized intervals. Each key refresh happens over a unique, single-use Tor circuit.

Unlike the original [Parcimonie], `parcimonie.sh` guarantees that each key refresh happens over a unique Tor circuit even when multiple refreshes happen at the same time.

## Why?

You can check [the original Parcimonie design document][Parcimonie design.mdwn] if you are wondering why this is needed.

## Dependencies

* [GnuPG] 2
* [torsocks]
* Have [Tor] running

## Usage

Just run `parcimonie.sh`. There are some **optional** environment variables that you can use to override the default values.

* `TOR_ADDRESS`: IP on which Tor is listening. If not set, uses `127.0.0.1`.
* `TOR_PORT`: Port on which Tor is listening. If not set, uses `9050`. Make sure this refers to a `SOCKSPort` entry of your `torrc` for which `NoIsolateSOCKSAuth` is not present. If you have no idea what that means, you have nothing to worry about.
* `MIN_WAIT_TIME`: Minimum time to wait between key refreshes. Defaults to 900 seconds (15 minutes).
* `USE_RANDOM`: Whether or not to use `/dev/random` instead of `/dev/urandom` as source of randomness. By default, this is set to `false`, therefore `/dev/urandom` is used.
* `GNUPG_BINARY`: Path to `gpg`. If not set, will use `gpg` from the `$PATH`.
* `TORSOCKS_BINARY`: Path to `torsocks`. If not set, will use `torsocks` from the `$PATH`.
* `GNUPG_HOMEDIR`: Value for the `--homedir` argument of `gpg`. If not set, no `--homedir` argument is passed, which usually means `~/.gnupg` will be used.
* `GNUPG_KEYSERVER`: Value for the `--keyserver` argument of `gpg`. If not set, no `--keyserver` argument is passed, which means your default keyserver will be used.
* `GNUPG_KEYSERVER_OPTIONS`: Value for the `--keyserver-options` argument of `gpg`. If not set, no `--keyserver-options` argument is passed.
* `TMP_PREFIX`: Prefix for temporary files. Defaults to `/tmp/parcimonie`.

## Why a reimplementation?

Oh gee, let me think.

```
$ pactree parcimonie-git                       $ pactree -d 1 parcimonie-sh-git
parcimonie-git                                 parcimonie-sh-git
├─perl-any-moose                               ├─bash
│ ├─perl-moose                                 ├─tor
│ │ ├─perl-class-load                          └─torsocks
│ │ │ ├─perl-module-runtime
│ │ │ │ └─perl-params-classify
│ │ │ ├─perl-data-optlist
│ │ │ │ ├─perl-params-util
│ │ │ │ ├─perl provides perl-scalar-list-utils
│ │ │ │ └─perl-sub-install
│ │ │ ├─perl-package-stash
│ │ │ │ ├─perl-dist-checkconflicts
│ │ │ │ │ ├─perl-list-moreutils
│ │ │ │ │ └─perl provides perl-exporter
│ │ │ │ ├─perl-package-deprecationmanager
│ │ │ │ │ ├─perl-list-moreutils
│ │ │ │ │ ├─perl-params-util
│ │ │ │ │ └─perl-sub-install
│ │ │ │ ├─perl provides perl-scalar-list-utils
│ │ │ │ └─perl-package-stash-xs
│ │ │ ├─perl-try-tiny
│ │ │ ├─perl-test-fatal
│ │ │ │ └─perl-try-tiny
│ │ │ └─perl-module-implementation
│ │ │   └─perl-module-runtime
│ │ ├─perl-class-load-xs
│ │ │ └─perl-class-load
│ │ ├─perl-data-optlist
│ │ ├─perl-devel-globaldestruction
│ │ │ ├─perl-sub-exporter
│ │ │ │ ├─perl
│ │ │ │ ├─perl-data-optlist
│ │ │ │ ├─perl-params-util
│ │ │ │ └─perl-sub-install
│ │ │ └─perl-sub-exporter-progressive
│ │ ├─perl-dist-checkconflicts
│ │ ├─perl-eval-closure
│ │ │ ├─perl provides perl-test-simple
│ │ │ ├─perl-test-requires
│ │ │ ├─perl-test-fatal
│ │ │ ├─perl-try-tiny
│ │ │ └─perl-sub-exporter
│ │ ├─perl-list-moreutils
│ │ ├─perl-mro-compat
│ │ ├─perl-package-deprecationmanager
│ │ ├─perl-package-stash
│ │ ├─perl-package-stash-xs
│ │ ├─perl-params-util
│ │ ├─perl-sub-exporter
│ │ ├─perl-sub-name
│ │ ├─perl-task-weaken
│ │ └─perl-try-tiny
│ └─perl-mouse
├─perl-namespace-autoclean
│ ├─perl-b-hooks-endofscope
│ │ ├─perl-module-implementation
│ │ ├─perl-module-runtime
│ │ ├─perl-sub-exporter
│ │ ├─perl-sub-exporter-progressive
│ │ ├─perl-try-tiny
│ │ ├─perl-variable-magic
│ └─perl-namespace-clean
│   ├─perl-b-hooks-endofscope
│   └─perl-package-stash
├─perl-gnupg-interface
│ └─perl-any-moose
├─perl-clone
├─perl-config-general
├─perl-file-homedir
│ └─perl-file-which
├─perl-path-class
├─perl-net-dbus
│ ├─dbus
│ │ ├─expat
│ │ │ └─glibc
│ │ ├─coreutils
│ │ ├─filesystem
│ │ └─shadow
│ │   ├─bash
│ │   ├─pam
│ │   └─acl
│ └─perl-xml-twig
│   ├─perl-xml-parser
│   │ └─expat
│   └─perl-text-iconv
├─perl-tie-cache
├─perl-time-duration-parse
│ └─perl-exporter-lite
├─perl-moosex-types-path-class
│ ├─perl-moose
│ ├─perl-moosex-types
│ │ ├─perl-carp-clan
│ │ ├─perl-namespace-clean
│ │ ├─perl-sub-install
│ │ └─perl-sub-name
│ └─perl-path-class
├─perl-moosex-getopt
│ ├─perl-getopt-long-descriptive
│ │ ├─perl-params-validate
│ │ │ └─perl-module-implementation
│ │ └─perl-sub-exporter
│ ├─perl-moose
│ └─perl-moosex-role-parameterized
└─perl

```

## Licensing

`parcimonie.sh` is licensed under the [WTFPL].

[Parcimonie]: https://gaffer.ptitcanardnoir.org/intrigeri/code/parcimonie/
[GnuPG]: https://en.wikipedia.org/wiki/GNU_Privacy_Guard
[Parcimonie design.mdwn]: https://code.ohloh.net/file?fid=BbMaEKchr9cDAOVs8ozX5mJ40g8&cid=RfbvTf3fwdw&s=&browser=Default&fp=405976&mpundefined&projSelected=true
[torsocks]: https://code.google.com/p/torsocks/
[Tor]: https://www.torproject.org/
[WTFPL]: http://www.wtfpl.net/
