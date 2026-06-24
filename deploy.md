# I have used the deafult vpc and internet gateway
# Updated the K8s directory:
updated the manifest         #claude mention what we have updated
added the backend.tf file

# terraform init, plan and apply

# after apply I have run on cmd
# aws eks update-kubeconfig --name eks-cluster --region ap-south-1    #for access the nodes, using kubeconfig we can switch the cluster,etc.
# kubectl get nodes
# kubectl get pods
# kubectl get pods -n argocd

# I have go to gihub and added the secrets which is used for my ci.yml file




