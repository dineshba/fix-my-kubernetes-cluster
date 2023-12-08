dirName=${PWD##*/}
clusterName="issue$dirName"
kind create cluster --config cluster.yaml --name $clusterName
printf "Waiting for etcd and api-server to be ready\n"
kubectl wait --for=condition=Ready pod etcd-$clusterName-control-plane -n kube-system --timeout=300s
kubectl wait --for=condition=Ready pod kube-apiserver-$clusterName-control-plane -n kube-system --timeout=30s

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/calico.yaml 2> /dev/null 1> /dev/null
kubectl rollout status ds -l k8s-app=calico-node -n kube-system --timeout=300s 2> /dev/null 1> /dev/null

# wait for default sa to be created
kubectl wait --for=jsonpath='{.status.phase}'=Active ns/default --timeout=60s

defaultServiceAccountPresent=$(kubectl get sa -n default | grep default | wc -l)
while [ $defaultServiceAccountPresent -eq 0 ]; do
  printf "Waiting for default SA to be created\n"
  sleep 5
  defaultServiceAccountPresent=$(kubectl get sa -n default | grep default | wc -l)
done

kubectl apply -f pod.yaml
kubectl apply -f svc.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/nginx --timeout=300s
kubectl apply -f np.yaml 2> /dev/null 1> /dev/null

kubectl create deploy utils --image=arunvelsriram/utils --replicas=1 -- sleep infinity
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 deploy/utils --timeout=300s

printf "Executing kubectl exec -it deploy/utils -- curl --connect-timeout 5 http://working-svc:80\n"
kubectl exec -it deploy/utils -- curl --connect-timeout 5 http://working-svc:80
printf "working-svc is not working now\n"

printf "\n\nCan you help in fixing it?\n"
printf "\n\n"