#!/bin/bash

set -euo pipefail

# variable for future steps
GCP_PROJECT_NAME=$1

# get cloudSQL private IP
SQL_IP="$(gcloud sql instances list --filter=name:exam-db --format='value(PRIVATE_ADDRESS)')"

# get cloudrun endpoint
BACKEND_URL="$(gcloud run services list | grep https://backend)"
BACKEND_URL=${BACKEND_URL:5}

# replace variable with real cloud run endpoint
sed -i "s|<CLOUD-RUN-BACKEND-URL>|$BACKEND_URL|g" "./frontend/src/App.jsx"

# build frontend code and docker containers
cd frontend
npm install
npm run build
docker buildx build --platform linux/amd64 -t "us-east1-docker.pkg.dev/$1/images-repo/frontend" .
docker push "us-east1-docker.pkg.dev/$1/images-repo/frontend"

# build backend code and docker containers
cd ../backend
docker buildx build --platform linux/amd64 -t "us-east1-docker.pkg.dev/$1/images-repo/backend" .
docker push "us-east1-docker.pkg.dev/$1/images-repo/backend"

# build migrate docker containers
cd ../migrate
docker buildx build --platform linux/amd64 -t "us-east1-docker.pkg.dev/$1/images-repo/migrate" .
docker push "us-east1-docker.pkg.dev/$1/images-repo/migrate"

# run job to migrate SQL schema
gcloud run jobs update migrate-job --image="us-east1-docker.pkg.dev/$1/images-repo/migrate" --region="us-east1"
gcloud run jobs execute migrate-job --region "us-east1"

# TOP SECRET
PASSWORD=$(gcloud secrets versions access latest --secret="db-root-password")

# update backend cloud run service
gcloud run deploy backend \
    --region="us-east1" \
    --image="us-east1-docker.pkg.dev/$1/images-repo/backend" \
    --vpc-connector cloud-run-connector \
    --vpc-egress private-ranges-only \
    --set-env-vars DATABASE_URL="postgres://postgres:$PASSWORD@/postgres?host=$SQL_IP" \
    --allow-unauthenticated

#update frontend cloud run service
gcloud run deploy frontend \
    --region="us-east1" \
    --image="us-east1-docker.pkg.dev/$1/images-repo/frontend" \
    --allow-unauthenticated
