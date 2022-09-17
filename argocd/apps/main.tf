provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "default/api-p2rdtgf7-eastus-aroapp-io:6443/kube:admin"
}

resource "kubernetes_manifest" "cluster-config-argocd-app" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "cluster-config"
      "namespace" = "openshift-gitops"
    }
    spec = {
      "destination" = {
        server = "https://kubernetes.default.svc"
      }
      "project" = "default"
      "source" = {
        "path"           = "manifests"
        "repoURL"        = "https://github.com/piomin/openshift-cluster-config.git"
        "targetRevision" = "HEAD"
      }
    }
  }
}

resource "kubernetes_manifest" "cicd-config-argocd-app" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "cicd-config"
      "namespace" = "openshift-gitops"
    }
    spec = {
      "destination" = {
        server = "https://kubernetes.default.svc"
      }
      "project" = "default"
      "source" = {
        "path"           = "cicd"
        "repoURL"        = "https://github.com/piomin/openshift-cluster-config.git"
        "targetRevision" = "HEAD"
        "directory" = {
          "recurse" = true
          "jsonnet" = {}
        }
      }
    }
  }
}

resource "kubernetes_cluster_role_binding" "openshift-gitops-argocd-controller-binding" {
  metadata {
    name = "openshift-gitops-argocd-controller-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "openshift-gitops-argocd-application-controller"
    namespace = "openshift-gitops"
  }
}