variable "region" {
  description = "The name of the region"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "igw_id" {
  description = "Internet Gateway ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR Value"
  type        = string
}

variable "subnets" {
  description = "List of subnets"
  type = list(object({
    name              = string
    cidr_block        = string
    availability_zone = string
  }))
}


variable "cluster_name" {
  description = "The name of the Kubernetes Cluster"
  type        = string
}

variable "node_group_name" {
  type        = string
  description = "EKS node group name"
}

variable "instance_types" {
  type        = list(string)
  description = "Instance types for worker nodes (t3.medium, t3.large)"
}

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "min_size" {
  type        = number
  description = "Minimum number of  worker nodes"
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
}

variable "disk_size" {
  type = number
}

variable "repositories" {
  type = list(string)
}

# AIOps Lambda module

variable "lambda_role_name" {
  type        = string
  description = "IAM execution role name shared by the AIOps Lambda functions"
}

variable "bedrock_agent_role_name" {
  type        = string
  description = "IAM role name assumed by the Bedrock Agent (Kira)"
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime for the AIOps Lambda functions"
}

variable "lambda_timeout" {
  type        = number
  description = "Timeout (seconds) for the AIOps Lambda functions"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group the fetch_logs function reads from"
}