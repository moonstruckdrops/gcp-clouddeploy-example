apiVersion: skaffold/v4beta7
kind: Config
metadata:
  name: app
build:
  artifacts:
    - image: ${REGION}-docker.pkg.dev/${PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT}/${REGISTRY_NAME}/${DOCKER_IMAGE_NAME}
      docker:
        dockerfile: ./Dockerfile
  tagPolicy:
    gitCommit:
      ignoreChanges: true
  googleCloudBuild:
    projectId: ${PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT}
    region: ${REGION}
profiles:
  - name: development
    manifests:
      rawYaml:
        - resources/development/run_service.yaml
    deploy:
      cloudrun:
        projectid: ${DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT}
        region: ${REGION}
  - name: staging
    manifests:
      rawYaml:
        - resources/staging/run_service.yaml
    deploy:
      cloudrun:
        projectid: ${STAGING_APP_GOOGLE_CLOUD_PROJECT}
        region: ${REGION}
  - name: production
    manifests:
      rawYaml:
        - resources/production/run_service.yaml
    deploy:
      cloudrun:
        projectid: ${PRODUCTION_APP_GOOGLE_CLOUD_PROJECT}
        region: ${REGION}
customActions:
  - name: setup
    containers:
      - name: setup
        image: gcr.io/google.com/cloudsdktool/google-cloud-cli:slim
        command:
          - "bash"
          - "-c"
          - |
            gsutil cp gs://${CLOUD_DEPLOY_DELIVERY_PIPELINE}/${CLOUD_DEPLOY_RELEASE}.tar.gz .
            tar xzvf ${CLOUD_DEPLOY_RELEASE}.tar.gz
            project=${DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT}
            case ${CLOUD_DEPLOY_TARGET} in
              "staging")
                project=${STAGING_APP_GOOGLE_CLOUD_PROJECT}
                ;;
              "production")
                project=${PRODUCTION_APP_GOOGLE_CLOUD_PROJECT}
                ;;
              *)
                ;;
            esac
            gcloud builds submit --config ./hooks/cloudbuild.setup.yaml --region ${REGION} --no-source --project ${project}
  - name: post-deploy
    containers:
      - name: deploy-appengine
        image: gcr.io/google.com/cloudsdktool/google-cloud-cli:slim
        command:
          - "bash"
          - "-c"
          - |
            gsutil cp gs://${CLOUD_DEPLOY_DELIVERY_PIPELINE}/${CLOUD_DEPLOY_RELEASE}.tar.gz .
            tar xzvf ${CLOUD_DEPLOY_RELEASE}.tar.gz
            gsutil cp gs://${CLOUD_DEPLOY_DELIVERY_PIPELINE}/${CLOUD_DEPLOY_RELEASE}-artifacts.json .
            apt-get update -y && apt-get install jq -y
            image_tag=$(cat ${CLOUD_DEPLOY_RELEASE}-artifacts.json | jq -r .builds[0].tag | sed s/@.*$//)
            project=${DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT}
            case ${CLOUD_DEPLOY_TARGET} in
              "staging")
                project=${STAGING_APP_GOOGLE_CLOUD_PROJECT}
                ;;
              "production")
                project=${PRODUCTION_APP_GOOGLE_CLOUD_PROJECT}
                ;;
              *)
                ;;
            esac
            gcloud app deploy resources/${CLOUD_DEPLOY_TARGET}/app.yaml --promote --stop-previous-version --version=${CLOUD_DEPLOY_RELEASE} --quiet --image-url=${image_tag} --project ${project}
  - name: teardown
    containers:
      - name: teardown
        image: gcr.io/google.com/cloudsdktool/google-cloud-cli:slim
        command:
          - "bash"
          - "-c"
          - |
            gsutil cp gs://${CLOUD_DEPLOY_DELIVERY_PIPELINE}/${CLOUD_DEPLOY_RELEASE}.tar.gz .
            tar xzvf ${CLOUD_DEPLOY_RELEASE}.tar.gz
            project=${DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT}
            case ${CLOUD_DEPLOY_TARGET} in
              "staging")
                project=${STAGING_APP_GOOGLE_CLOUD_PROJECT}
                ;;
              "production")
                project=${PRODUCTION_APP_GOOGLE_CLOUD_PROJECT}
                ;;
              *)
                ;;
            esac
            gcloud builds submit --config ./hooks/cloudbuild.teardown.yaml --region ${REGION} --no-source --project ${project}
