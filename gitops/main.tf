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

// (1) Install Argo CD through the OpenShift GitOps Operator
resource "kubernetes_manifest" "gitops" {
  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "Subscription"
    "metadata" = {
      "name"      = "openshift-gitops-operator"
      "namespace" = "openshift-operators"
    }
    "spec" = {
      "channel"             = "latest"
      "installPlanApproval" = "Automatic"
      "name"                = "openshift-gitops-operator"
      "source"              = "redhat-operators"
      "sourceNamespace"     = "openshift-marketplace"
    }
  }
}

// (2) Create namespace for SealedSecrets
resource "kubernetes_namespace" "sealed-secrets-ns" {
  metadata {
    name = "sealed-secrets"
  }
}

// (3) Create keys for SealedSecrets
resource "kubernetes_secret" "sealed-secrets-key" {
  depends_on = [kubernetes_namespace.sealed-secrets-ns]
  metadata {
    name = "sealed-secrets-key"
    namespace = "sealed-secrets"
  }
  data = {
    "tls.crt" = file("keys/tls.crt")
    "tls.key" = "${file("keys/tls.key")}"
  }
  type = "kubernetes.io/tls"
}

// (4) Wait on OpenShift GitOps installation
resource "time_sleep" "wait_120_seconds" {
  depends_on = [kubernetes_manifest.gitops]

  create_duration = "120s"
}

// (5) Create Argo CD projects and init apps
resource "helm_release" "argocd-apps" {
  name  = "argocd-apps"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "openshift-gitops"
  version          = "1.2.0"

  values = [
    file("apps.yaml")
  ]

  depends_on = [time_sleep.wait_120_seconds]
}

// (6) Add cluster privileges to ArgoCD account
resource "kubernetes_cluster_role_binding" "argocd-application-controller-crb" {
  metadata {
    name = "argocd-application-controller-cluster-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "openshift-gitops-argocd-application-controller"
    namespace = "openshift-gitops"
  }

  depends_on = [time_sleep.wait_120_seconds]
}

resource "kubernetes_manifest" "cluster-admins-group" {
  manifest = {
    "apiVersion" = "user.openshift.io/v1"
    "kind"       = "Group"
    "metadata"   = {
      "name" = "cluster-admins"
    }
    "users" = [
      "opentlc-mgr",
      "admin"
    ]
  }
}