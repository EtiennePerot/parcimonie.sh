#!/usr/bin/env bash

# Copyright © 2017 Etienne Perot <etienne at perot dot me>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See http://www.wtfpl.net/ for more details.

if [ -n "$PARCIMONIE_CONF" ]; then
	source "$PARCIMONIE_CONF" || exit 'Bad configuration file.'
	export PARCIMONIE_CONF='' # Children spawned by this script (if any) should not inherit those values
fi

parcimonieUser="${PARCIMONIE_USER:-$(whoami)}"
gnupgBinary="${GNUPG_BINARY:-}"
torsocksBinary="${TORSOCKS_BINARY:-torsocks}"
gnupgHomedir="${GNUPG_HOMEDIR:-}"
gnupgKeyserver="${GNUPG_KEYSERVER:-}"
gnupgKeyserverOptions="${GNUPG_KEYSERVER_OPTIONS:-http-proxy=}"
torAddress="${TOR_ADDRESS:-127.0.0.1}"
torPort="${TOR_PORT:-9050}"
minWaitTime="${MIN_WAIT_TIME:-900}" # 15 minutes
targetRefreshTime="${TARGET_REFRESH_TIME:-604800}" # 1 week
computerOnlineFraction="${COMPUTER_ONLINE_FRACTION:-1.0}" # 100% of the time
useRandom="${USE_RANDOM:-false}"
dirmngrPath="${DIRMNGR_PATH:-}"
dirmngrClientPath="${DIRMNGR_CLIENT_PATH:-}"
gpgConnectAgentPath="${GPG_CONNECT_AGENT_PATH:-}"

# -----------------------------------------------------------------------------

if [ "$(whoami)" != "$parcimonieUser" ]; then
	if [ "$parcimonieUser" == '*' ]; then # If user requested the script to run for all users
		if [ "$(id -u)" != 0 ]; then
			echo 'Error: Must be run as root in order to support PARCIMONIE_USER="*".'
			exit 1
		fi
		gnupgUsers=()
		for user in $(cut -d ':' -f 1 < /etc/passwd); do
			if [ -d "$(eval "echo ~$user")/.gnupg" ]; then
				gnupgUsers+=("$user")
			fi
		done
		# If we have 0 users, error out
		if [ "${#gnupgUsers[@]}" -eq 0 ]; then
			echo 'Error: No users found with a ~/.gnupg directory.'
			exit 1
		fi
		# If we just have one user, just su to it
		if [ "${#gnupgUsers[@]}" -eq 1 ]; then
			export PARCIMONIE_USER="${gnupgUsers[0]}"
			export GNUPG_HOMEDIR="$(eval "echo ~"${gnupgUsers[0]}"")/.gnupg"
			exec su -c "$0" "${gnupgUsers[0]}"
		fi
		# If we have more than one, spawn children processes for each
		childrenPids=()
		for user in "${gnupgUsers[@]}"; do
			PARCIMONIE_USER="$user" GNUPG_HOMEDIR="$(eval "echo ~$user")/.gnupg" su -c "$0" "$user" &
			childrenPids+=("$!")
		done
		for childPid in "${childrenPids[@]}"; do
			wait "$childPid"
		done
		exit 0
	else # If the user requested the script to run for a specific user which is not the current one
		exec su -c "$0" "$parcimonieUser"
	fi
fi

# If we get here, we know that we are the right user.

# Find the gpg binary.
if [ -n "$gnupgBinary" ]; then
	if [ ! -x "$gnupgBinary" ]; then
		echo "Error: GNUPG_BINARY '$GNUPG_BINARY' does not exist or is not executable."
		exit 1
	fi
elif which gpg2 &> /dev/null; then
	# Try to find it in $PATH.
	gnupgBinary="$(which gpg2)"
	echo "Detected gpg2 at '$gnupgBinary'."
elif which gpg &> /dev/null; then
	gnupgBinary="$(which gpg)"
	echo "Detected gpg at '$gnupgBinary'."
else
	echo 'gpg not found. Please make sure you have installed GnuPG.'
	echo 'You may manually specify the full path to gpg with GNUPG_BINARY.'
	exit 1
