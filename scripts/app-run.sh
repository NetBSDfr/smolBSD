#!/bin/sh
#
# See app/README.md for documentation
#

progname=${0##*/}
progdir=${0%/*}
cwd=$(realpath $progdir)

set -euf

(
    cd $cwd/../app;

    # initial setup
    if [ ! -f bin/activate ]; then
        python3 -m venv .
        . bin/activate
        pip install -r requirements.txt
    fi

    . bin/activate
    # Set Flask env vars defaults
    FLASK_APP=${FLASK_APP:-app} \
    FLASK_RUN_PORT=${FLASK_RUN_PORT:-5000} \
    FLASK_RUN_HOST=${FLASK_RUN_HOST:-127.0.0.1} \
    FLASK_ENV=${FLASK_ENV:-development} \
    FLASK_DEBUG=${FLASK_DEBUG:-True} \
    FLASK_LOGLEVEL=${FLASK_LOGLEVEL:-20} \
    FLASK_CWD=$cwd/.. \
        flask run "$@"
        #python3 app.py
)
