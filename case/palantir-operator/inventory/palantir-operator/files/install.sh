#!/usr/bin/env bash

set -eo pipefail

[[ "$DEBUG" == 'true' ]] && set -x

### Check pre-requisite input information ###
missing_variable=0
[[ -z $NAMESPACE ]] && echo "\$NAMESPACE is a required environment variable and was missing" && missing_variable=1
[[ -z $CPD_NAMESPACE ]] && echo "\$CPD_NAMESPACE is a required environment variable and was missing" && missing_variable=1
[[ -z $CPD_DOMAIN ]] && echo "\$CPD_DOMAIN is a required environment variable and was missing" && missing_variable=1
[[ -z $IBM_ENTITLEMENT_KEY ]] && echo "\$IBM_ENTITLEMENT_KEY is a required environment variable and was missing" && missing_variable=1
[[ -z $PALANTIR_REGISTRATION_KEY ]] && echo "\$PALANTIR_REGISTRATION_KEY is a required environment variable and was missing" && missing_variable=1
[[ -z $STORAGE_CLASS ]] && echo "\$STORAGE_CLASS is a required environment variable and was missing" && missing_variable=1
[[ -z $DATA_STORAGE_PATH ]] && echo "\$DATA_STORAGE_PATH is a required environment variable and was missing" && missing_variable=1
[[ -z $DATA_STORAGE_ENDPOINT ]] && echo "\$DATA_STORAGE_ENDPOINT is a required environment variable and was missing" && missing_variable=1
[[ -z $DATA_STORAGE_ENCRYPTION_PUBLIC_KEY_FILE ]] && echo "\$DATA_STORAGE_ENCRYPTION_PUBLIC_KEY_FILE is a required environment variable and was missing" && missing_variable=1
[[ -z $DATA_STORAGE_ENCRYPTION_PRIVATE_KEY_FILE ]] && echo "\$DATA_STORAGE_ENCRYPTION_PRIVATE_KEY_FILE is a required environment variable and was missing" && missing_variable=1
[[ -z $DATA_STORAGE_ACCESS_KEY ]] && echo "\$DATA_STORAGE_ACCESS_KEY is a required environment variable and was missing" && missing_variable=1
[[ -z $DATA_STORAGE_ACCESS_KEY_SECRET ]] && echo "\$DATA_STORAGE_ACCESS_KEY_SECRET is a required environment variable and was missing" && missing_variable=1
[[ -z $PALANTIR_DOCKER_USER ]] && echo "\$PALANTIR_DOCKER_USER is a required environment variable and was missing" && missing_variable=1
[[ -z $PALANTIR_DOCKER_PASSWORD ]] && echo "\$PALANTIR_DOCKER_PASSWORD is a required environment variable and was missing" && missing_variable=1

if [[ $missing_variable -eq 1 ]]; then
  exit 1
fi

### Enable firewalls unless overridden
: "${DISABLE_NETWORK_FIREWALLS:=false}"
if [[ $DISABLE_NETWORK_FIREWALLS == "true" ]]; then
  echo "Disabling network firewalls"
fi

### Start installation ###
oc create namespace "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -

oc create secret generic -n "$NAMESPACE" registration-info \
    --from-literal=entitlement-key="$IBM_ENTITLEMENT_KEY" \
    --from-literal=registration-key="$PALANTIR_REGISTRATION_KEY" \
    --dry-run=client -o yaml | oc apply -f -

oc create secret generic -n "$NAMESPACE" data-storage-encryption \
    --from-file=public-key="$DATA_STORAGE_ENCRYPTION_PUBLIC_KEY_FILE" \
    --from-file=private-key="$DATA_STORAGE_ENCRYPTION_PRIVATE_KEY_FILE" \
    --dry-run=client -o yaml | oc apply -f -

oc create secret generic -n "$NAMESPACE" data-storage-creds \
    --from-literal=access-key="$DATA_STORAGE_ACCESS_KEY" \
    --from-literal=access-key-secret="$DATA_STORAGE_ACCESS_KEY_SECRET" \
    --dry-run=client -o yaml | oc apply -f -

if [[ -n $P4CP4D_PROXY_CERTIFICATE_FILE && -n $P4CP4D_PROXY_PRIVATE_KEY_FILE ]]; then
    oc create secret tls -n "$NAMESPACE" proxy-certificate \
      --cert="$P4CP4D_PROXY_CERTIFICATE_FILE" \
      --key="$P4CP4D_PROXY_PRIVATE_KEY_FILE" \
      --dry-run=client -o yaml | oc apply -f -
else
    echo "Using self-signed certificate for P4CP4D proxy"
fi

manifestsDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sed -e "s|#DISABLE_NETWORK_FIREWALLS#|$DISABLE_NETWORK_FIREWALLS|g" \
  -e "s|#STORAGE_CLASS#|$STORAGE_CLASS|g" \
  -e "s|#DATA_STORAGE_PATH#|$DATA_STORAGE_PATH|g" \
  -e "s|#DATA_STORAGE_ENDPOINT#|$DATA_STORAGE_ENDPOINT|g" \
  -e "s|#CPD_NAMESPACE#|$CPD_NAMESPACE|g" \
  -e "s|#CPD_DOMAIN#|$CPD_DOMAIN|g" \
  "$manifestsDir"/userconfig.yaml | oc apply -n "$NAMESPACE" -f -

sed -e "s|#NAMESPACE#|$NAMESPACE|g" "$manifestsDir"/rbac.yaml | oc apply -n "$NAMESPACE" -f -

oc create secret -n "$NAMESPACE" docker-registry palantir-ext-creds \
    --docker-server docker.external.palantir.build \
    --docker-username "$PALANTIR_DOCKER_USER" \
    --docker-password "$PALANTIR_DOCKER_PASSWORD" \
    --dry-run=client -o yaml | oc apply -f -

oc patch serviceaccount palantir-operator -n "$NAMESPACE" -p '{"imagePullSecrets": [{"name": "palantir-ext-creds"}]}'

oc apply -n "$NAMESPACE" -f "$manifestsDir"/configmap.yaml
oc apply -n "$NAMESPACE" -f "$manifestsDir"/operator.yaml

echo "Installation complete!"