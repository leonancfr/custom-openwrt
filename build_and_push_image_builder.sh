#! /bin/bash

# script to build and push CharlinhOS Image Builder

# get version to build
VERSION="$(grep -R "CONFIG_VERSION_NUMBER" diffconfig  | awk -F[\"] '{print $2}')"

read -p "Digite o ambiente da imagem [STAGING|production]: " ENVIRON
# get default value
ENVIRON=${ENVIRON:-staging}

case $ENVIRON in
    staging | STAGING ) echo -e "\tBuild será feito para STAGING\n" && TAG="$VERSION-rc" && LATEST="latest-rc" ;;
    production | PRODUCTION ) echo -e "\tBuild será feito para PRODUCTION\n" && TAG="$VERSION" && LATEST="latest";;
    * )  echo "\tPor favor, escolha um ambiente válido" && exit 1;;
esac

docker build --push --progress=plain \
  -f Dockerfile \
  --build-arg GITLAB_TOKEN_NAME=$GITLAB_TOKEN_NAME \
  --build-arg GITLAB_TOKEN=$GITLAB_TOKEN \
  --build-arg CHARLES_GO_ENV_FILE=$CHARLES_GO_ENV_FILE \
  --tag registry.gitlab.com/gabriel-technologia/iot/charlinhos:${TAG} \
  --tag registry.gitlab.com/gabriel-technologia/iot/charlinhos:${LATEST} .
