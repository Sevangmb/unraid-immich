#!/bin/bash
# Lance le service Machine Learning (reconnaissance faciale, recherche intelligente)

export TRANSFORMERS_CACHE="${ML_MODEL_CACHE:-/data/model-cache}"
export HF_HOME="${ML_MODEL_CACHE:-/data/model-cache}"
export MACHINE_LEARNING_CACHE_FOLDER="${ML_MODEL_CACHE:-/data/model-cache}"

cd /ml/app

# Utilise le venv si présent (packaging récent d'Immich ML), sinon python3 global
if [ -x ".venv/bin/python" ]; then
    exec .venv/bin/python -m uvicorn app.main:app \
        --host 0.0.0.0 --port 3003 --workers 1
else
    exec python3 -m uvicorn app.main:app \
        --host 0.0.0.0 --port 3003 --workers 1
fi
