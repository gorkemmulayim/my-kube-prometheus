# my-kube-prometheus


```
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) quay.io/coreos/jsonnet-ci jb install
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) quay.io/coreos/jsonnet-ci ./build.sh example.jsonnet
kubectl apply --server-side -f manifests/setup
kubectl apply -f manifests
```
