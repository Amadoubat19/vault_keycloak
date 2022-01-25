provider "vault" {
  address = format("https://%s", var.vault_url)
  token = var.vault_token
}

resource "vault_identity_oidc_key" "key" {
  name      = "key"
  algorithm = "RS256"
}

resource "vault_jwt_auth_backend" "oidc_backend" {
    description         = "Demonstration of the Terraform JWT auth backend"
    path                = "oidc"
    type                = "oidc"
    oidc_discovery_url  = format("https://%s/auth/realms/vault", var.keycloak_url)
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
    format("https://%s/ui/vault/auth/oidc/oidc/callback", var.vault_url),
    format("https://%s/oidc/oidc/callback", var.vault_url),
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

# resource "vault_audit" "file" {
#   type = "file"

#   options = {
#     file_path = "/var/lib/vault/vault_audit.log"
#   }
# }

# resource "vault_pki_secret_backend" "pki-tidi" {
#   path        = "pki-tidi"
# }

# resource "vault_pki_secret_backend_role" "role" {
#   backend          = vault_pki_secret_backend.domain_tidi.path
#   name             = "domain_tidi"
#   ttl              = 30000000
#   max_ttl          = 30000000
#   allowed_domains  = ["toudhere"]
#   allow_subdomains = true
# }

resource "vault_policy" "nginx-secret" {
  name = "nginx-secret"
  policy = <<EOT
    path "nginx-secret/*" {
      capabilities = ["read"]
    }
  EOT
}

# resource "vault_policy" "cert-manager" {
#   name = "cert-manager"

#   policy = <<EOF
#     path "pki-tidi/*" { 
#       capabilities = ["read", "list"] 
#     }
#     path "pki-tidi/roles/domain_4as" { 
#       capabilities = ["create", "update"] 
#     }
#     path "pki-tidi/sign/domain_4as"  { 
#       capabilities = ["create", "update"]
#     }
#     path "pki-tidi/issue/domain_4as" { 
#       capabilities = ["create"] 
#     }
#   EOF
# }

resource "vault_mount" "nginx-secret" {
  path        = "nginx-secret"
  type        = "kv-v2"
}

resource "vault_generic_secret" "nginx-secret-data" {
  path = "nginx-secret/data"

  data_json = <<EOT
  {
    "username":   "kernelPanic",
    "passwd": "hahahaha"
  }
EOT
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kube-vpn" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://XXX:6443" # Kubernetes api server host and port
  kubernetes_ca_cert     = file("../files/caKube.crt") # Kube ca certificate 
  token_reviewer_jwt     = file("../files/kubernetes.key") # Token reviewer with auth-delegator
  issuer                 = "https://kubernetes.default.svc.cluster.local"
}

resource "vault_kubernetes_auth_backend_role" "kube-vpn" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "kube-vpn"
  bound_service_account_names      = ["default", "vault-secret"]
  bound_service_account_namespaces = ["default", "vault"]
  token_ttl                        = 3600
  token_policies                   = ["default", "nginx-secret"]
  audience                         = null
}