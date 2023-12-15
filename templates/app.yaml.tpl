runtime: custom
env: flex
service: default

network:
  name: default
  subnetwork_name: default

resources:
  cpu: 2
  memory_gb: 7.6
  disk_size_gb: 10

manual_scaling:
  instances: 1

includes:
  - app_secrets.yaml
