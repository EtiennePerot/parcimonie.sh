# `parcimonie.sh`

This is a reimplementation of [Parcimonie], written completely in a si{mp,ng}le Bash script.

## What does it do?

`parcimonie.sh` refreshes individual keys in your [GnuPG] keyring at randomized intervals. Each key is refreshed over a unique, single-use Tor circuit.

Unlike the original [Parcimonie], `parcimonie.sh` guarantees that each key refresh happens over a unique Tor circuit even when multiple refreshes happen at the same time (`torsocks --isolate`).

## Why?

You can check [the original Parcimonie design document][parcimonie-original-design.md] if you are wondering why this is needed. _This is the original file from the perl parcimonie and is only here to be archived._

The **tl;dr** version: `gpg --refresh-keys` discloses your entire list of PGP keys to the keyserver you are using, as well as [whoever is wiretapping your connection][National Security Agency] if you are using an unencrypted protocol such as HKP (which is the default for most setups). That is a bad thing.

## Known security issues

* On GnuPG 2.1+, key refreshes are not guaranteed to use unique Tor circuit (issue #15).
* On GnuPG 2.1+, if the user refreshes a key outside of `parcimonie.sh` prior to `parcimonie.sh`'s first key refresh, **Tor will not be used for key refreshes** (also issue #15).

## Installation

If on Arch, grab the [`parcimonie-sh-git` package][parcimonie-sh-git package on the Arch User Repository] from the [AUR][Arch User Repository].

On Fedora, install [`parcimonie.sh`][parcimonie package in the Fedora package database] from the official repositories: `dnf install parcimonie.sh`.

Otherwise, just copy `parcimonie.sh` somewhere and make it run at boot with the right environment variables (see the "Usage" section).

## Dependencies

* [GnuPG]: tested with GnuPG 2, probably works OK with 1.* as well
* [torsocks]: 2.0
* Have [Tor] running

## Usage

Just run `parcimonie.sh`. There are some **optional** environment variables that you can use to override the default values.

* `TOR_ADDRESS`: IP on which Tor is listening. If not set, uses `127.0.0.1`.
* `TOR_PORT`: Port on which Tor is listening. If not set, uses `9050`. Make sure this refers to a `SOCKSPort` entry of your `torrc` for which `NoIsolateSOCKSAuth` is not present. If you have no idea what that means, you have nothing to worry about.
* `PARCIMONIE_USER`: The user to run as. If not set, will run as whatever user is running the script. If set, will `su` to the specified user. You can also set it to the special value `*`, which will cause the script to multiple run instances of itself: one instance for each user who has a directory called `.gnupg` in their home directory. Useful for boot scripts, and for config files for the systemd service.
* `MIN_WAIT_TIME`: Minimum time to wait between key refreshes. Defaults to 900 seconds (15 minutes).
* `TARGET_REFRESH_TIME`: Rough expected time for refreshing every key in the keyring. Defaults to 604800 seconds (1 week). Note that this doesn't guarantee that every key will be refreshed in that time. The time intervals between refreshes and the actual keys to refresh are picked randomly every time. See [the delay computation function][getTimeToWait function] for the exact formula.
* `COMPUTER_ONLINE_FRACTION`: Fraction of time that the computer is expected to be online, from 0.1 (online 10% of the time) to 1.0 (always online). Defaults to 1.0. This is used to scale `TARGET_REFRESH_TIME` accordingly in order to make it likely enough for keys to be regularly refreshed on a computer that is not online permanently. `MIN_WAIT_TIME` is still honored.
* `USE_RANDOM`: Whether or not to use `/dev/random` instead of `/dev/urandom` as source of randomness. By default, this is set to `false`, therefore `/dev/urandom` is used.
* `GNUPG_BINARY`: Path to `gpg`. If not set, will use `gpg2` or `gpg` from the `$PATH`.
* `DIRMNGR_PATH`: Path to `dirmngr`, for GnuPG < 2.1. If not set, will try to find it in `$PATH`. If not found, GnuPG < 2.1 will be assumed.
* `DIRMNGR_CLIENT_PATH`: Path to `dirmngr-client`. If not set, will try to find it in `$PATH`. `dirmngr-client` is required if `dirmngr` is specified or found in `$PATH`.
* `TORSOCKS_BINARY`: Path to `torsocks`. If not set, will use `torsocks` from the `$PATH`.
* `GNUPG_HOMEDIR`: Value for the `--homedir` argument of `gpg`. Ignored when `PARCIMONIE_USER=*`. If not set, no `--homedir` argument is passed, which usually means `~/.gnupg` will be used.
* `GNUPG_KEYSERVER`: Value for the `--keyserver` argument of `gpg`. If not set, no `--keyserver` argument is passed, which means your default keyserver will be used.
* `GNUPG_KEYSERVER_OPTIONS`: Value for the `--keyserver-options` argument of `gpg`. If not set, a single `http-proxy=` argument is passed. If you already use torify connections to keyservers with gpg's `http-proxy` keyserver-option in your `gpg.conf` while having other keyserver-options defined on top of that, you will need to re-specify those along with `http-proxy=` in `GNUPG_KEYSERVER_OPTIONS` in order to disable the proxying part. `parcimonie.sh` needs to run `gpg` with `torsocks` in order to ensure that all key grabs happen on different Tor circuits, and `torsocks` won't allow `gpg` to connect to its `http-proxy` on `127.0.0.1`.
* `PARCIMONIE_CONF`: If set, this file will be sourced before running. Useful to set environment variables without polluting the environment too much.

### systemd service

If you installed the Arch package or the Fedora package, you have a parameterized systemd service called `parcimonie.sh@`. The parameter refers to an environment file in `/etc/parcimonie.sh.d`; for example, the `parcimonie.sh@hello` service reads the environment variables from `/etc/parcimonie.sh.d/hello.conf`, and runs `parcimonie.sh` with it.

A ready-to-use configuration file is provided at `/etc/parcimonie.sh.d/all-users.conf`; it is set to start `parcimonie.sh` for all users on the system who have a `~/.gnupg` directory. If that sounds like what you want, you can enable it right away using the `parcimonie.sh@all-users` service. If not, another sample configuration file is provided at `/etc/parcimonie.sh.d/sample-configuration.conf.sample` (Arch package) or at `/usr/share/doc/parcimonie.sh/sample-configuration.conf.sample` (Fedora package).

## Why a reimplementation?

Oh gee, let me think.

```
$ pactree parcimonie-git                       $ pactree -d 1 parcimonie-sh-git
parcimonie-git                                 parcimonie-sh-git
├─perl-any-moose                               ├─bash
│ ├─perl-moose                                 ├─torsocks
│ │ ├─perl-class-load                          ├─tor
│ │ │ ├─perl-module-runtime                    └─gnupg
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
[parcimonie-original-design.md]: https://github.com/EtiennePerot/parcimonie.sh/blob/master/parcimonie-original-design.md
[National Security Agency]: https://en.wikipedia.org/wiki/National_Security_Agency
[parcimonie-sh-git package on the Arch User Repository]: https://aur.archlinux.org/packages/parcimonie-sh-git
[parcimonie package in the Fedora package database]: https://admin.fedoraproject.org/pkgdb/package/parcimonie.sh/
[Arch User Repository]: https://aur.archlinux.org/
[getTimeToWait function]: https://github.com/EtiennePerot/parcimonie.sh/blob/2ce44f45af2f48565aa42155b0bb96f07d373cbc/parcimonie.sh#L152-L171
[torsocks]: https://gitweb.torproject.org/torsocks.git/
[Tor]: https://www.torproject.org/
[WTFPL]: http://www.wtfpl.net/
