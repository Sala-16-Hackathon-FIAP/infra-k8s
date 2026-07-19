resource "kubernetes_namespace" "messaging" {
  metadata {
    name = "messaging"
  }

  depends_on = [aws_eks_node_group.default]
}

resource "helm_release" "rabbitmq" {
  name       = "rabbitmq"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq"
  version    = "14.6.6"
  namespace  = kubernetes_namespace.messaging.metadata[0].name

  set {
    name  = "auth.username"
    value = var.rabbitmq_username
  }

  set_sensitive {
    name  = "auth.password"
    value = var.rabbitmq_password
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  # Persistence disabled — cluster does not have the aws-ebs-csi-driver addon.
  # To enable, add the addon via aws_eks_addon in eks.tf and set to true.
  set {
    name  = "persistence.enabled"
    value = "false"
  }

  set {
    name  = "resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  timeout      = 600
  wait         = false
  force_update = true

  depends_on = [kubernetes_namespace.messaging]
}
