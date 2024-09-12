FROM ubuntu:latest
RUN apt-get update && apt-get install -y \
    sudo \
    apache2 \
    certbot \
    python3-certbot-apache \
    vim \
    nano

WORKDIR /var/www/html

COPY . .
RUN chmod 777 entrypoint.sh

#CMD ["apachectl", "-D", "FOREGROUND"]
ENTRYPOINT ["./entrypoint.sh"]
