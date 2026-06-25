region   = "ap-south-1"
vpc_name = "EKS-Demo-VPC"
vpc_cidr = "172.31.0.0/16"
vpc_id   = "vpc-0aa2309de49e1232f" # Replace with your actual VPC ID
igw_id   = "igw-0cd2e9fc1ba9fe976" # Replace with your actual Internet Gateway ID

subnets = [
  {
    name              = "subnet-1"
    cidr_block        = "172.31.1.0/24"
    availability_zone = "ap-south-1a"
  },

  {
    name              = "subnet-2"
    cidr_block        = "172.31.2.0/24"
    availability_zone = "ap-south-1b"
  }
]

cluster_name    = "eks-cluster"
node_group_name = "eks-node-group"

instance_types = ["t3.large"]
capacity_type  = "ON_DEMAND"

desired_size = 1
min_size     = 1
max_size     = 2

disk_size = 30

repositories = [
  "frontend",
  "gateway",
  "auth",
  "order-service",
  "orders",
  "product-service",
  "user-service"
]

# AIOps Lambda module
lambda_role_name        = "aiops-lambda-role"
bedrock_agent_role_name = "aiops-bedrock-agent-role"
lambda_runtime          = "python3.12"
lambda_timeout          = 30
log_group_name          = "/eks/boutique/pods"