FROM python:3.6-slim
MAINTAINER Tyler Fowler <tylerfowler.1337@gmail.com>

# Caravel setup options
ENV SUPERSET_VERSION 0.17.4
ENV SUPERSET_HOME /superset
ENV SUP_ROW_LIMIT 5000
ENV SUP_WEBSERVER_THREADS 8
ENV SUP_WEBSERVER_PORT 8088
ENV SUP_WEBSERVER_TIMEOUT 60
ENV SUP_SECRET_KEY 'thisismysecretkey'
ENV SUP_META_DB_URI "sqlite:///${SUPERSET_HOME}/superset.db"
ENV SUP_CSRF_ENABLED True

ENV PYTHONPATH $SUPERSET_HOME:$PYTHONPATH

# admin auth details
ENV ADMIN_USERNAME admin
ENV ADMIN_FIRST_NAME admin
ENV ADMIN_LAST_NAME user
ENV ADMIN_EMAIL admin@nowhere.com
ENV ADMIN_PWD superset

# by default only includes PostgreSQL because I'm selfish
ENV DB_PACKAGES libpq-dev
ENV DB_PIP_PACKAGES psycopg2

RUN apt-get update \
&& apt-get install -y \
  build-essential gcc \
  libssl-dev libffi-dev libsasl2-dev libldap2-dev \
&& pip install --no-cache-dir \
  $DB_PIP_PACKAGES flask-appbuilder superset==$SUPERSET_VERSION "PyAthenaJDBC>1.0.9"\
&& apt-get remove -y \
  build-essential libssl-dev libffi-dev libsasl2-dev libldap2-dev \
&& apt-get -y autoremove && apt-get clean && rm -rf /var/lib/apt/lists/*

# install DB packages separately
RUN apt-get update && apt-get install -y $DB_PACKAGES \
&& apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up Athena support: Install Java 8 & symlink the expected command name

RUN \
    echo "===> add webupd8 repository..."  && \
    echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee /etc/apt/sources.list.d/webupd8team-java.list  && \
    echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list  && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886  && \
    apt-get update

RUN echo "===> install Java"  && \
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections  && \
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections  && \
    DEBIAN_FRONTEND=noninteractive  apt-get install -y --force-yes oracle-java8-installer oracle-java8-set-defaultRUN ln -s /usr/bin/java /usr/bin/jvm

RUN echo "===> clean up..."  && \
    rm -rf /var/cache/oracle-jdk8-installer  && \
    apt-get clean  && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/java /usr/bin/jvm

# remove build dependencies
RUN mkdir $SUPERSET_HOME

COPY superset-init.sh /superset-init.sh
RUN chmod +x /superset-init.sh

VOLUME $SUPERSET_HOME
EXPOSE 8088

# since this can be used as a base image adding the file /docker-entrypoint.sh
# is all you need to do and it will be run *before* Caravel is set up
ENTRYPOINT [ "/superset-init.sh" ]
