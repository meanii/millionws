name := "millionws"
registry := "docker.io/meanii"
image := registry + "/" + name
tag := "latest"

# build main
build:
    go build -o ./dist/{{name}} ./...

run: build
    ./dist/{{name}}

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
