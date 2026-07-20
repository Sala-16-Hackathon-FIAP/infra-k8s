resource "kubernetes_namespace" "messaging" {
  metadata {
    name = "messaging"
  }

  depends_on = [aws_eks_node_group.default]
}

resource "kubernetes_secret" "rabbitmq" {
  metadata {
    name      = "rabbitmq-secrets"
    namespace = kubernetes_namespace.messaging.metadata[0].name
  }

  data = {
    RABBITMQ_DEFAULT_USER = var.rabbitmq_username
    RABBITMQ_DEFAULT_PASS = var.rabbitmq_password
  }
}

resource "kubernetes_stateful_set" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.messaging.metadata[0].name
    labels = {
      app = "rabbitmq"
    }
  }

  spec {
    service_name = "rabbitmq"
    replicas     = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3.13-management"

          port {
            container_port = 5672
            name           = "amqp"
          }

          port {
            container_port = 15672
            name           = "management"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.rabbitmq.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }

          readiness_probe {
            tcp_socket {
              port = 5672
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          liveness_probe {
            tcp_socket {
              port = 5672
            }
            initial_delay_seconds = 60
            period_seconds        = 15
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.messaging]
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.messaging.metadata[0].name
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }

    type = "ClusterIP"
  }
}
