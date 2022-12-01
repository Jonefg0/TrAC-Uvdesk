FROM ubuntu:18.04
LABEL maintainer="akshay.kumar758@webkul.com"

ENV GOSU_VERSION 1.11

RUN adduser uvdesk -q --disabled-password --gecos ""

# Install base supplimentary packages
RUN apt-get update && apt-get -y upgrade \
    && apt-get update && apt-get install -y software-properties-common && add-apt-repository -y ppa:ondrej/php \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
        curl \
        wget \
        git \
        unzip \
        apache2 \
        mysql-server \
        php \
        libapache2-mod-php \
        php-common \
        php-xml \
        php-imap \
        php-mysql \
        php-mailparse \
        ca-certificates; \
    if ! command -v gpg; then \
		apt-get install -y --no-install-recommends gnupg2 dirmngr; \
	elif gpg --version | grep -q '^gpg (GnuPG) 1\.'; then \
		apt-get install -y --no-install-recommends gnupg-curl; \
	fi;

#RUN a2enmod ssl && a2enmod rewrite
#RUN mkdir -p /etc/apache2/ssl
COPY ./.docker/config/apache2/env /etc/apache2/envvars
COPY ./.docker/config/apache2/httpd.conf /etc/apache2/apache2.conf
#COPY ./.docker/config/apache2/vhost.conf /etc/apache2/sites-available/uvdesk.puentesdigitales.cl.conf
COPY ./.docker/config/apache2/vhost.conf /etc/apache2/sites-available/000-default.conf
COPY ./.docker/bash/uvdesk-entrypoint.sh /usr/local/bin/
COPY . /var/www/uvdesk/

RUN \
    # Update apache configurations
    a2enmod php rewrite; \
    chmod +x /usr/local/bin/uvdesk-entrypoint.sh; \
    # Install gosu for stepping-down from root to a non-privileged user during container startup
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    # Verify gosu installation
    export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && gpgconf --kill all \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true; \
    \
    # Download and verify composer installer signature
    wget -O /usr/local/bin/composer.php "https://getcomposer.org/installer"; \
    actualSig="$(wget -q -O - https://composer.github.io/installer.sig)"; \
    currentSig="$(shasum -a 384 /usr/local/bin/composer.php | awk '{print $1}')"; \
    if [ "$currentSig" != "$actualSig" ]; then \
        echo "Warning: Failed to verify composer signature."; \
        exit 1; \
	fi; \
    # Install composer
    php /usr/local/bin/composer.php --quiet --filename=/usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer; \
    # Assign user uvdesk the ownership of source directory
    chown -R uvdesk:uvdesk /var/www; \
    # Clean up files
    rm -rf \
        "$GNUPGHOME" \
        /var/lib/apt/lists/* \
        /usr/local/bin/gosu.asc \
        /usr/local/bin/composer.php \
        /var/www/bin \
        /var/www/html \
        /var/www/uvdesk/.docker;


WORKDIR /var/www/uvdesk

RUN composer self-update
RUN composer install
RUN composer update
#RUN php bin/console d:s:u --force
# Change working directory to uvdesk source
WORKDIR /var/www

RUN chmod 777 -R /var/www/uvdesk/config
RUN chmod 777 -R /var/www/uvdesk/var
RUN chmod 777 -R /var/www/uvdesk/public
RUN chmod 777 -R /var/www/uvdesk/.env

RUN apt-get update && apt-get install vim -y
#RUN add-apt-repository ppa:certbot/certbot
RUN apt-get install php-curl -y
RUN a2enmod headers
RUN service apache2 restart
#RUN apt install python-certbot-apache -y
#RUN apt install ufw -y
#RUN a2ensite uvdesk.puentesdigitales.cl.conf
#RUN service apache2 restart

ENTRYPOINT ["uvdesk-entrypoint.sh"]
CMD ["/bin/bash"]