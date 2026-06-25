# output "cluster_name" {
#   value = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   value = module.eks.cluster_endpoint
# }

# output "ecr_urls" {
#   value = module.ecr.repository_urls
# }

output "fluent_bit_irsa_role_arn" {
  value = module.eks.fluent_bit_irsa_role_arn
}
