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

resource "kubernetes_cluster_role_binding" "argocd-application-controller-crb" {
  depends_on = [kubernetes_manifest.gitops]
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
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [kubernetes_manifest.gitops]

  create_duration = "60s"
}

resource "helm_release" "argocd-apps" {
  name = "argocd-apps"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "openshift-gitops"
  version    = "0.0.6"

  values = [
    file("apps.yaml")
  ]

  depends_on       = [time_sleep.wait_60_seconds]

}