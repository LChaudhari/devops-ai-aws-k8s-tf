output "lambda_role_name" {
  value = aws_iam_role.lambda_role.name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "bedrock_agent_role_name" {
  value = aws_iam_role.bedrock_agent_role.name
}

output "bedrock_agent_role_arn" {
  value = aws_iam_role.bedrock_agent_role.arn
}

output "lambda_function_names" {
  value = [for fn in aws_lambda_function.aiops : fn.function_name]
}

output "lambda_function_arns" {
  value = { for k, fn in aws_lambda_function.aiops : k => fn.arn }
}
