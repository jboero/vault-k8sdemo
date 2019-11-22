#!/bin/bash -x
# John Boero - jboero@hashicorp.com
# Example vault container runner for OpenShift
# Must be run from a Pod.

export VAULT_ADDR=${VAULT_ADDR:-http://vault:8200}

# Get our token
export SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
export SA_TOKEN=${SA_TOKEN:-INVALID}

# Authenticate via REST.
export VAULT_AUTH=$(curl --request POST \
	--data "{\"jwt\": \"$SA_TOKEN\", \"role\": \"demo\"}" \
	$VAULT_ADDR/v1/auth/kubernetes/login)

# Set VAULT_TOKEN
export VAULT_TOKEN=$(echo $VAULT_AUTH | jq -r .auth.client_token)
export VAULT_TOKEN=${VAULT_TOKEN:-INVALID}

# Fetch secrets
# Fetch a KV
export KV=$(curl -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/kv/test)

# Example: Database creds
export DB=$(curl -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/database/creds/test)

# Exmaple: PKI cert
export CERT=$(curl -H "X-Vault-Token: $VAULT_TOKEN" --request POST \
                             --data '{ "common_name": "demo.openshift.domain.com"}' \
                              $VAULT_ADDR/v1/pki/issue/osrole)

# Generate sample HTML page:
cat > /usr/share/nginx/html/index.html <<EOF
<html><head><title>Vault Secrets POD</title></head><body><span style="font-family: monospace;">
<h2>Welcome</h2><p>
<table width="1680" border="1">
<tr><td nowrap><b>My service account token</b>:</td><td>$SA_TOKEN</td></tr>
<tr><td nowrap><b>My Vault token</b>:</td><td>$VAULT_TOKEN</td></tr>
</table>
The secrets I've fetched during startup:
<table width="1680" border="1">
<tr><td nowrap><b>Static secret kv/test</b>:</td><td>$KV</td></tr>
<tr><td nowrap><b>Dynamic database creds</b>:</td><td>$DB</td></tr>
<tr><td nowrap><b>PKI TLS cert info</b>:</td><td>$CERT</td></tr>
</table>
End
</body></html>
EOF

sed -i 's/$/<br>/g' /usr/share/nginx/html/index.html

nginx -g "daemon off;"
