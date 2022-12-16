resource "kubernetes_namespace" "istio" {
  metadata {
    name = "istio"
  }
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [kubernetes_manifest.ossm]

  create_duration = "60s"
}

resource "kubectl_manifest" "basic" {
  depends_on = [time_sleep.wait_60_seconds, kubernetes_namespace.istio]
  yaml_body = <<YAML
kind: ServiceMeshControlPlane
apiVersion: maistra.io/v2
metadata:
  name: basic
  namespace: istio
spec:
  version: v2.3
  tracing:
    type: Jaeger
    sampling: 10000
  policy:
    type: Istiod
  telemetry:
    type: Istiod
  addons:
    jaeger:
      install:
        storage:
          type: Memory
    prometheus:
      enabled: true
    kiali:
      enabled: true
    grafana:
      enabled: true
YAML
}

resource "kubectl_manifest" "console" {
  depends_on = [time_sleep.wait_60_seconds, kubernetes_namespace.istio]
  yaml_body = <<YAML
kind: OSSMConsole
apiVersion: kiali.io/v1alpha1
metadata:
  name: ossmconsole
  namespace: istio
spec:
  kiali:
    serviceName: ''
    serviceNamespace: ''
    servicePort: 0
    url: ''
YAML
}