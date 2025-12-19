name := "millionws"
registry := "docker.io/meanii"
image := registry + "/" + name
tag := "v1.0.0"

# build main
build:
    @go build -o ./dist/{{name}} ./...

run: build
    @echo "use blow IP on prometheus.yml target host, since prometheus docker network wouldn't be able to access it through host"
    @ifconfig | grep 192. | awk '{print $2}'
    @./dist/{{name}}

test:
    go test ./... -v

benchmark:
    go test -bench=.

locust:
    locust -f tools/locust/load_testing.py

locust-report:
    mkdir -p dist
    locust -f tools/locust/load_testing.py \
        --headless \
        -u 100 \
        -r 10 \
        --run-time 1m \
        --html dist/locust-report.html

docker-build:
    docker build -t {{image}}:{{tag}} .

docker-push:
    docker push {{image}}:{{tag}}

docker-build-push: docker-build docker-push


# local development
start-monitoring:
    @docker-compose -f deploy/local/compose.yml up -d --force-recreate
    @echo open grafana, http://localhost:8001
    @echo open prometheus, http://localhost:9090

start-monitoring-logs:
    @docker-compose -f deploy/local/compose.yml logs --follow --tail 10

stop-monitoring:
    docker-compose -f deploy/local/compose.yml down
