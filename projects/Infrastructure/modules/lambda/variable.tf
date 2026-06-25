variable "lambda_role_name" {
  description = "Name of the IAM execution role shared by the AIOps Lambda functions"
  type        = string
}

variable "bedrock_agent_role_name" {
  description = "Name of the IAM role assumed by the Bedrock Agent (Kira)"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the AIOps Lambda functions"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout (seconds) for the AIOps Lambda functions"
  type        = number
}

variable "log_group_name" {
  description = "CloudWatch log group the fetch_logs function reads from"
  type        = string
}
