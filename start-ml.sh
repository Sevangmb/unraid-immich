#!/bin/bash
export TRANSFORMERS_CACHE="${ML_MODEL_CACHE:-/data/model-cache}"
export HF_HOME="${ML_MODEL_CACHE:-/data/model-cache}"
export MACHINE_LEARNING_CACHE_FOLDER="${ML_MODEL_CACHE:-/data/model-cache}"

mkdir -p "${ML_MODEL_CACHE:-/data/model-cache}"

cd /ml/src
exec /opt/venv/bin/python -m immich_ml
