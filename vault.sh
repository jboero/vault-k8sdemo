#!/bin/bash
# Vault setup for OpenShift demo container.
# 

# Enable database secrets
vault secrets enable database
# Write database config for server we'll name "mysql"
vault write database/config/mysql plugin_name=mysql-database-plugin \
	connection_url="{{username}}:{{password}}@tcp(192.168.2.5:3306)/" \
	username="vault" password="vaultpassword"
# Write database role (template) for the users we'd like to create
vault write database/roles/demo db_name=mysql creation_statements=\
	(echo "CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT ON *.* TO '{{name}}'@'%';" | base64) \
	default_ttl="10m" max_ttl="24h"

# Enable KV
vault secrets enable -version=1 kv
# Write KV test
vault write kv/test sec=test sec2=test2

# Enable PKI
vault secrets enable pki
# Create a test root CA for certs
vault write pki/root/generate/internal \
	common_name=test.domain.com \
	ttl=8760h
# Write a role (CSR template) for demo.
vault write pki/roles/osrole \
    allowed_domains=openshift.domain.com \
    allow_subdomains=true \
    max_ttl=72h


# Create a policy for our OpenShift role:
vault write sys/policy/openshiftapp1 policy=<<EOF
path "kv/test" {
    capabilities = ["read"]
}

path "database/creds/test" {
    capabilities = ["read"]
}

path "pki/issue/openshift-role" {
  	capabilities = ["read", "update"]
}
EOF

# Create a token reviewer in OpenShift first if necessary (OC admin required):
oc create sa vault-auth
oc adm policy add-cluster-role-to-user system:auth-delegator system:serviceaccount:vault-controller:vault-auth

reviewer_service_account_jwt=$(oc serviceaccounts get-token vault-auth)

# Enable OpenShift authentication on OpenShift cluster with this token for reviewing:
# You will need a copy of your Kubernetes CA cert here for TLS.
vault write auth/kubernetes/config token_reviewer_jwt="$reviewer_service_account_jwt" \
	kubernetes_host=<server-url> \
	kubernetes_ca_cert=@your_openshift_ca.crt

# Create a role for our OpenShift namespace/app:
# Change OpenShift service account from default if necessary
vault write auth/kubernetes/role/ocpapp1 \
	bound_service_account_names=default \
	bound_service_account_namespaces='*' \
	policies=openshiftapp1 \
	ttl=2h

