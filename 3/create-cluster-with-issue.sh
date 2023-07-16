clusterName="issue3"
kind create cluster --name $clusterName
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
kubectl get clusterrolebinding system:kube-scheduler -o yaml > clusterrolebinding.yaml
kubectl delete clusterrolebinding system:kube-scheduler

printf "\n"
printf "Applying Pods\n"
kubectl apply -f pod1.yaml
printf "\n\nCan you help in making the pending pod run?\n"
kubectl get pods -n default
printf "\n\n"