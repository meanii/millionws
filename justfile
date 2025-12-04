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
