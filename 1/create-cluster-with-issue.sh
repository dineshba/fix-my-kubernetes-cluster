kind create cluster --name issue1
printf "Waiting for nodes to be ready\n"
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# wait for default sa to be created
kubectl wait --for=jsonpath='{.status.phase}'=Active ns/default --timeout=60s

defaultServiceAccountPresent=$(kubectl get sa -n default | grep default | wc -l)
while [ $defaultServiceAccountPresent -eq 0 ]; do
  printf "Waiting for default SA to be created\n"
  sleep 5
  defaultServiceAccountPresent=$(kubectl get sa -n default | grep default | wc -l)
done

# create an issue
docker exec -it $(docker ps | grep issue1 | awk '{ print $1}') mv /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/

printf "\n"
printf "Applying Pods\n"
kubectl apply -f pod1.yaml
kubectl wait --for=condition=Ready pods/nginx1 -n default --timeout=60s
kubectl apply -f pod2.yaml
printf "\n\nCan you help in making the pending pod run?\n"
kubectl get pods -n default
printf "\n\n"