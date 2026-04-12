#!/bin/zsh
# ADL ShareFlow — Start backend server

cd "$(dirname "$0")/backend"

if [ ! -d "venv" ]; then
  echo "Creating virtualenv..."
  python3.12 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
else
  source venv/bin/activate
fi

echo "Running migrations..."
FLASK_APP=run.py flask db upgrade

echo ""
echo "Starting ADL ShareFlow Backend..."
echo "API: http://localhost:5050"
echo "Health: http://localhost:5050/health"
echo ""

python run.py
