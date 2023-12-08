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

sleep 3
kubectl exec -it deploy/utils -- curl http://working-svc:80
printf "working-svc is working now. Let's create an issue\n"

# create issue
kubectl scale deploy/coredns -n kube-system --replicas=0 2> /dev/null 1> /dev/null
sleep 10

# test
printf "Executing kubectl exec -it deploy/utils -- curl http://working-svc:80\n"
kubectl exec -it deploy/utils -- curl http://working-svc:80
printf "working-svc is not working now\n"

printf "\n\nworking-svc is not reachable. Can you help in fixing it?\n"
printf "\n\n"

# Questions to be asked:
# 0. Is nslookup working?
# 2. What is /etc/resolv.conf in the utils container pointing to?
# 1. How is the utils got /etc/resolv.conf? Who configured it?
# 3. What is the configuration of the pointing service ?
# 4. What is the search domain ? Is it same for all ns ?