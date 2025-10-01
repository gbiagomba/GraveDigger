FROM alpine:3.20

RUN apk add --no-cache bash coreutils findutils tar openssl

WORKDIR /app
COPY GraveDigger.sh /app/GraveDigger.sh

RUN chmod +x /app/GraveDigger.sh

ENTRYPOINT ["/app/GraveDigger.sh"]