fi

# Test for dirmngr, used in GnuPG >= 2.1 for keyserver communication.
if [ -n "$dirmngrPath" ]; then
	if [ ! -x "$dirmngrPath" ]; then
		echo "Error: DIRMNGR_PATH '$DIRMNGR_PATH' does not exist or is not executable."
		exit 1
	fi
elif which dirmngr &> /dev/null; then
	# Try to find dirmngr in $PATH.
	dirmngrPath="$(which dirmngr)"
	echo "Detected dirmngr at '$dirmngrPath'; assuming GnuPG >= 2.1."
else
	echo 'dirmngr not specified, and not found in $PATH. Assuming GnuPG < 2.1.'
fi

if [ -n "$dirmngrPath" ]; then
	# If we are using dirmngr, we must also have dirmngr-client.
	if [ -n "$dirmngrClientPath" ]; then
		if [ ! -x "$dirmngrClientPath" ]; then
			echo "Error: DIRMNGR_CLIENT_PATH '$DIRMNGR_CLIENT_PATH' does not exist or is not executable."
			exit 1
		fi
	elif which dirmngr-client &> /dev/null; then
		# Try to find it in $PATH. Unlike dirmngr, it is a fatal error if we cannot find it,
		# because we need it to handle dirmngr properly.
		dirmngrClientPath="$(which dirmngr-client)"
		echo "Detected dirmngr-client at '$dirmngrClientPath'."
	else
		echo "dirmngr-client not found, while dirmngr was found at '$dirmngrPath'."
		echo 'Please make sure your installation of GnuPG is complete.'
		echo 'You may manually specify the full path to dirmngr-client with DIRMNGR_CLIENT_PATH.'
		exit 1
	fi
	# Same deal with gpg-connect-agent.
	if [ -n "$gpgConnectAgentPath" ]; then
		if [ ! -x "$gpgConnectAgentPath" ]; then
			echo "Error: GPG_CONNECT_AGENT_PATH '$GPG_CONNECT_AGENT_PATH' does not exist or is not executable."
			exit 1
		fi
	elif which gpg-connect-agent &> /dev/null; then
		gpgConnectAgentPath="$(which gpg-connect-agent)"
		echo "Detected gpg-connect-agent at '$gpgConnectAgentPath'."
	else
		echo "gpg-connect-agent not found, while dirmngr was found at '$dirmngrPath'."
		echo 'Please make sure your installation of GnuPG is complete.'
		echo 'You may manually specify the full path to gpg-connect-agent with GPG_CONNECT_AGENT_PATH.'
		exit 1
	fi
fi

gnupgExec=("$gnupgBinary" --batch --with-colons)
if [ -n "$gnupgHomedir" ]; then
	gnupgExec+=(--homedir "$gnupgHomedir")
fi
if [ -n "$gnupgKeyserver" ]; then
	gnupgExec+=(--keyserver "$gnupgKeyserver")
fi
if [ -n "$gnupgKeyserverOptions" ]; then
	gnupgExec+=(--keyserver-options "$gnupgKeyserverOptions")
fi

# Test for GNU `sed`, or use a `sed` fallback in sedExtRegexp
sedExec=(sed)
if [ "$(echo 'abc' | sed -r 's/abc/def/' 2> /dev/null || true)" == 'def' ]; then
	# GNU Linux sed
	sedExec+=(-r)
else
	# Mac OS X sed
	sedExec+=(-E)
fi

sedExtRegexp() {
	"${sedExec[@]}" "$@"
}

keepDigitsOnly() {
	sedExtRegexp -e 's/[^[:digit:]]//g' -e '/^$/d'
}

getRandom() {
	if [ -z "$useRandom" -o "$useRandom" == 'false' ]; then
		od -vAn -N4 -tu4 < /dev/urandom | keepDigitsOnly
	else
		od -vAn -N4 -tu4 < /dev/random | keepDigitsOnly
	fi
}

nontor_gnupg() {
	"${gnupgExec[@]}" "$@"
	return "$?"
}

tor_gnupg() {
	"$torsocksBinary" --isolate "${gnupgExec[@]}" "$@"
}

