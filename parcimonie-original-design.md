Assumptions
===========

Let us consider an individual's public keyring as an unordered set of
public OpenPGP keys.

We assume there probably exists at least one subset of public keys in
this keyring that identifies it, i.e. no other individual's keyring
contain the same subset of public keys. This unproven assumption is
the basis for any subsequent design thought about parcimonie.

It is generally considered good practice to refresh such public keys
from public keyservers on a regular basis, notably since public
OpenPGP keys can be compromised and thus revoked.

The usual way to refresh a public keyring is to run the `gpg
--refresh-keys` command that queries the configured keyserver for
updates of every public key stored in the to-be-refreshed keyring.

Combined with the identifying subset assumption, this "query all keys
at a time" way of refreshing a keyring might disclose private
information to an adversary.

The adversary
=============

Network-wise we assume the same type of threat that Tor does: an
non-global adversary who has full control over the network traffic of
some fractions of the Internet.

OpenPGP keyservers administrators are in a privileged position to
observe public keys requests.

To put it short, the rest of this document will call "the adversary"
anyone able to monitor a given individual's connections to her
configured OpenPGP keyserver(s) on a regular basis.

The adversary is able to establish the identifying subset <->
individual.
XXX: explain why/how the adversary may be able to do so.

Threats
=======

Using Tor
---------

(application-level leakage)

The adversary gains knowledge of the rest of the keyring.

Not using Tor
-------------

(IP-level + application-level leakage)

The adversary gains knowledge of the rest of the keyring + user location.

Possible workarounds
====================

Greatly increase the cost of correlating every key update.

parcimonie refreshes one key at a time, over Tor; between every key
update it sleeps a random amount of time, long enough for the
previously used Tor circuit to expire.

Refresh rate
============

parcimonie sleeps a random amount of time between every key fetch;

- the longest the delay is, the longest it takes for a published key
  update (e.g. revocation certificate) to become locally available
- the shortest the delay is, the cheaper a correlation attack is

this lapse time is computed in function of the number of public keys
in the keyring:

   max(MaxCircuitDirtiness, rand(2 * ( seconds in a week / number of pubkeys )))


Examples:
  - 50  public keys -> average lapse time =~ 200 min.
  - 500 public keys -> average lapse time =~ 20 min.

Feedback to the user
====================

The parcimonie daemon sends a D-Bus signal before and after every key
fetch attempt. The applet registers to this signal and displays status
information accordingly.
