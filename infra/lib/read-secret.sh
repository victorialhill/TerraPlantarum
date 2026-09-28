# Shared by the container scripts. Load with: . /terraplantarum/read-secret.sh
# read_secret <name> prints /run/secrets/<name>, and stops the calling script if it is missing or empty.
# POSIX sh, so it works under Alpine's sh and Debian's bash alike

read_secret() {
    value="$(cat "/run/secrets/$1")"
    if [ -z "$value" ]; then
        echo "secret $1 is missing or empty; refusing to start" >&2
        exit 1
    fi
    printf '%s' "$value"
}
