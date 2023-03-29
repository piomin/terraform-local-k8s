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

resource "vault_kubernetes_auth_backend_role" "es-role" {
  backend                          = data.vault_auth_backend.kubernetes.path
  role_name                        = "es"
  bound_service_account_names      = ["cluster-external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_ttl                        = 3600
  token_policies                   = ["internal-es"]
}

resource "vault_policy" "internal-es" {
  name = "internal-es"

  policy = <<EOT
path "secret/data/example" {
  capabilities = ["read"]
}
EOT
}