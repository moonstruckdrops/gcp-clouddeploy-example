apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
  name: ${PIPELINE_NAME}
serialPipeline:
  stages:
    - targetId: development
      profiles:
        - development
      strategy:
        standard:
          predeploy:
            actions: ["setup"]
          postdeploy:
            actions: ["post-deploy", "teardown"]
    - targetId: staging
      profiles:
        - staging
      strategy:
        standard:
          predeploy:
            actions: ["setup"]
          postdeploy:
            actions: ["post-deploy", "teardown"]
    - targetId: production
      profiles:
        - production
      strategy:
        standard:
          predeploy:
            actions: ["setup"]
          postdeploy:
            actions: ["post-deploy", "teardown"]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: development
description: deploy application for development
requireApproval: false
run:
  location: projects/${DEVELEOPMENT_APP_GOOGLE_CLOUD_PROJECT}/locations/${REGION}
executionConfigs:
  - usages:
      - RENDER
      - PREDEPLOY
      - DEPLOY
      - VERIFY
      - POSTDEPLOY
    executionTimeout: 7200s
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: staging
description: deploy application for staging
requireApproval: false
run:
  location: projects/${STAGING_APP_GOOGLE_CLOUD_PROJECT}/locations/${REGION}
executionConfigs:
  - usages:
      - RENDER
      - PREDEPLOY
      - DEPLOY
      - VERIFY
      - POSTDEPLOY
    executionTimeout: 7200s
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: production
description: deploy application for production
requireApproval: true
run:
  location: projects/${PRODUCTION_APP_GOOGLE_CLOUD_PROJECT}/locations/${REGION}
executionConfigs:
  - usages:
      - RENDER
      - PREDEPLOY
      - DEPLOY
      - VERIFY
      - POSTDEPLOY
    executionTimeout: 7200s
---
apiVersion: deploy.cloud.google.com/v1
kind: Automation
metadata:
  name: ${PIPELINE_NAME}/development-to-staging
description: rollout development to staging
suspended: false
serviceAccount: ${GOOGLE_CLOUD_PROJECT_NUMBER}-compute@developer.gserviceaccount.com
selector:
  - target:
      id: development
rules:
  - promoteRelease:
      name: development-to-staging
      destinationTargetId: "@next"
