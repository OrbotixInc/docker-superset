#!/bin/bash

set -eo pipefail
apt-get update
apt-get install -y  git
pip uninstall -y Flask-AppBuilder
pip install git+git://github.com/mattk42/Flask-AppBuilder.git@6b56b08dddb9d9a41302f8bb54ba41f5dc77cfce
pip install Flask-OAuthlib
pip install Flask-Mail
pip list

# check to see if the superset config already exists, if it does skip to
# running the user supplied docker-entrypoint.sh, note that this means
# that users can copy over a prewritten superset config and that will be used
# without being modified
echo "Checking for existing Caravel config..."
if [ ! -f $SUPERSET_HOME/superset_config.py ]; then
  echo "No Superset config found, creating from environment"
  touch $SUPERSET_HOME/superset_config.py

  cat > $SUPERSET_HOME/superset_config.py <<EOF
ROW_LIMIT = ${SUP_ROW_LIMIT}
WEBSERVER_THREADS = ${SUP_WEBSERVER_THREADS}
SUPERSET_WEBSERVER_PORT = ${SUP_WEBSERVER_PORT}
SUPERSET_WEBSERVER_TIMEOUT = ${SUP_WEBSERVER_TIMEOUT}
SECRET_KEY = '${SUP_SECRET_KEY}'
SQLALCHEMY_DATABASE_URI = '${SUP_META_DB_URI}'
CSRF_ENABLED = ${SUP_CSRF_ENABLED}
SQLLAB_TIMEOUT = ${SUP_SQLLAB_TIMEOUT}
ENABLE_PROXY_FIX = ${SUP_ENABLE_PROXY_FIX}
LOG_LEVEL = 'DEBUG'
EOF
fi

cat >> $SUPERSET_HOME/superset_config.py <<EOF
from flask_appbuilder.security.manager import AUTH_OID, \
                                          AUTH_REMOTE_USER, \
                                          AUTH_DB, AUTH_LDAP, \
                                          AUTH_OAUTH
AUTH_TYPE = 4
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "readonly"
ALLOWED_EMAIL_DOMAINS = ${ALLOWED_EMAIL_DOMAINS}

RECAPTCHA_PUBLIC_KEY = "${RECAPTCHA_PUBLIC_KEY}"
RECAPTCHA_PRIVATE_KEY =  "${RECAPTCHA_PRIVATE_KEY}"

# Config for Flask-Mail necessary for user registration
MAIL_SERVER = "${MAIL_SERVER}"
MAIL_PORT = "${MAIL_PORT}"
MAIL_USE_TLS = True
MAIL_USERNAME = "${MAIL_USERNAME}"
MAIL_PASSWORD = "${MAIL_PASSWORD}"
MAIL_DEFAULT_SENDER = "${MAIL_DEFAULT_SENDER}"

OAUTH_PROVIDERS = [
    {'name':'google', 'icon':'fa-google', 'token_key':'access_token',
        'remote_app': {
            'consumer_key':"${GOOGLE_CONSUMER_KEY}",
            'consumer_secret':"${GOOGLE_CONSUMER_SECRET}",
            'base_url':'https://www.googleapis.com/plus/v1/',
            'request_token_params':{
              'scope': 'https://www.googleapis.com/auth/userinfo.email'
            },
            'request_token_url':None,
            'access_token_url':'https://accounts.google.com/o/oauth2/token',
            'authorize_url':'https://accounts.google.com/o/oauth2/auth'}
    }
]

import logging
logging.getLogger().setLevel(logging.DEBUG)

EOF

# check for existence of /docker-entrypoint.sh & run it if it does
echo "Checking for docker-entrypoint"
if [ -f /docker-entrypoint.sh ]; then
  echo "docker-entrypoint found, running"
  chmod +x /docker-entrypoint.sh
  . docker-entrypoint.sh
fi

# set up Caravel if we haven't already
#if [ ! -f $SUPERSET_HOME/.setup-complete ]; then
#  echo "Running first time setup for Caravel"
#
#  echo "Creating admin user ${ADMIN_USERNAME}"
#  cat > $SUPERSET_HOME/admin.config <<EOF
#${ADMIN_USERNAME}
#${ADMIN_FIRST_NAME}
#${ADMIN_LAST_NAME}
#${ADMIN_EMAIL}
#${ADMIN_PWD}
#${ADMIN_PWD}
#
#EOF

#  /bin/sh -c '/usr/local/bin/fabmanager create-admin --app superset < $SUPERSET_HOME/admin.config'

#  rm $SUPERSET_HOME/admin.config

#  echo "Initializing database"
#  superset db upgrade

#  echo "Creating default roles and permissions"
#  superset init

#  touch $SUPERSET_HOME/.setup-complete
#else
#  # always upgrade the database, running any pending migrations
#  superset db upgrade
#fi

echo "Starting up Caravel"
superset runserver -p 8088 -a 0.0.0.0 -t ${SUP_WEBSERVER_TIMEOUT}
