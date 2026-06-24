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
# push the chnages to github and auto triggered the pipeline.


# Next step is to deploy the manifest files which are under gitops dir
# We are using the kustomization.yml file we are applying all the 15 services at a time.
# kubectl apply -k gitops/

# kubectl get pods -n boutique 
# we will getting an error becasue the image we are using is old in ci.yml and the new image is push to our ecr 
# So here argocd came into picture.

# kubectl get pods -n argocd
# kubectl get svc -n argocd
# kubectl port-forward svc/argocd-server -n argocd 8080:80 

# once the localhost:8080 is accessible then run
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# get the argocd password

# login to argocd
user: admin
password: 


# Once login
# Add the repo, under settings add repos using HTTP method
# provide project name
# provide url
# add username
# add password is PAT


