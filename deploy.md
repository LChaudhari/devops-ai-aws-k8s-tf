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


# Now make argocd sync with the github for that deploy the argocd.yml file
# kubectl apply -f argo-cd.yml

# Go to argocd localhost and sync with latest changes.
# except postgresql and frontend all the pods will get erroe because of db not exist.

# We need to re-run restore job to make all the pods healthy.
# kubectl apply -f restore-job.yml 
# kubectl get pods -n boutique
# Still the pod showing unhealthy 
# delete the pods so it will recreate auto

# Now all the pods are healthy
# test the service
# kubectl get svc -n boutique
# kubectl port-forward svc/gateway -n boutique 3001:3001
# kubectl port-forward svc/frontend -n boutique 3005:3000

# If I delete any deployment then I need to manually sync the argocd to make the deployment back running, but If I want it to do automatically the, update the argo-cd.yml file
# kubectl apply -f argo-cd.yml

# try to delete any deployment, then argocd make them in running state.
# kubectl get deployments.apps -n boutique
# kubectl get pods -n boutique 

# Now check our monitoring Gra and Promth.
# kubectl get pods -n monitoring
# kubectl get svc -n monitoring

# kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# For login to grafana
# for password enter cmd
# kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
user: admin
pas
# In grafana go to Dashboard, Already created dashboard for services.