getPublicKeys() {
	nontor_gnupg --list-public-keys --with-colons --fixed-list-mode --with-fingerprint --with-fingerprint --with-key-data |
		grep -a -A 1 '^pub:' |                       # only allow fingerprints of public keys (not subkeys)
		grep -E   '^fpr:+[0-9a-fA-F]{40,}:' |        # only allow fingerprints of v4 pgp keys
		                                             # (v3 fingerprints consist of 32 hex characters)
		sedExtRegexp 's/^fpr:+([0-9a-fA-F]+):+$/\1/' # extract the fingerprint
}

getNumKeys() {
	getPublicKeys | wc -l | keepDigitsOnly
}

getRandomKey() {
	local allPublicKeys fingerprint
	allPublicKeys=()
	for fingerprint in $(getPublicKeys); do
		allPublicKeys+=("$fingerprint")
	done
	echo "${allPublicKeys[$(expr "$(getRandom)" % "${#allPublicKeys[@]}")]}"
}

getTimeToWait() {
	# The target refresh time is scaled by the fraction of time that the computer is expected to be online.
	# expr or bash's $(()) don't support fractional math. Use awk.
	local scaledRefreshTime
	scaledRefreshTime="$targetRefreshTime"
	if [ "$computerOnlineFraction" != '1.0' -a "$computerOnlineFraction" != '1' ]; then
		scaledRefreshTime="$(echo "$scaledRefreshTime" "$computerOnlineFraction" | awk 'BEGIN {print sprintf("%.0f", $1 * $2)}')"
	fi
	#   minimum wait time + rand(2 * (refresh time / number of pubkeys))
	# = $minWaitTime + $(getRandom) % (2 * $scaledRefreshTime / $(getNumKeys))
	# But if we have a lot of keys or a very short refresh time (2 * refresh time < number of keys),
	# then we can encounter a modulo by zero. In this case, we use the following as fallback:
	#   minimum wait time + rand(minimum wait time)
	# = $minWaitTime + $(getRandom) % $minWaitTime
	if [ "$(expr '2' '*' "$scaledRefreshTime")" -le "$(getNumKeys)" ]; then
		expr "$minWaitTime" '+' "$(getRandom)" '%' "$minWaitTime"
	else
		expr "$minWaitTime" '+' "$(getRandom)" '%' '(' '2' '*' "$scaledRefreshTime" '/' "$(getNumKeys)" ')'
	fi
}

killallByUser() {
	# Usage: killallByUser KILL|TERM processname1 proccessname2 ...
	# Kills all processes running as the current user that match at least one of the
	# given process names. Does not require the "killall" binary to be installed.
	# FIXME test that this works
	local signal exe processName
	signal="$1"
	shift
	for pid in $(ps -u "$(whoami)" -o pid=); do
		exe="$(readlink "/proc/$pid/exe" 2>/dev/null || echo '')"
		if [ "$exe" -eq '' ]; then
			continue
		fi
		processName="$(basename "$exe")"
		for arg; do
			if [ "$processName" == "$arg" ]; then
				kill --signal "$signal" "$pid" &>/dev/null
				break
			fi
		done
	done
}

dirmngrPing() {
	GNUPGHOME="$gnupgHomedir" "$dirmngrClientPath" --ping --quiet
}

dirmngrConnect() {
	"$gpgConnectAgentPath" --homedir="$gnupgHomedir" --dirmngr --no-autostart "$@" /bye
}

dirmngrGetPid() {
	local pidLine
	pidLine="$(dirmngrConnect 'GETINFO pid' | head -1 | sedExtRegexp 's/^D ([0-9]+)$/\1/')"
	# Verify that the PID was correctly extracted.
	if ! echo "$pidLine" | grep -P '^[0-9]+$'; then
		return 1
	fi
	echo "$pidLine"
}

killallDirmngr() {
	# Attempt to kill dirmngr running as the current user.
	# It first tries with gpg-connect-agent.
	# If unsuccessful after 20 seconds, send SIGTERM.
	# If still unsuccessful after another 20 seconds, send SIGKILL.
	# If still unsuccessful after another 20 seconds, give up.
	local dirmngrProcessNames
	dirmngrProcessNames=(dirmngr)
	if [ "$(basename "$dirmngrPath")" != 'dirmngr' ]; then
		dirmngrProcessNames+=("$(basename "$dirmngrPath")")
	fi
	for i in $(seq 1 20); do
		dirmngrConnect KILLDIRMNGR
		sleep 1
		if ! dirmngrPing; then
			return 0
		fi
	done
	for i in $(seq 1 20); do
		killallByUser TERM "${dirmngrProcessNames[@]}"
		sleep 1
		if ! dirmngrPing; then
			return 0
		fi
	done
	for i in $(seq 1 20); do
		killallByUser KILL "${dirmngrProcessNames[@]}"
		sleep 1
		if ! dirmngrPing; then
			return 0
		fi
	done
	return 1
}

tryKillDirmngr() {
	# Usage: tryKillDirmngr PID
	# Attempt to kill dirmngr running at the given PID.
	# First it tries with gpg-connect-agent, as long as the PID matches.
	# If unsuccessful after 20 seconds or if the PID doesn't match, send SIGTERM.
	# If unsuccessful after another 20 seconds, send SIGKILL.
	# If unsuccessful after another 20 seconds, give up.
	FIXME
}

safelyTorifyDirmngr() {
	# This function kills any dirmngr running as the current user, and attempts to
	# start a fresh Torified instance.
	# Upon success, it prints the pid of the dirmngr process to stdout.
	local dirmngrPid
	if dirmngrPing; then
		# An existing dirmngr is running. Attempt to kill it for a minute.
		if ! killallDirmngr; then
			echo 'Could not kill dirmngr properly prior to spawning a new one.' >&2
			return 1
		fi
	fi
	# Spawn a new Torified dirmngr.
	"$torsocksBinary" --isolate "$dirmngrPath" "${dirmngrOptions[@]}" --daemon &
	# Give it some time to start, then find out its PID.
	sleep 15
	FIXME
}

refreshKey() {
	local keyToRefresh dirmngrPid returnCode
	keyToRefresh="$1"
	if [ -z "$dirmngrPath" ]; then
		# GnuPG < 2.1. Just torify gpg.
		tor_gnupg --recv-keys "$keyToRefresh"
		return "$?"
	fi
	# GnuPG >= 2.1 uses a separate dirmngr process to do keyserver communication.
	# This process is long-lived, which is problematic for parcimonie.sh because it
	# needs to be restarted in order to get a new Tor circuit for each key refresh.
	# To work around this, this script does some elaborate gymnastics to ensure that
	# it successfully spawns a new Torified dirmngr process.
	dirmngrPid="$(safelyTorifyDirmngr)"
	if [ "$?" -ne 0 ]; then
		echo 'Could not safely Torify dirmngr; giving up on this key refresh.'
		return
	fi
	tor_gnupg --no-autostart --recv-keys "$keyToRefresh"
	returnCode="$?"
	# Try to kill the dirmngr we spawned, such that key refreshes outside of
	# parcimonie.sh do not reuse the same Tor circuit.
	# It is not critical if this fails, as we will not attempt to initiate further
	# key refreshes with this dirmngr no matter what. This means that at most one
	# parcimonie-refreshed key may share a circuit with a non-parcimonie-refreshed
	# key.
	tryKillDirmngr "$dirmngrPid" || true
	return "$returnCode"
}

if [ "$(getNumKeys)" -eq 0 ]; then
	echo 'No GnuPG keys found.'
	exit 1
fi

if [ "$(echo "$computerOnlineFraction" | awk '{ print ($1 < 0.1 || $1 > 1.0) ? "bad" : "good" }')" == 'bad' ]; then
	echo 'COMPUTER_ONLINE_FRACTION must be between 0.1 and 1.0.' >&2
	exit 1
fi

while true; do
	keyToRefresh="$(getRandomKey)"
	timeToSleep="$(getTimeToWait)"
	echo "> Sleeping $timeToSleep seconds before refreshing key $keyToRefresh..."
	sleep "$timeToSleep"
	refreshKey "$keyToRefresh"
done
