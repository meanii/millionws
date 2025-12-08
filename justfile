name := "millionws"

# build main
build:
    go build -o ./dist/{{name}} ./...

# run
run: build
    ./dist/{{name}}

test:
    go test ./... -v

benchmark:
    go test -bench=.

# run locust web UI (default on http://localhost:8089)
locust:
    locust -f tools/locust/load_testing.py


# generate locust HTML report
locust-report:
    mkdir -p dist
    locust -f tools/locust/load_testing.py \
        --headless \
        -u 100 \
        -r 10 \
        --run-time 1m \
        --html dist/locust-report.html
