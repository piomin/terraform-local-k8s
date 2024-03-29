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

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_service_account" "vault-sa" {
  depends_on = [kubernetes_namespace.vault]
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}

resource "kubernetes_secret_v1" "vault-secret" {
  depends_on = [kubernetes_namespace.vault]
  metadata {
    name = "vault-token"
    namespace = "vault"
    annotations = {
      "kubernetes.io/service-account.name" = "vault"
    }
  }

  type = "kubernetes.io/service-account-token"
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
  repository       = "https://helm.releases.hashicorp.com"

  values = [
    file("values.yaml")
  ]
}