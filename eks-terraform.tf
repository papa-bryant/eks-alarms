provider "aws" {
  region = "us-east-1"
}

# Create VPC for EKS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc-cl"
  cidr = "172.16.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["172.16.1.0/24", "172.16.2.0/24"]
  public_subnets  = ["172.16.101.0/24", "172.16.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  private_subnet_tags = {
    "kubernetes.io/cluster/eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"   = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/eks-cluster" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Create EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "eks-cluster"
  cluster_version = "1.27"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets

  # Avoid public endpoint access for better security
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true  # Enable for easier initial access, consider disabling in production

  # Managed node group with t3.small instances
  eks_managed_node_groups = {
    default = {
      name = "eks-node-group"

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 3
      desired_size = 2

      update_config = {
        max_unavailable_percentage = 50
      }

      # IAM role for the node group
      iam_role_additional_policies = {
        AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        ECRReadOnly          = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }

      # Add labels for the node group
      labels = {
        Environment = "dev"
        NodeType    = "standard"
      }

      tags = {
        Environment = "dev"
        Terraform   = "true"
      }
    }
  }

  # Configure AWS Auth to allow access to EKS
  manage_aws_auth_configmap = false

  # Enable EKS add-ons
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
    amazon-cloudwatch-observability = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Output values
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}