name := "millionws"
registry := "docker.io/meanii"
image := registry + "/" + name
tag := "v2.0.0"

# build main
build:
    @go build -o ./dist/{{name}} .
    @go build -o ./dist/loadgen ./cmd/loadgen

run: build
    @echo "use blow IP on prometheus.yml target host, since prometheus docker network wouldn't be able to access it through host"
    @ifconfig | grep 192. | awk '{print $2}'
    @./dist/{{name}}

test:
    go test ./... -v

benchmark:
    go test -bench=.

# one local benchmark run of a variant in bench/local/variants
bench variant="nbio-tuned" total="300000" replicas="5":
    bench/local/run.sh {{variant}} {{total}} {{replicas}}

# every variant, several times, plus a comparison table
bench-matrix repeats="3":
    bench/local/matrix.sh {{repeats}}

docker-build:
    docker build -t {{image}}:{{tag}} .

docker-push:
    docker push {{image}}:{{tag}}

docker-build-push: docker-build docker-push


# local development
start-monitoring:
    @docker compose -f deploy/local/compose.yml up -d --force-recreate
    @echo open grafana, http://localhost:8001
    @echo open prometheus, http://localhost:9090

start-monitoring-logs: start-monitoring
    @docker compose -f deploy/local/compose.yml logs --follow --tail 10

stop-monitoring:
    docker compose -f deploy/local/compose.yml down
