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

# create an issue
containerId=$(docker ps | grep $clusterName | awk '{ print $1}')
containerIP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $containerId)

cat <<EOF | docker exec -i $containerId bash
cd /etc/kubernetes/

date -s "2023-05-25 12:34:56" 1> /dev/null

openssl genrsa -out mykube-scheduler.key 2048 1> /dev/null
openssl req -new -key mykube-scheduler.key -subj "/CN=system:kube-scheduler" -addext "keyUsage = digitalSignature, keyEncipherment" -addext "extendedKeyUsage=TLS Web Client Authentication" -out kube-scheduler.csr 1> /dev/null 2> /dev/null
openssl x509 -req -in kube-scheduler.csr -CA pki/ca.crt -CAkey pki/ca.key -CAcreateserial -out mykube-scheduler.crt -days 10 1> /dev/null 2> /dev/null
# openssl x509 -noout -in mykube-scheduler.crt -dates

hwclock -s

kubectl config set-cluster $clusterName \
    --certificate-authority=./pki/ca.crt \
    --embed-certs=true \
    --server=https://$containerIP:6443 \
    --kubeconfig=mykube-scheduler.kubeconfig 1> /dev/null

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=mykube-scheduler.crt \
  --client-key=mykube-scheduler.key \
  --embed-certs=true \
  --kubeconfig=mykube-scheduler.kubeconfig 1> /dev/null

kubectl config set-context default \
  --cluster=$clusterName \
  --user=system:kube-scheduler \
  --kubeconfig=mykube-scheduler.kubeconfig 1> /dev/null

kubectl config use-context default --kubeconfig=mykube-scheduler.kubeconfig 1> /dev/null

mv scheduler.conf scheduler.conf.backup
mv mykube-scheduler.kubeconfig scheduler.conf

crictl ps | grep scheduler | awk '{print \$1}' | xargs -I{} crictl stop {} > /dev/null
EOF

printf "\n"
printf "Applying Pods\n"
kubectl apply -f pod1.yaml
printf "\n\nCan you help in making the pending pod run?\n"
kubectl get pods -n default
printf "\n\n"