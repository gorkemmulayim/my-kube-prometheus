# my-kube-prometheus

```
docker build -t builder .
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) builder jb install
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) builder ./build.sh example.jsonnet
kubectl apply --server-side -f manifests/setup
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
kubectl apply -f manifests
echo  "admin:$(echo admin | openssl passwd -apr1 -stdin)" > auth
kubectl create secret -n monitoring generic auth --from-file=auth
rm -rf auth
kubectl apply -f custom-manifests
```
