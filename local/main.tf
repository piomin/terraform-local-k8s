terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "docker-desktop"
}

provider "kubectl" {
  config_path = "~/.kube/config"
  config_context = "docker-desktop"
}

data "kubectl_file_documents" "crds" {
  content = file("crds.yaml")
}

resource "kubectl_manifest" "crds-test" {
  for_each  = data.kubectl_file_documents.crds.manifests
  yaml_body = each.value
  wait = true
  server_side_apply = true
}

data "kubectl_file_documents" "olm" {
  content = file("olm.yaml")
}

resource "kubectl_manifest" "olm-test" {
  depends_on = [data.kubectl_file_documents.crds]
  for_each  = data.kubectl_file_documents.olm.manifests
  yaml_body = each.value
}

#locals {
#  raw_olm_manifests = split("---", file("crds.yaml"))
#  hcl_olm_manifests = [for olm_manifest in local.raw_olm_manifests : yamldecode(olm_manifest)]
#}
#
#resource "kubernetes_manifest" "olm-manifests" {
#  count = length(local.hcl_olm_manifests)
#  manifest = local.hcl_olm_manifests[count.index]
#}

#resource "kubernetes_manifest" "olm" {
#  depends_on = [kubernetes_manifest.crds]
#  manifest = yamldecode(file("olm.yaml"))
#}