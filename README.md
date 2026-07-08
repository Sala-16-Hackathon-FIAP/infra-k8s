# infra-k8s

Terraform infrastructure for provisioning the foundational AWS resources for the FIAP-X video processing platform: networking, EKS cluster, S3 storage, and RabbitMQ messaging.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  VPC 10.0.0.0/16                                        │
│                                                         │
│  ┌──────────────────┐  ┌──────────────┐ ┌─────────────┐ │
│  │ Public Subnet    │  │ Private      │ │ Private     │ │
│  │ 10.0.1.0/24      │  │ Subnet A     │ │ Subnet B    │ │
│  │ (us-east-1a)     │  │ 10.0.2.0/24  │ │ 10.0.3.0/24 │ │
│  │                  │  │ (us-east-1a) │ │ (us-east-1b)│ │
│  │ • EKS Nodes      │  │ • RDS (AZ-a) │ │ • RDS (AZ-b)│ │
│  │ • Load Balancers │  │              │ │             │ │
│  └──────────────────┘  └──────────────┘ └─────────────┘ │
│                                                         │
│  Internet GW ─── NAT GW                                │
└─────────────────────────────────────────────────────────┘
```

## Resources Provisioned

### Networking (`network.tf`)
- **VPC**: `10.0.0.0/16` with DNS support enabled
- **Public Subnet**: `10.0.1.0/24` (us-east-1a) — EKS nodes, load balancers
- **Private Subnet A**: `10.0.2.0/24` (us-east-1a) — RDS instances
- **Private Subnet B**: `10.0.3.0/24` (us-east-1b) — RDS HA
- **Internet Gateway**: Public internet access
- **NAT Gateway**: Outbound access for private subnets
- **Route Tables**: Public (IGW) and private (NAT GW)

### EKS Cluster (`eks.tf`)
- **Cluster**: `fiapx-cluster` (Kubernetes 1.31)
- **Node Group**: `fiapx-nodes` with `t3.medium` instances (min: 1, max: 4, desired: 2)
- **IAM**: Uses pre-existing `LabRole` (AWS Academy compatible — no OIDC/IRSA)

### S3 Storage (`s3.tf`)
- **Bucket**: `fiapx-videos-<account_id>` for video uploads and processed frames
- **Security**: All public access blocked

### RabbitMQ (`rabbitmq.tf`)
- **Helm Chart**: Bitnami RabbitMQ v14.6.6 in `messaging` namespace
- **Service**: ClusterIP (internal access at `rabbitmq.messaging.svc.cluster.local`)
- **Management UI**: Exposed via NLB on port 15672 (`k8s/rabbitmq-management-svc.yaml`)
- **Persistence**: Disabled (no EBS CSI driver in Academy environment)
- **Resources**: 200m CPU request, 256Mi-512Mi memory

### Load Balancer Controller (`lb_controller.tf`)
- Not installed — AWS Academy does not support OIDC identity providers (required for IRSA)
- NLB provisioning is handled by the native EKS cloud controller manager using LabRole

## Terraform State

State is stored remotely in S3:

```
Bucket: fiapx-terraform-state
Key:    k8s/terraform.tfstate
Region: us-east-1
```

The CI/CD pipeline automatically creates the state bucket if it doesn't exist.

## Outputs

| Output                         | Description                                    |
|--------------------------------|------------------------------------------------|
| `cluster_name`                 | EKS cluster name (`fiapx-cluster`)             |
| `cluster_endpoint`             | EKS cluster API endpoint                       |
| `cluster_certificate_authority`| EKS cluster CA certificate (base64)            |
| `vpc_id`                       | VPC ID                                         |
| `vpc_cidr_block`               | VPC CIDR block (`10.0.0.0/16`)                 |
| `public_subnet_id`             | Public subnet ID                               |
| `private_subnet_a_id`          | Private subnet A ID (used by infra-db for RDS) |
| `private_subnet_b_id`          | Private subnet B ID (used by infra-db for RDS) |
| `s3_videos_bucket_name`        | S3 bucket name for video storage               |

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/terraform-k8s.yml`) runs automatically:

- **On pull request to `main`**: Runs `terraform init` and `terraform plan` (validation only)
- **On push to `main`**: Runs full `terraform init`, `plan`, `apply`, updates kubeconfig, and exposes RabbitMQ Management UI
- **State bucket**: Auto-created if it doesn't exist

### Required GitHub Secrets

| Secret                  | Description                        |
|-------------------------|------------------------------------|
| `AWS_ACCESS_KEY_ID`     | AWS Academy access key             |
| `AWS_SECRET_ACCESS_KEY` | AWS Academy secret key             |
| `AWS_SESSION_TOKEN`     | AWS Academy session token          |
| `AWS_ACCOUNT_ID`        | AWS account ID (used in IAM ARNs)  |
| `RABBITMQ_USERNAME`     | RabbitMQ admin username            |
| `RABBITMQ_PASSWORD`     | RabbitMQ admin password            |

## Dependencies

This is the **first module** to be applied. Other modules depend on it:

### Deploy Order

```
1. infra-k8s    <-- this repo (VPC, EKS, S3, RabbitMQ)
2. infra-db     (reads VPC/subnet outputs via remote state)
3. Microservices (deployed to EKS via CI/CD)
```

## Usage

### Apply manually (local)

```bash
cd terraform
terraform init
terraform plan \
  -var="aws_account_id=YOUR_ACCOUNT_ID" \
  -var="rabbitmq_username=admin" \
  -var="rabbitmq_password=YOUR_PASSWORD"

terraform apply \
  -var="aws_account_id=YOUR_ACCOUNT_ID" \
  -var="rabbitmq_username=admin" \
  -var="rabbitmq_password=YOUR_PASSWORD"
```

### Configure kubectl after apply

```bash
aws eks update-kubeconfig --name fiapx-cluster --region us-east-1
```

### Expose RabbitMQ Management UI

```bash
kubectl apply -f k8s/rabbitmq-management-svc.yaml
```

### Verify cluster

```bash
kubectl get nodes
kubectl get pods -n messaging
```

## Technology Stack

- **Terraform** ~> 5.0 (AWS, Kubernetes, Helm providers)
- **AWS EKS** Kubernetes 1.31
- **AWS VPC** with public and private subnets
- **AWS S3** for video storage
- **RabbitMQ** via Bitnami Helm chart v14.6.6
- **S3** Remote state backend
- **GitHub Actions** CI/CD

## Acknowledgments

This project was developed with the assistance of [Claude](https://claude.com/claude-code) (Anthropic) as an AI pair-programming tool for code implementation, debugging, and documentation.
