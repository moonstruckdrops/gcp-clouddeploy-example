FROM golang:1.21.4-alpine

WORKDIR /app

RUN apk update && \
    apk add git && \
    rm -rf /var/cache/apk/*

COPY *.go .

EXPOSE 8080
CMD ["go", "run", "main.go"]
