#!/bin/sh
set -e

echo "Waiting for Vault to be ready..."
until vault status 2>/dev/null; do
  sleep 2
done

echo "Configuring Vault..."

# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2 || true

# Store database credentials
vault kv put secret/database/postgres \
  username="${DB_USER:-dbadmin}" \
  password="${DB_PASSWORD:-dbpassword123}"

# Create policy for backend service
cat <<EOF | vault policy write backend-policy -
path "secret/data/database/postgres" {
  capabilities = ["read"]
}

path "auth/approle/login" {
  capabilities = ["create", "update"]
}
EOF

# Enable AppRole auth method
vault auth enable approle || true

# Create AppRole for backend service
vault write auth/approle/role/backend \
  token_policies="backend-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0 \
  secret_id_num_uses=0

# Get Role ID
ROLE_ID=$(vault read -field=role_id auth/approle/role/backend/role-id)
echo "ROLE_ID: $ROLE_ID"

# Create Secret ID
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/backend/secret-id)
echo "SECRET_ID: $SECRET_ID"

# Save credentials to file for later use
cat > /shared/vault-creds <<EOF
VAULT_ROLE_ID=$ROLE_ID
VAULT_SECRET_ID=$SECRET_ID
EOF

echo "Vault configuration completed!"
echo "Role ID and Secret ID have been generated."
echo "Please update your .env file with the credentials above."
