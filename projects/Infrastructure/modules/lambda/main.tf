# AIOps Lambda functions: fetch_logs, fetch_metrics, fetch_health
# Each function's code lives in a same-named subdirectory of this module.

locals {
  lambda_functions = {
    "aiops-fetch-logs"    = "fetch_logs"
    "aiops-fetch-metrics" = "fetch_metrics"
    "aiops-fetch-health"  = "fetch_health"
  }
}

data "archive_file" "lambda_zip" {
  for_each = local.lambda_functions

  type        = "zip"
  source_dir  = "${path.module}/${each.value}"
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_lambda_function" "aiops" {
  for_each = local.lambda_functions

  function_name = each.key
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout

  filename         = data.archive_file.lambda_zip[each.key].output_path
  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256

  environment {
    variables = {
      LOG_GROUP_NAME = var.log_group_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_logs_eks_access
  ]
}

# IAM execution role shared by the AIOps Lambda functions
# (fetch_logs, fetch_metrics, fetch_health)

resource "aws_iam_role" "lambda_role" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Basic Lambda execution — lets the functions write their own logs to CloudWatch

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline policy: read CloudWatch Logs (boutique pod logs) and describe the EKS cluster

resource "aws_iam_role_policy" "lambda_logs_eks_access" {
  name = "${var.lambda_role_name}-logs-eks-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSRead"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for the Bedrock Agent (Kira)

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "bedrock_agent_role" {
  name = var.bedrock_agent_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# Inline policy: invoke Bedrock models and the AIOps Lambda functions

resource "aws_iam_role_policy" "bedrock_agent_access" {
  name = "${var.bedrock_agent_role_name}-access"
  role = aws_iam_role.bedrock_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockModelInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetInferenceProfile"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*",
          "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:aws:bedrock:*::foundation-model/amazon.nova-micro-v1:0",
          "arn:aws:bedrock:ap-south-1:018442532737:inference-profile/apac.amazon.nova-micro-v1:0"
        ]
      },
      {
        Sid      = "LambdaInvoke"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:aiops-*",
          "arn:aws:bedrock:ap-south-1:018442532737:inference-profile/apac.amazon.nova-micro-v1:0",
          "arn:aws:bedrock:ap-south-1::foundation-model/amazon.nova-micro-v1:0",
          "arn:aws:bedrock:ap-southeast-1::foundation-model/amazon.nova-micro-v1:0",
          "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.nova-micro-v1:0",
          "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.nova-micro-v1:0"
          ]          
      }
    ]
  })
}


