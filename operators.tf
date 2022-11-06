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

resource "kubernetes_manifest" "pipelines" {
  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "Subscription"
    "metadata" = {
      "name"      = "openshift-pipelines-operator-rh"
      "namespace" = "openshift-operators"
    }
    "spec" = {
      "channel"             = "latest"
      "installPlanApproval" = "Automatic"
      "name"                = "openshift-pipelines-operator-rh"
      "source"              = "redhat-operators"
      "sourceNamespace"     = "openshift-marketplace"
    }
  }
}

resource "kubernetes_manifest" "external-secrets" {
  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "Subscription"
    "metadata" = {
      "name"      = "external-secrets-operator"
      "namespace" = "openshift-operators"
    }
    "spec" = {
      "channel"             = "alpha"
      "installPlanApproval" = "Automatic"
      "name"                = "external-secrets-operator"
      "source"              = "community-operators"
      "sourceNamespace"     = "openshift-marketplace"
      "startingCSV"         = "external-secrets-operator.v0.6.1"
    }
  }
}

resource "kubernetes_namespace" "resource-locker-ns" {
  metadata {
    name = "resource-locker-operator"
  }
}

resource "kubernetes_manifest" "resource-locker-group" {
  depends_on = [kubernetes_namespace.resource-locker-ns]
  manifest = {
    "apiVersion" = "operators.coreos.com/v1"
    "kind"       = "OperatorGroup"
    "metadata" = {
      "name"      = "resource-locker-operator-1"
      "namespace" = "resource-locker-operator"
    }
    "spec" = {

    }
  }
}

resource "kubernetes_manifest" "resource-locker" {
  depends_on = [kubernetes_namespace.resource-locker-ns, kubernetes_manifest.resource-locker-group]
  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "Subscription"
    "metadata" = {
      "name"      = "resource-locker-operator"
      "namespace" = "resource-locker-operator"
    }
    "spec" = {
      "channel"             = "alpha"
      "installPlanApproval" = "Automatic"
      "name"                = "resource-locker-operator"
      "source"              = "community-operators"
      "sourceNamespace"     = "openshift-marketplace"
    }
  }
}

resource "kubernetes_namespace" "sealed-secrets-ns" {
  metadata {
    name = "sealed-secrets"
  }
}

resource "kubernetes_service_account" "sealed-secrets-sa" {
  depends_on = [kubernetes_namespace.sealed-secrets-ns]
  metadata {
    name = "sealed-secrets"
    namespace = "sealed-secrets"
  }
}
resource "kubernetes_cluster_role_binding" "sealed-secrets-sa-privileged" {
  depends_on = [kubernetes_service_account.sealed-secrets-sa]
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
    name      = "sealed-secrets"
    namespace = "sealed-secrets"
  }
}

resource "helm_release" "sealed-secrets" {
  depends_on = [kubernetes_namespace.sealed-secrets-ns, kubernetes_secret.sealed-secrets-key, kubernetes_service_account.sealed-secrets-sa, kubernetes_cluster_role_binding.sealed-secrets-sa-privileged]
  chart      = "sealed-secrets"
  name       = "sealed-secrets"
  namespace  = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = "sealed-secrets"
  }
}

resource "kubernetes_secret" "sealed-secrets-key" {
  depends_on = [kubernetes_namespace.sealed-secrets-ns]
  metadata {
    name = "sealed-secrets-key"
    namespace = "sealed-secrets"
  }
  data = {
    "tls.crt" = "${file("tls.crt")}"
    "tls.key" = "${file("tls.key")}"
  }
  type = "kubernetes.io/tls"
}

resource "kubernetes_manifest" "cluster-admins-group" {
  manifest = {
    "apiVersion" = "user.openshift.io/v1"
    "kind"       = "Group"
    "metadata"   = {
      "name" = "cluster-admins"
    }
    "users" = [
      "opentlc-mgr"
    ]
  }
}

resource "kubernetes_manifest" "app-owners" {
  manifest = {
    "apiVersion" = "user.openshift.io/v1"
    "kind"       = "Group"
    "metadata"   = {
      "name" = "app-owners"
    }
    "users" = [
      "pminkows"
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

resource "helm_release" "vault" {
  chart            = "vault"
  name             = "vault"
  namespace        = "vault"
  create_namespace = true
  repository       = "https://helm.releases.hashicorp.com"

  values = [
    file("vault-values.yaml")
  ]
}

resource "helm_release" "argocd-apps" {
  name  = "argocd-apps"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "openshift-gitops"
  version          = "0.0.1"

  values = [
    file("apps.yaml")
  ]

  depends_on = [kubernetes_manifest.gitops, helm_release.vault, helm_release.sealed-secrets]

}