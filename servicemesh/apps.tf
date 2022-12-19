resource "kubernetes_namespace" "demo-apps" {
  metadata {
    name = "demo-apps"
  }
}

resource "kubernetes_secret" "person-db-secret" {
  depends_on = [kubernetes_namespace.demo-apps]
  metadata {
    name      = "person-db"
    namespace = "demo-apps"
  }
  data = {
    postgres-password = "person-db"
    password          = "person-db"
    database-user     = "person-db"
    database-name     = "person-name"
  }
}

resource "kubernetes_secret" "insurance-db-secret" {
  depends_on = [kubernetes_namespace.demo-apps]
  metadata {
    name      = "insurance-db"
    namespace = "demo-apps"
  }
  data = {
    postgres-password = "insurance-db"
    password          = "insurance-db"
    database-user     = "insurance-db"
    database-name     = "insurance-name"
  }
}

resource "helm_release" "person-db" {
  depends_on = [kubernetes_namespace.demo-apps]
  chart            = "postgresql"
  name             = "person-db"
  namespace        = "demo-apps"
  repository       = "https://charts.bitnami.com/bitnami"

  values = [
    file("manifests/person-db-values.yaml")
  ]
}

resource "helm_release" "insurance-db" {
  depends_on = [kubernetes_namespace.demo-apps]
  chart            = "postgresql"
  name             = "insurance-db"
  namespace        = "demo-apps"
  repository       = "https://charts.bitnami.com/bitnami"

  values = [
    file("manifests/insurance-db-values.yaml")
  ]
}

resource "kubernetes_deployment" "quarkus-insurance-app" {
  depends_on = [helm_release.insurance-db]
  metadata {
    name      = "quarkus-insurance-app"
    namespace = "demo-apps"
  }
  spec {
    selector {
      match_labels = {
        app = "quarkus-insurance-app"
        version = "v1"
      }
    }
    template {
      metadata {
        labels = {
          app = "quarkus-insurance-app"
          version = "v1"
        }
        annotations = {
          "sidecar.istio.io/inject": "true"
        }
      }
      spec {
        container {
          name = "quarkus-insurance-app"
          image = "piomin/quarkus-insurance-app:v1"
          port {
            container_port = 8080
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "database-user"
                name = "insurance-db"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "password"
                name = "insurance-db"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                key = "database-name"
                name = "insurance-db"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "quarkus-insurance-app" {
  depends_on = [helm_release.insurance-db]
  metadata {
    name = "quarkus-insurance-app"
    namespace = "demo-apps"
    labels = {
      app = "quarkus-insurance-app"
    }
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = "quarkus-insurance-app"
    }
    port {
      port = 8080
      name = "http"
    }
  }
}

resource "kubernetes_deployment" "quarkus-person-app-v1" {
  depends_on = [helm_release.person-db]
  metadata {
    name      = "quarkus-person-app-v1"
    namespace = "demo-apps"
  }
  spec {
    selector {
      match_labels = {
        app = "quarkus-person-app"
        version = "v1"
      }
    }
    template {
      metadata {
        labels = {
          app = "quarkus-person-app"
          version = "v1"
        }
        annotations = {
          "sidecar.istio.io/inject": "true"
        }
      }
      spec {
        container {
          name = "quarkus-person-app"
          image = "piomin/quarkus-person-app:v1"
          port {
            container_port = 8080
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "database-user"
                name = "person-db"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "password"
                name = "person-db"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                key = "database-name"
                name = "person-db"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "quarkus-person-app-v2" {
  depends_on = [helm_release.person-db]
  metadata {
    name      = "quarkus-person-app-v2"
    namespace = "demo-apps"
  }
  spec {
    selector {
      match_labels = {
        app = "quarkus-person-app"
        version = "v2"
      }
    }
    template {
      metadata {
        labels = {
          app = "quarkus-person-app"
          version = "v2"
        }
        annotations = {
          "sidecar.istio.io/inject": "true"
        }
      }
      spec {
        container {
          name = "quarkus-person-app"
          image = "piomin/quarkus-person-app:v2"
          port {
            container_port = 8080
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "database-user"
                name = "person-db"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "password"
                name = "person-db"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                key = "database-name"
                name = "person-db"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "quarkus-person-app" {
  depends_on = [helm_release.person-db]
  metadata {
    name = "quarkus-person-app"
    namespace = "demo-apps"
    labels = {
      app = "quarkus-person-app"
    }
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = "quarkus-person-app"
    }
    port {
      port = 8080
      name = "http"
    }
  }
}