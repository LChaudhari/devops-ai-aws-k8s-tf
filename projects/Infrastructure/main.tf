module "vpc" {
  source = "./modules/vpc"

  vpc_name           = var.vpc_name
  vpc_id             = var.vpc_id
  cidr_block         = var.vpc_cidr
  igw_id             = var.igw_id
  subnet_cidrs       = [for s in var.subnets : s.cidr_block]
  availability_zones = [for s in var.subnets : s.availability_zone]
  cluster_name       = var.cluster_name
}


module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name

  instance_types = var.instance_types
  min_size       = var.min_size
  desired_size   = var.desired_size
  max_size       = var.max_size

  subnet_ids = module.vpc.subnet_ids
  depends_on = [module.vpc]
}

module "ecr" {
  source = "./modules/ecr"

  repositories = var.repositories
}

module "lambda" {
  source = "./modules/lambda"

  lambda_role_name        = var.lambda_role_name
  bedrock_agent_role_name = var.bedrock_agent_role_name
  lambda_runtime          = var.lambda_runtime
  lambda_timeout          = var.lambda_timeout
  log_group_name          = var.log_group_name
}


provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  alias = "eks"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}


module "argocd" {
  source = "./modules/argocd"

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  depends_on = [module.eks]
}

