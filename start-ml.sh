#!/bin/bash
export TRANSFORMERS_CACHE="${ML_MODEL_CACHE:-/data/model-cache}"
export HF_HOME="${ML_MODEL_CACHE:-/data/model-cache}"
export MACHINE_LEARNING_CACHE_FOLDER="${ML_MODEL_CACHE:-/data/model-cache}"

mkdir -p "${ML_MODEL_CACHE:-/data/model-cache}"

cd /ml/src

# immich_ml dispo (package installé depuis source) → entrée native
if /opt/venv/bin/python -c "import immich_ml" 2>/dev/null; then
    exec /opt/venv/bin/python -m immich_ml
fi

# Sinon : uvicorn direct sur app/main.py (structure standard de l'image ML)
exec /opt/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 3003 --workers 1
