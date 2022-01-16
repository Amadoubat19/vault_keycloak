
terraform {
  required_providers {
    keycloak = {
      source = "mrparkers/keycloak"
      version = "3.6.0"
    }
    keycloaky = {
      source = "StatueFungus/keycloak"
      version = "2.3.2"
    }
  }
}

provider "keycloak" {
  username      = var.username
  password      = var.passwd
  client_id = var.client_id
  url           = var.url
}

provider "keycloaky" {
  username      = var.username
  password      = var.passwd
  client_id = var.client_id
  url           = var.url
}


resource "keycloak_realm" "realm" {
  realm             = "vault"
  enabled           = true
  display_name = "Vault authentication management"
}

resource "keycloak_user" "user_with_initial_password" {
  realm_id   = keycloak_realm.realm.id
  count = length(var.users)
  username   = var.users[count.index].username
  enabled    = true

  email      = var.users[count.index].email
  first_name = var.users[count.index].first_name
  last_name  = var.users[count.index].last_name

  initial_password {
    value     = var.users[count.index].initial_password
    temporary = false
  }
}

resource "keycloak_openid_client" "openid_client" {
  realm_id            = keycloak_realm.realm.id
  client_id           = "vault"

  name                = "vault"
  enabled             = true
  standard_flow_enabled = true
  direct_access_grants_enabled = true
  
  access_type         = "PUBLIC"
  valid_redirect_uris = [
    "https://__VAULT_URL__/ui/vault/auth/oidc/oidc/callback",    
    "https://__VAULT_URL__/oidc/oidc/callback",
  ]

  login_theme = "keycloak"
}

resource "keycloak_role" "management_role" {
  realm_id    = keycloak_realm.realm.id
  client_id   = keycloak_openid_client.openid_client.id
  name        = "management"
  description = "Management role"
  composite_roles = [
    keycloak_role.reader_role.id
  ]
}

resource "keycloak_role" "reader_role" {
  realm_id    = keycloak_realm.realm.id
  client_id   = keycloak_openid_client.openid_client.id
  name        = "reader"
  description = "Reader role"
}

resource "keycloak_user_roles" "alice_roles" {
  realm_id = keycloak_realm.realm.id
  user_id  = keycloak_user.user_with_initial_password[0].id

  role_ids = [
    keycloak_role.reader_role.id,
  ]
}

resource "keycloak_user_roles" "bob_roles" {
  realm_id = keycloak_realm.realm.id
  user_id  = keycloak_user.user_with_initial_password[1].id

  role_ids = [
    keycloak_role.management_role.id,
  ]
}

resource "keycloak_openid_user_client_role_protocol_mapper" "user_realm_role_mapper" {
  provider = keycloaky
  realm_id  = keycloak_realm.realm.id
  client_id = keycloak_openid_client.openid_client.id
  name = "user-client-role-mapper"
  claim_name  = "resource_access.vault.roles"
  multivalued = true
}

