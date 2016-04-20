FROM alpine:3.2

RUN apk update && apk add nginx && rm -rf /var/cache/apk/*

EXPOSE 80 1080

COPY start.sh /app/

COPY nginx.conf /etc/nginx/

CMD /app/start.sh
