#!/bin/bash

# Export dependencies
pip freeze > requirements.txt

# Build zip
zip build requirements.txt saliencyservice/* Dockerfile

# Deploy to EB
eb deploy
