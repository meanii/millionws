#!/bin/bash
# run.sh - Simple script to run Locust tests

# Install dependencies if needed
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip3 install -r requirements.txt
fi

# Run Locust
locust -f locustfile.py
