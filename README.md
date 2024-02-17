# my-kube-prometheus

```
docker build -t builder .
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) builder jb install
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) builder ./build.sh example.jsonnet
kubectl apply --server-side -f manifests/setup
kubectl apply -f manifests
kubectl apply -f custom-manifests
```
