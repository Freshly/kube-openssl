#!/bin/sh
# set -x
# 3ber ctx set staging -q

export CRYPTO_KEY=$(kubectl get secret/master-key -o jsonpath='{.data.key}')
export CRYPTO_KEY=$(echo ${CRYPTO_KEY} | openssl base64 -d)

# encrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 encrypt-wrap "$@"; echo; }
# decrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 decrypt "$@"; }

# # this is really inefficient
# namespaces=$(kubectl get ns -o jsonpath='{.items}'|jq -r '.[].metadata.name')
# for namespace in ${namespaces[@]}; do
#   secretNames=$(kubectl -n ${namespace} get secret -o jsonpath={.items} | jq -r '.[].metadata.name')
#   for secretName in ${secretNames[@]}; do
#     echo "${namespace}/${secretName}:"
#     secrets=$(kubectl -n ${namespace} get secret/${secretName} -o jsonpath='{.data}')
#     for secret in `echo $secrets | jq -r 'keys[]'`; do
#       val=`echo ${secrets} | jq -r .${secret} | openssl base64 -d`
#       enc=`encrypt "${val}"`
#       echo "  ${secret}: >-"
#       while IFS= read -r line ; do
#         echo "    ${line}"
#       done <<< "${enc}"
#     done
#     echo
#   done
# done

kubectl get secret -Ao yaml | openssl aes-256-cbc -k "${CRYPTO_KEY}" -pbkdf2
