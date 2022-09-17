terraform {
  required_providers {
    kind = {
      source = "tehcyx/kind"
      version = "0.0.12"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "default" {
  name = "test-2"
  wait_for_ready = true
  kind_config {
    kind = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }

    node {
      role = "worker"
      image = "kindest/node:v1.23.4"
    }

    node {
      role = "worker"
      image = "kindest/node:v1.23.4"
    }

    node {
      role = "worker"
      image = "kindest/node:v1.23.4"
    }
  }
}

provider "kubernetes" {
#  config_path = "~/.kube/config"
#  config_context = "kind-test-1"
  host = "${kind_cluster.default.endpoint}"
  cluster_ca_certificate = "${kind_cluster.default.cluster_ca_certificate}"
  client_certificate = "${kind_cluster.default.client_certificate}"
  client_key = "${kind_cluster.default.client_key}"
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "my-first-namespace"
  }
}