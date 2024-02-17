FROM golang:1.22.0-bookworm

RUN go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@v0.5.1
RUN go install -a github.com/google/go-jsonnet/cmd/jsonnet@v0.20.0
RUN go install -a github.com/brancz/gojsontoyaml@v0.1.0