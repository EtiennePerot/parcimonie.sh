#!/usr/bin/env bash

if [ -n "$PARCIMONIE_CONF" ]; then
	source "$PARCIMONIE_CONF" || exit 'Bad configuration file.'
	export PARCIMONIE_CONF='' # Children spawned by this script (if any) should not inherit those values
fi

parcimonieUser="${PARCIMONIE_USER:-$(whoami)}"
gnupgBinary="${GNUPG_BINARY:-gpg}"
torsocksBinary="${TORSOCKS_BINARY:-torsocks}"
gnupgHomedir="${GNUPG_HOMEDIR:-}"
gnupgKeyserver="${GNUPG_KEYSERVER:-}"
gnupgKeyserverOptions="${GNUPG_KEYSERVER_OPTIONS:-}"
torAddress="${TOR_ADDRESS:-127.0.0.1}"
torPort="${TOR_PORT:-9050}"
minWaitTime="${MIN_WAIT_TIME:-900}" # 15 minutes
tmpPrefix="${TMP_PREFIX:-/tmp/parcimonie}"
useRandom="${USE_RANDOM:-false}"

# -----------------------------------------------------------------------------

if [ "$(whoami)" != "$parcimonieUser" ]; then
	exec su -c "$0" "$parcimonieUser"
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

getRandom() {
	if [ -z "$useRandom" -o "$useRandom" == 'false' ]; then
		od -vAn -N4 -tu4 < /dev/urandom | sed -r 's/\s+//'
	else
		od -vAn -N4 -tu4 < /dev/random | sed -r 's/\s+//'
	fi
}

gnupg() {
	"${gnupgExec[@]}" "$@"
	return "$?"
}

torgnupg() {
	local torsocksConfig returnCode
	torsocksConfig="${tmpPrefix}-torsocks-$(getRandom).conf"
	touch "$torsocksConfig"
	chmod 600 "$torsocksConfig"
	echo "server = $torAddress" > "$torsocksConfig"
	echo "server_port = $torPort" >> "$torsocksConfig"
	echo "server_type = 5" >> "$torsocksConfig"
	TORSOCKS_CONF_FILE="$torsocksConfig" TSOCKS_USERNAME="parcimonie-$(getRandom)" TSOCKS_PASSWORD="parcimonie-$(getRandom)" "$torsocksBinary" "${gnupgExec[@]}" "$@"
	returnCode="$?"
	rm -f "$torsocksConfig"
	return "$returnCode"
}

cleanup() {
	rm -f "$tmpPrefix"* &> /dev/null
}

getPublicKeys() {
	gnupg --list-public-keys --fixed-list-mode --fingerprint --with-key-data | grep -E '^fpr:' | sed -r 's/^fpr:+([0-9A-F]+):+$/\1/i'
}

getNumKeys() {
	getPublicKeys | wc -l
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
	#   minimum wait time + rand(2 * (seconds in a week / number of pubkeys))
	# = minimum wait time + rand(seconds in 2 weeks / number of pubkeys)
	# = $minWaitTime + 1209600 / $(getNumKeys) % $(getRandom)
	expr "$minWaitTime" '+' 1209600 '/' "$(getNumKeys)" '%' "$(getRandom)"
}

if [ "$(getNumKeys)" -eq 0 ]; then
	echo 'No GnuPG keys found.'
	exit 1
fi

cleanup
while true; do
	keyToRefresh="$(getRandomKey)"
	timeToSleep="$(getTimeToWait)"
	echo "> Sleeping $timeToSleep seconds before refreshing key $keyToRefresh..."
	sleep "$timeToSleep"
	torgnupg --recv-keys "$keyToRefresh"
done
cleanup
