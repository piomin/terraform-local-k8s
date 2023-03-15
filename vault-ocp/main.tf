provider "vault" {
  token = "root"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = var.cluster-context
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = var.cluster-context
  }
}

resource "kubernetes_cluster_role_binding" "privileged" {
  metadata {
    name = "system:openshift:scc:privileged"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:openshift:scc:privileged"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "secrets-store-csi-driver"
    namespace = "k8s-secrets-store-csi"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "vault-csi-provider"
    namespace = "vault"
  }
}

resource "helm_release" "secrets-store-csi-driver" {
  chart            = "secrets-store-csi-driver"
  name             = "csi-secrets-store"
  namespace        = "k8s-secrets-store-csi"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"

  set {
    name  = "linux.providersDir"
    value = "/var/run/secrets-store-csi-providers"
  }

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

resource "helm_release" "vault" {
  chart            = "vault"
  name             = "vault"
  namespace        = "vault"
  create_namespace = true
  repository       = "https://helm.releases.hashicorp.com"

  values = [
    file("values.yaml")
  ]
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [helm_release.vault]

  create_duration = "60s"
}

resource "vault_auth_backend" "kubernetes" {
  depends_on = [time_sleep.wait_60_seconds]
  type       = "kubernetes"
}

resource "vault_kv_secret" "secret" {
  path = "secret/db-pass"
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

resource "vault_kubernetes_auth_backend_role" "webapp-role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "webapp"
  bound_service_account_names      = ["webapp"]
  bound_service_account_namespaces = ["webapp"]
  token_ttl                        = 3600
  token_policies                   = ["argocd"]
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

resource "vault_policy" "internal-app" {
  name = "internal-app"

  policy = <<EOT
path "secret/data/db-pass" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "internal-role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "webapp"
  bound_service_account_names      = ["webapp-sa"]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = ["internal-app"]
}

data "kubernetes_service_account" "webapp-sa" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}

#resource "kubernetes_manifest" "vault-database" {
#  manifest = {
#    "apiVersion" = "secrets-store.csi.x-k8s.io/v1alpha1"
#    "kind"       = "SecretProviderClass"
#    "metadata" = {
#      "name"      = "vault-database"
#      "namespace" = "default"
#    }
#    "spec" = {
#      "provider"   = "vault"
#      "parameters" = {
#        "vaultAddress" = "http://vault.vault.svc:8200"
#        "roleName"     = "webapp"
#        "objects"      = [{
#          "objectName" = "db-password"
#          "secretPath" = "secret/data/db-pass"
#          "secretKey"  = "password"
#        }]
#      }
#    }
#  }
#}