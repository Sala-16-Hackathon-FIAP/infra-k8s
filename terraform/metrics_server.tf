# metrics-server — provides pod/node CPU & memory metrics to the Kubernetes
# Metrics API. Required for HorizontalPodAutoscaler (CPU-based) and `kubectl top`.
# It runs entirely in-cluster (no OIDC/IRSA or extra AWS permissions), so it is
# compatible with the AWS Academy LabRole constraints.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"
  namespace  = "kube-system"

  # EKS kubelet serving certs are not signed by the cluster CA; without this the
  # metrics-server cannot scrape kubelets and the Metrics API stays unavailable.
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  timeout    = 300
  depends_on = [aws_eks_node_group.default]
}
