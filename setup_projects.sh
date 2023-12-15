#!/bin/bash

echo "***** Project Setting ***** "
echo "Deploy Pipeline project name > "
read PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
echo "Application project name for development environment > "
read DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT
echo "Application project name for staging environment > "
read STAGING_APP_GOOGLE_CLOUD_PROJECT
echo "Application project name for production environment > "
read PRODUCTION_APP_GOOGLE_CLOUD_PROJECT
echo "Billing Account ID > "
read BILLING_ACCOUNT_ID
echo "REGION > "
read REGION
echo "DeliveryPipeline name > "
read PIPELINE_NAME
echo "Artifact Registry name > "
read REGISTRY_NAME
echo "DockerImage name > "
read DOCKER_IMAGE_NAME

echo "*** confirm ***"
echo "Deploy Pipeline project name : "$PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
echo "Application project name for development environment : "$DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT
echo "Application project name for staging environment : "$STAGING_APP_GOOGLE_CLOUD_PROJECT
echo "Application project name for production environment : "$PRODUCTION_APP_GOOGLE_CLOUD_PROJECT
echo "Billing Account ID : "$BILLING_ACCOUNT_ID
echo "REGION : "$REGION
echo "DeliveryPipeline name : "$PIPELINE_NAME
echo "Artifact Registry name : "$REGISTRY_NAME
echo "DockerImage name : "$DOCKER_IMAGE_NAME

/bin/echo -n "confirm[Y/n] > "
read CONFIRM

if [ "${CONFIRM}" != 'Y' ]; then
    exit
fi

#
# Create Projects
#
all_projects=($PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT $DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT $STAGING_APP_GOOGLE_CLOUD_PROJECT $PRODUCTION_APP_GOOGLE_CLOUD_PROJECT)
for project in "${all_projects[@]}"; do
    gcloud projects create $project --name $project
    gcloud alpha billing accounts projects link $project --billing-account $BILLING_ACCOUNT_ID
done

#
# * API activation
# * Setup AppEngine Application
#
gcloud services enable appengine.googleapis.com --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
gcloud services enable artifactregistry.googleapis.com --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
gcloud services enable cloudbuild.googleapis.com --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
gcloud services enable compute.googleapis.com --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
gcloud services enable clouddeploy.googleapis.com --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
gcloud services enable storage.googleapis.com --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
app_projects=($DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT $STAGING_APP_GOOGLE_CLOUD_PROJECT $PRODUCTION_APP_GOOGLE_CLOUD_PROJECT)
for project in "${app_projects[@]}"; do
    gcloud services enable appengine.googleapis.com --project $project
    gcloud services enable appengineflex.googleapis.com --project $project
    gcloud services enable cloudbuild.googleapis.com --project $project
    gcloud services enable compute.googleapis.com
    gcloud services enable deploymentmanager.googleapis.com --project $project
    gcloud services enable run.googleapis.com --project $project
    gcloud app create --region $REGION --project $project
done

#
# Setup IAM Role
#
for project in "${app_projects[@]}"; do
    project_number=$(gcloud projects describe $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT --format='value(projectNumber)')
    gcloud projects add-iam-policy-binding $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT --member "serviceAccount:${project_number}@cloudbuild.gserviceaccount.com" --role "roles/artifactregistry.writer"

    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" --role "roles/iam.serviceAccountUser"
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" --role "roles/appengine.deployer"
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" --role "roles/appengine.serviceAdmin"
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" --role "roles/run.admin"
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" --role "roles/cloudbuild.builds.editor"
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" --role "roles/cloudbuild.workerPoolUser"

    app_project_number=$(gcloud projects describe $project --format='value(projectNumber)')
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${app_project_number}@cloudbuild.gserviceaccount.com" --role "roles/run.admin"
    gcloud projects add-iam-policy-binding $project --member "serviceAccount:${app_project_number}@cloudbuild.gserviceaccount.com" --role "roles/appengine.appAdmin"
    gcloud projects add-iam-policy-binding $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT --member "serviceAccount:service-${app_project_number}@serverless-robot-prod.iam.gserviceaccount.com" --role "roles/artifactregistry.reader"
    gcloud projects add-iam-policy-binding $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT --member "serviceAccount:${project}@appspot.gserviceaccount.com" --role "roles/artifactregistry.reader"
done

#
# Create Artifact Registry
#
gcloud artifacts repositories create $REGISTRY_NAME --location $REGION --repository-format docker --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT

#
# Create Bucket
#
gcloud storage buckets create gs://$PIPELINE_NAME --location $REGION --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT

#
# generate files
#
export PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
export DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT
export STAGING_APP_GOOGLE_CLOUD_PROJECT
export PRODUCTION_APP_GOOGLE_CLOUD_PROJECT
export REGION
export PIPELINE_NAME
export REGISTRY_NAME
export DOCKER_IMAGE_NAME
export GOOGLE_CLOUD_PROJECT_NUMBER=$(gcloud projects describe $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT --format='value(projectNumber)')
cat ./templates/clouddeploy.yaml.tpl | envsubst > ./clouddeploy.yaml
cat ./templates/skaffold.yaml.tpl | envsubst '$PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT $DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT $STAGING_APP_GOOGLE_CLOUD_PROJECT $PRODUCTION_APP_GOOGLE_CLOUD_PROJECT $REGION $PIPELINE_NAME $REGISTRY_NAME $DOCKER_IMAGE_NAME' > ./skaffold.yaml

export GOOGLE_CLOUD_PROJECT_NUMBER=$(gcloud projects describe $DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT --format='value(projectNumber)')
cat ./templates/cloudrun_service.yaml.tpl | envsubst > ./resources/development/run_service.yaml
cp ./templates/app.yaml.tpl ./resources/development/app.yaml
cp ./templates/app_secrets.yaml.tpl ./resources/development/app_secrets.yaml

export GOOGLE_CLOUD_PROJECT_NUMBER=$(gcloud projects describe $STAGING_APP_GOOGLE_CLOUD_PROJECT --format='value(projectNumber)')
cat templates/cloudrun_service.yaml.tpl | envsubst > ./resources/staging/run_service.yaml
cp ./templates/app.yaml.tpl ./resources/staging/app.yaml
cp ./templates/app_secrets.yaml.tpl ./resources/staging/app_secrets.yaml

export GOOGLE_CLOUD_PROJECT_NUMBER=$(gcloud projects describe $PRODUCTION_APP_GOOGLE_CLOUD_PROJECT --format='value(projectNumber)')
cat templates/cloudrun_service.yaml.tpl | envsubst > ./resources/production/run_service.yaml
cp ./templates/app.yaml.tpl ./resources/production/app.yaml
cp ./templates/app_secrets.yaml.tpl ./resources/production/app_secrets.yaml

#
# Create Deploy Pipeline
#
gcloud deploy apply --file clouddeploy.yaml --region $REGION --project $PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT
