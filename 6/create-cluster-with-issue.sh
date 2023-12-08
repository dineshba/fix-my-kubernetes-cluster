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

kubectl apply -f pod.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/nginx --timeout=300s
kubectl apply -f svc.yaml

containerId=$(docker ps | grep $clusterName | awk '{ print $1}')
containerIP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $containerId)
svcIP=$(kubectl get svc working-svc -o jsonpath='{.spec.clusterIP}')

kubectl create deploy utils --image=arunvelsriram/utils --replicas=1 -- sleep infinity
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 deploy/utils --timeout=300s

svcWorking=1
while [ $svcWorking -ne 0 ]; do
  printf "Waiting for working-svc to work\n"
  sleep 3
  docker exec -it $containerId curl --connect-timeout 3 http://$svcIP:80
  svcWorking=$(echo $?)
done

kubectl get ds/kube-proxy -n kube-system -o yaml > kube-proxy.yaml
kubectl delete ds/kube-proxy -n kube-system

kubectl apply -f svc2.yaml

printf "Executing kubectl exec -it deploy/utils -- curl --connect-timeout 3 http://not-working-svc:80\n"
kubectl exec -it deploy/utils -- curl --connect-timeout 3 http://not-working-svc:80
printf "not-working-svc is not working now\n"

printf "\n\nCan you help in fixing it?\n"
printf "\n\n"

# Commands used:
# iptables -t nat -L PREROUTING
# iptables -t nat -L KUBE-SERVICES