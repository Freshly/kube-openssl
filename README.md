# Secrets

This is a lightweight, git-ops friendly Kubernetes secrets solution based on `openssl` using AES 256-bit CBC symmetric encryption. It provides a simple approach for storing encrypted data at rest and decrypting it at runtime. At its simplest, a secret master key is installed into the Kubernetes cluster and referenced by an init container to decrypt secret data.

## Prerequisites

A secrets developer will need these tools to be effective:

- docker
- helm
- jq
- kubectl
- OpenSSL 1.1.1
- 3ber (optional)

### Mac Users: openssl

If a Mac user wants to encrypt using openssl on their host, they will need to adjust their path to point to the correct OpenSSL version:

```
export PATH="/usr/local/opt/openssl@1.1/bin:$PATH" >> ~/.zshrc
. ~/.zshrc
```

## Dependency: Kubernetes Replicator

The Kubernetes replicator is required to distribute the crypto key.

```
3ber ctx set staging -q
helm repo add mittwald https://helm.mittwald.de
helm repo update
helm upgrade --install kubernetes-replicator mittwald/kubernetes-replicator --set grantClusterAdmin=true
```

## Creating Crypto Key

You need to create a crypto key for your Kubernetes cluster. This will be stored in a secret. We add an annotation to tell the [Kubernetes replicator](https://github.com/mittwald/kubernetes-replicator) to create the secret in every namespace.

```
3ber ctx set staging -q
export CRYPTO_KEY=$(openssl rand -base64 42)
kubectl create secret generic master-key --type=string --from-literal=key=${CRYPTO_KEY}
kubectl annotate secret/master-key replicator.v1.mittwald.de/replicate-to='*'
```

Back up your crypto key!

```
kubectl get secret/master-key -o yaml >> ~/.kube/master-key-staging.yaml
```

## Encrypting / Decrypting

### Manually

Below is an example of how to manually encrypt/decrypt information. Multi-line data is supported.

```
3ber ctx set staging -q
export CRYPTO_KEY=$(kubectl get secret/master-key -o jsonpath='{.data.key}')
export CRYPTO_KEY=$(echo ${CRYPTO_KEY} | openssl base64 -d -A)
encrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 encrypt "$@"; echo; }
decrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 decrypt "$@"; echo; }

encrypt 'Well, I see you were able to decrypt this successfully in staging...'
encrypt 'Able was I, ere I saw elba'
decrypt U2FsdGVkX1+mP22w8c76Fs210J6g6gU08yBAbWYWCM5VU8VbB4prboC2npUXlnyU/wW2ElEh+Co2vhunjjxyjza5w/qOapGcXEg0ayyc5ieQwzg1806IQvUgFzC3o/Hh
decrypt U2FsdGVkX1+owcmxHHTx2RMWPXpbdyKwSfO5dpbESnj+zlpH+nzRDXx8e47yjVic
enc=$(encrypt "test\ntest2\ntest3\ntest4\ntest5")
decrypt $enc
```

Put the encrypted value in your chart's `values.yaml` file.

### Encrypt Existing Secret

You can use this script to automatically encrypt existing secret data.

```
3ber ctx set staging -q
export CRYPTO_KEY=$(kubectl get secret/master-key -o jsonpath='{.data.key}')
export CRYPTO_KEY=$(echo ${CRYPTO_KEY} | openssl base64 -d -A)
encrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 encrypt-wrap "$@"; echo; }
decrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 decrypt "$@"; echo; }

secrets=$(kubectl -n account-service get secret/account-service-env -o jsonpath='{.data}')

for secret in `echo $secrets | jq -r 'keys[]'`; do
  val=`echo ${secrets} | jq -r .${secret} | openssl base64 -d -A`
  enc=`encrypt "${val}"`
  echo "${secret}: |"
  while IFS= read -r line ; do
    echo "  ${line}"
  done <<< "${enc}"
done
```

### Automated Encrypt Method

You can use this general purpose script to encrypt arbitrary base64-encoded data.

```
3ber ctx set staging -q
export CRYPTO_KEY=$(kubectl get secret/master-key -o jsonpath='{.data.key}')
export CRYPTO_KEY=$(echo ${CRYPTO_KEY} | openssl base64 -d)
encrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 encrypt-wrap "$@"; echo; }
decrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 decrypt "$@"; echo; }

vars=(
  ACCOUNT_SERVICE_BASIC_AUTH_PASSWORD: dGhpc2lzYWN0dWFsbHlmYWtlCg==
  ACCOUNT_SERVICE_BASIC_AUTH_USERNAME: ZnJlc2hseQ==
)
for (( i=1; i <= ${#vars[@]}; i += 2 )); do
  key=${vars[$i]}
  val=`echo "${vars[$i+1]}" | openssl base64 -d -A`
  enc=`encrypt "${val}"`
  echo "${key} |"
  while IFS= read -r line ; do
    echo "  ${line}"
  done <<< "${enc}"
done
```

Copy the secret data to your chart's `values.yaml` file.

## Decrypting

### Runtime

Try out the example pod in staging:

```
3ber ctx set staging -q
kubectl create -f pod.yaml
```

### Production

If you can connect to the production cluster, you can decrypt/encrypt secrets like usual.

```
3ber ctx set prod -q
export CRYPTO_KEY=$(kubectl get secret/master-key -o jsonpath='{.data.key}')
export CRYPTO_KEY=$(echo ${CRYPTO_KEY} | openssl base64 -d -A)
encrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 encrypt "$@"; echo; }
decrypt() { docker run --rm -it -e CRYPTO_KEY=${CRYPTO_KEY} gcr.io/freshly-docker/crypto:0.0.6 decrypt "$@"; echo; }

decrypt U2FsdGVkX1+oIpGKjOQPRtntl7C0ZvTzqTGV+N36XuLRTuZn4RZIRq3kaFFnFTjIDqWBPffJ/GEUNLmWbkGzUSppBYDJLGiBMy5Ly+5Y37n6SGQsD+S3zlSLMkDRtvv5
decrypt U2FsdGVkX19JbDZ6L6VBDsi2G9eXR6qO19Xmr0aMydOHjeZx0ngL0iZG89WCVcVzDl+qzVwsTDmtz2KLKF0oZg==
```

## Docker

### Building Image

```
docker build -t gcr.io/freshly-docker/crypto:0.0.6 .             
docker push gcr.io/freshly-docker/crypto:0.0.6
```

### Run Tests

```
docker run --rm -it --entrypoint=/usr/bin/crypto-test gcr.io/freshly-docker/crypto:0.0.6
```
