#!/bin/bash

DIR=${DIR:-.}

log() { printf "\xE2\x98\xA0 `date "+%F %T.%3N"` $@ \n"; }

make_credential_file() {
	log "switching to $1 context"
	3ber ctx set $1 -q || exit 1

	log "loading all secrets"
	all_secrets=$(kubectl get secret -Ao json)
	count=$(echo $all_secrets | jq '.items | length')
	log "found $count secrets total"

	secrets=$(echo $all_secrets | jq '.items[] | select(.metadata.name | contains("-env"))')
	count=$(echo $secrets | jq -s '. | length')
	log "reduced to $count secrets with -env in the name"

	log "parsing keys/values"
	keys=($(echo $secrets | jq -r '.data | to_entries[].key' 2>/dev/null))
	values=($(echo $secrets | jq -r '.data | to_entries[].value' 2>/dev/null))
	log "there are ${#keys[@]} keys and ${#values[@]} values"

	[ ${#keys[@]} -ne ${#values[@]} ] && log "key/value count mismatch!" && exit 1

	log "base64 decoding values"
	for (( i=0; i<${#values[@]}; i++ )); do
		values[$i]=$(printf ${values[$i]} | base64 -d)
	done

	log "writing credentials.json.$1"
	ruby_grpc_json() {
		count=0
		printf "[\n"
		for (( i=0; i<${#keys[@]}; i++ )); do
			key=${keys[$i]} value="${values[$i]}"
			 if [[ $key =~ _BASIC_AUTH_USERNAME$ ]] ||  [[ $key =~ _BASIC_AUTH_PASSWORD$ ]]; then
			 	[[ $count -gt 0 ]] && printf ",\n"; count=$(($count+1))
			 	printf "\t{\n"
			 	printf "\t\t'username': '$key',\n"
			 	printf "\t\t'password': '$value',\n"
			 	printf "\t}"
			 fi
		done
		printf "\n]"
	}
	ruby_grpc_json > "${DIR}/credentials.json.$1"
}

# make_credential_file staging
make_credential_file prod

log done
