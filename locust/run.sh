#!/usr/bin/env bash
set -e

# Raise file descriptor limits
# Hard limit check
HARD_LIMIT=$(ulimit -Hn)
SOFT_LIMIT=200000

if [ "$HARD_LIMIT" -lt "$SOFT_LIMIT" ]; then
  echo "Hard FD limit ($HARD_LIMIT) is lower than requested ($SOFT_LIMIT)"
  echo "You must raise it via /etc/security/limits.conf or launch shell differently"
else
  ulimit -n $SOFT_LIMIT
fi

echo "Using file descriptor limit: $(ulimit -n)"


PYTHON=python3

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON -m venv .venv
fi

source .venv/bin/activate

python -m ensurepip --upgrade >/dev/null 2>&1 || true
python -m pip install --upgrade pip

if [ -f "requirements.txt" ]; then
    python -m pip install -r requirements.txt
fi

# Run Locust
exec locust -f locustfile.py

