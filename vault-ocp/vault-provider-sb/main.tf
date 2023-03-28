provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = var.cluster-context
}

provider "vault" {
  token = "root"
  address = var.vault-addr
}

data "vault_auth_backend" "kubernetes" {
  path       = "kubernetes"
}

data "kubernetes_secret" "vault-token" {
  metadata {
    name      = "vault-token"
    namespace = "vault"
  }
}

resource "vault_kubernetes_auth_backend_config" "example" {
  backend                = data.vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://172.30.0.1:443"
  kubernetes_ca_cert     = data.kubernetes_secret.vault-token.data["ca.crt"]
  token_reviewer_jwt     = data.kubernetes_secret.vault-token.data.token
}

resource "vault_kubernetes_auth_backend_role" "webapp-role" {
  backend                          = data.vault_auth_backend.kubernetes.path
  role_name                        = "webapp"
  bound_service_account_names      = ["webapp"]
  bound_service_account_namespaces = ["webapp"]
  token_ttl                        = 3600
  token_policies                   = ["argocd", "internal-es"]
}

resource "vault_mount" "kv-v2" {
  path        = "kv-v2"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_policy" "read-key" {
  name = "argocd"

  policy = <<EOT
path "kv-v2/data/argocd" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "internal-es" {
  name = "internal-es"

  policy = <<EOT
path "secret/data/example" {
  capabilities = ["read"]
}
EOT
}