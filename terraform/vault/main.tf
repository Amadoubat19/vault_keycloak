provider "vault" {
  address = "https://__VAULT_URL"
  token = "__VAULT_TOKEN__"
}

resource "vault_identity_oidc_key" "key" {
  name      = "key"
  algorithm = "RS256"
}

resource "vault_jwt_auth_backend" "oidc_backend" {
    description         = "Demonstration of the Terraform JWT auth backend"
    path                = "oidc"
    type                = "oidc"
    oidc_discovery_url  = "https://__KEYCLOAK_URL__/auth/realms/vault"
    default_role = "default"
    oidc_client_id      = "vault"
    oidc_client_secret  = "9SC0lmQSsuvN6EUK6sagJEdmREWiph58"
    tune {
        audit_non_hmac_request_keys  = []
        audit_non_hmac_response_keys = []
        default_lease_ttl            = "1h"
        listing_visibility           = "unauth"
        max_lease_ttl                = "1h"
        passthrough_request_headers  = []
        token_type                   = "default-service"
    }
}

resource "vault_jwt_auth_backend_role" "default" {
  backend         = vault_jwt_auth_backend.oidc_backend.path
  role_name       = "default"
  role_type      = "oidc"
  token_ttl      = 3600
  token_max_ttl  = 3600
  user_claim            = "sub"
  bound_audiences = ["vault"]
  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  allowed_redirect_uris = [
    "https://__VAULT_URL/ui/vault/auth/oidc/oidc/callback",    
    "https://__VAULT_URL/oidc/oidc/callback",
  ]
  groups_claim = "/resource_access/vault/roles"
}

data "vault_policy_document" "reader_policy" {
  rule {
    path         = "/secret/*"
    capabilities = ["list", "read"]
  }
}


resource "vault_policy" "reader_policy" {
  name   = "reader"
  policy = data.vault_policy_document.reader_policy.hcl
}

data "vault_policy_document" "manager_policy" {
  rule {
    path         = "/secret/*"
    capabilities = ["create", "update", "delete"]
  }
}

resource "vault_policy" "manager_policy" {
  name   = "management"
  policy = data.vault_policy_document.manager_policy.hcl
}

resource "vault_identity_oidc_role" "management_role" {
  name = "management"
  key  = vault_identity_oidc_key.key.name
}

resource "vault_identity_oidc_role" "reader_role" {
  name = "reader"
  key  = vault_identity_oidc_key.key.name
}

resource "vault_identity_group" "management_group" {
  name     = vault_identity_oidc_role.management_role.name
  type     = "external"
  policies = [
    vault_policy.manager_policy.name
  ]
}

resource "vault_identity_group_alias" "management_group_alias" {
  name           = "management"
  mount_accessor = vault_jwt_auth_backend.oidc_backend.accessor
  canonical_id   = vault_identity_group.management_group.id
}

resource "vault_identity_group" "reader_group" {
  name     = vault_identity_oidc_role.reader_role.name
  type     = "external"
  policies = [
    vault_policy.reader_policy.name
  ]
}

resource "vault_identity_group_alias" "reader_group_alias" {
  name           = "reader"
  mount_accessor = vault_jwt_auth_backend.oidc_backend.accessor
  canonical_id   = vault_identity_group.reader_group.id
}