set dotenv-load := true

IMAGE := "vdr-demo"
TAG := "latest"
CONTAINER := "vdr-demo"
PORT := "4000"
REGISTRY_IMAGE := "localhost:32000/vdr-demo"
DEPLOY_HOST := "rubybox.dev"
DEPLOYMENT := "veidrodelis-demo-web"

# Install deps and run local dev server
run:
    mix deps.get
    mix phx.server

# Build production release locally
release:
    MIX_ENV=prod mix deps.get
    MIX_ENV=prod mix assets.deploy
    MIX_ENV=prod mix release

# Build 2-stage production image
docker-build image=IMAGE tag=TAG:
    docker build -t {{image}}:{{tag}} .

# Tag image for registry
docker-tag registry_image=REGISTRY_IMAGE image=IMAGE tag=TAG: (docker-build image tag)
    docker tag {{image}}:{{tag}} {{registry_image}}:{{tag}}

# Push image to registry
docker-push registry_image=REGISTRY_IMAGE image=IMAGE tag=TAG: (docker-tag registry_image image tag)
    docker tag {{image}}:{{tag}} {{registry_image}}:{{tag}}
    docker push {{registry_image}}:{{tag}}

# Push image and restart Kubernetes deployment
deploy deploy_host=DEPLOY_HOST deployment=DEPLOYMENT registry_image=REGISTRY_IMAGE image=IMAGE tag=TAG: (docker-push registry_image image tag)
    ssh {{deploy_host}} microk8s.kubectl rollout restart deployment/{{deployment}}

# Build compose stack images
compose-build:
    docker compose -f ci/docker-compose.yml build

# Start local multi-node stack (valkey + 3 app nodes + nginx)
compose-up:
    docker compose -f ci/docker-compose.yml up -d --build

# Stream compose logs
compose-logs:
    docker compose -f ci/docker-compose.yml logs -f

# Stop and remove compose stack
compose-down:
    docker compose -f ci/docker-compose.yml down
