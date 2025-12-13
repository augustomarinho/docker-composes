#!/bin/bash
set -o errexit ; set -o nounset; set -o pipefail

url="$1"
shift
cmd=("$@")

echo "Waiting for $url to return a healthy status..."
while true; do
  status_code=$(curl -sk -o /dev/null -w "%{http_code}" "$url" || true)
  case "$status_code" in
    200|401|403)
      echo "$url is reachable (HTTP $status_code), proceeding..."
      break
      ;;
    *)
      echo "Waiting for $url to be ready... Current status: $status_code"
      ;;
  esac
  sleep 2
done

exec "${cmd[@]}"
