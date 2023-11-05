dirName=${PWD##*/}
clusterName="issue$dirName"
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

kubectl create deploy utils --image=arunvelsriram/utils --replicas=1 -- sleep infinity
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 deploy/utils --timeout=300s

kubectl apply -f pod.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/nginx --timeout=300s
kubectl apply -f svc.yaml

# create issue
kubectl scale deploy/coredns -n kube-system --replicas=0

# test
kubectl exec -it deploy/utils -- curl http://working-svc:80
kubectl exec -it deploy/utils -- curl http://kubernetes:80

printf "\n\nNot able to resolve working-svc. Can you help in fixing it?\n"
printf "\n\n"