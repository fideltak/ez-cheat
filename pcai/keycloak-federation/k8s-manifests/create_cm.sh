#!/bin/bash

set -euo pipefail

NAMESPACE=""

while getopts ":n:" opt; do
  case "$opt" in
    n) NAMESPACE="$OPTARG" ;;
    *)
      echo "Usage: $0 -n <namespace>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$NAMESPACE" ]]; then
  echo "Usage: $0 -n <namespace>" >&2
  exit 1
fi

kubectl -n "$NAMESPACE" create configmap \
  mykeycloak-authenticator-jar \
  --from-file=../pcai-downstream-authenticator-0.1.0.jar 