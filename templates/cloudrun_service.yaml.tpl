apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello
  labels:
    cloud.googleapis.com/location: ${REGION}
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/ingress-status: all
spec:
  template:
    metadata:
      labels:
        run.googleapis.com/startupProbeType: Default
      annotations:
        autoscaling.knative.dev/maxScale: '3'
        run.googleapis.com/startup-cpu-boost: 'true'
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      serviceAccountName: ${GOOGLE_CLOUD_PROJECT_NUMBER}-compute@developer.gserviceaccount.com
      containers:
      - name: hello
        image: ${REGION}-docker.pkg.dev/${PIPELINE_MANEGEMENT_GOOGLE_CLOUD_PROJECT}/${REGISTRY_NAME}/${DOCKER_IMAGE_NAME}
        ports:
        - name: http1
          containerPort: 8080
        resources:
          limits:
            cpu: 1000m
            memory: 512Mi
        startupProbe:
          timeoutSeconds: 240
          periodSeconds: 240
          failureThreshold: 1
          tcpSocket:
            port: 8080
  traffic:
  - percent: 100
    latestRevision: true
