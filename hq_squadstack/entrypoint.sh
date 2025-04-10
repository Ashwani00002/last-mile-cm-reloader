#!/bin/bash

# Check if the environment variable RUN_CONSUMER is set to "true"
if [ "$RUN_CONSUMER" = "true" ]; then
    echo "Starting consumer application..."
    # Delete newrelic.ini, setup.py, urls.py, wsgi.ini, wsgi.py, app.py and app_decorator.py
    rm -f newrelic.ini setup.py urls.py wsgi.ini wsgi.py app.py app_decorator.py
    exec python3 start_consumer.py
else
    echo "Starting uwsgi server..."
    # Delete start_consumer.py
    rm -f consumers/start_consumer.py
    exec uwsgi --ini wsgi.ini
fi