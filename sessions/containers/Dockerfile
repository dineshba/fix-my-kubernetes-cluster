FROM golang:latest

RUN apt-get update
RUN apt-get install -y curl

WORKDIR /app
COPY . /app

RUN go mod download
RUN go build -o myapp .

USER root
CMD ["./myapp"]