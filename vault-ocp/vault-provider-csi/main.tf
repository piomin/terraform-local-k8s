provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = var.cluster-context
}

provider "vault" {
  token = "root"
  address = var.vault-addr
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kv_secret_v2" "secret" {
  mount = "secret"
  name = "db-pass"
  data_json = jsonencode(
    {
      password = "hunter"
    }
  )
}

data "kubernetes_service_account" "vault-sa" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}

data "kubernetes_secret" "vault-default" {
  metadata {
    name      = data.kubernetes_service_account.vault-sa.default_secret_name
    namespace = "vault"
  }
}

resource "vault_kubernetes_auth_backend_config" "example" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://172.30.0.1:443"
  kubernetes_ca_cert     = data.kubernetes_secret.vault-default.data["ca.crt"]
  token_reviewer_jwt     = data.kubernetes_secret.vault-default.data.token
}

resource "vault_policy" "internal-app" {
  name = "internal-app"

  policy = <<EOT
path "secret/data/db-pass" {
  capabilities = ["read"]
}
EOT
}

resource "kubernetes_service_account" "webapp-sa" {
  metadata {
    name      = "webapp-sa"
    namespace = "default"
  }
}

resource "vault_kubernetes_auth_backend_role" "internal-role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "webapp"
  bound_service_account_names      = ["webapp-sa"]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = ["internal-app"]
}

resource "kubernetes_manifest" "vault-database" {
  manifest = {
    "apiVersion" = "secrets-store.csi.x-k8s.io/v1alpha1"
    "kind"       = "SecretProviderClass"
    "metadata" = {
      "name"      = "vault-database"
      "namespace" = "default"
    }
    "spec" = {
      "provider"   = "vault"
      "parameters" = {
        "vaultAddress" = "http://vault.vault.svc:8200"
        "roleName"     = "webapp"
        "objects"      = "- objectName: \"db-password\"\n  secretPath: \"secret/data/db-pass\"\n  secretKey: \"password\""
      }
    }
  }
}