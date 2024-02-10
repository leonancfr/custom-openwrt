#!/bin/bash

# Usage:
#  $ ./deploy param1
# * param1: .env file to load environment variables as in .env.sample
if [ $# == 0 ]; then
    echo "usage: $0 .env_file"
    echo "  .env_file      variáveis de ambiente conforme .env.sample"
    exit 1
fi

function build_image(){

    start_time=$(date +%s)

    # clone OpenWRT repo
    git clone https://git.openwrt.org/openwrt/openwrt.git --branch v22.03.6 --depth 1

    # inject customization files in OpenWRT
    ln -srf mt7628an_hilink_hlk-7628n.dts openwrt/target/linux/ramips/dts/mt7628an_hilink_hlk-7628n.dts
    ln -srf files openwrt/files

    # build image
    docker build -t charlinh_os_base -f Dockerfile.dev .

    # run container 
    docker stop charlinh_os_build && sleep 2
    docker run -d -it --rm --name charlinh_os_build -v ./:/charlinhos -v /tmp:/tmp -v /dev:/dev charlinh_os_base

    # update and install feeds
    docker exec charlinh_os_build bash -c "cd charlinhos && ./openwrt/scripts/feeds update -a"
    docker exec charlinh_os_build bash -c "cd charlinhos && ./openwrt/scripts/feeds install libpam liblzma libnetsnmp"
    docker exec charlinh_os_build bash -c "cd charlinhos && ./openwrt/scripts/feeds install -a" 

    # copy and expand .config file
    docker exec charlinh_os_build bash -c "cd charlinhos && cp diffconfig openwrt/.config" 
    docker exec charlinh_os_build bash -c "cd charlinhos/openwrt && make defconfig" 

    # download make dependencies and make
    docker exec charlinh_os_build bash -c "cd charlinhos/openwrt && make -j $(($(nproc)+1)) download" 
    docker exec charlinh_os_build bash -c "cd charlinhos/openwrt && time make -j $(($(nproc)+1)) V=s" 

    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))

    echo "    Tempo decorrido: $elapsed_time segundos"
    echo "    Log do build em build.log"
    return 0
}

function send_to_sftp_server() {
   echo "Enviando imagem para o servidor SFTP"

    LOCAL_IMAGE_PATH="$(pwd)/openwrt/bin/targets/ramips/mt76x8/charlinhos-1.0.6-ramips-mt76x8-hilink_hlk-7628n-squashfs-sysupgrade.bin"

    REMOTEPATH="Files/hlk7628/staging/1.0.6"

    SFTP_COMMANDS="
    mkdir $REMOTEPATH
    cd $REMOTEPATH
    put $LOCAL_IMAGE_PATH charlinhos-sysupgrade.bin
    "

    sshpass -v -p $SFTP_PASSWORD sftp -o StrictHostKeyChecking=no $SFTP_USERNAME@$SFTP_HOSTNAME <<EOF &> /dev/null
    $SFTP_COMMANDS
EOF

    if [ $? -ne 0 ]; then
      echo "Houve um erro ao executar os comandos SFTP."
      exit 1
    fi

    echo "Imagem enviada para o servidor SFTP com sucesso!"

}

function publish_to_mqtt_broker() {
    echo "Publicando nova versão para os devices de production"
    echo "$MQTT_HOSTNAME $MQTT_TOPIC $MQTT_MESSAGE"

    SHA256=$(sha256sum $(pwd)/openwrt/bin/targets/ramips/mt76x8/charlinhos-1.0.6-ramips-mt76x8-hilink_hlk-7628n-squashfs-sysupgrade.bin | awk '{print $1}')

    MQTT_TOPIC="environments/production/hlk7628/version"
    MQTT_MESSAGE='{"version": "'1.0.6'", "sha256sum": "'"$SHA256"'"}'

    echo $MQTT_TOPIC
    echo $MQTT_MESSAGE

    mqttx pub -h $MQTT_HOSTNAME -p $MQTT_SERVER_PORT -u $MQTT_USER -P $MQTT_PASSWORD -t $MQTT_TOPIC -m "$MQTT_MESSAGE" --insecure -r --protocol mqtts

    if [ $? -ne 0 ]; then
      echo "Houve um erro ao atualizar os dados no MQTT."
      echo "Tente publicar manualmente a mensagem $MQTT_MESSAGE no tópico $MQTT_TOPIC para o ambiente $ENVIRON"
      exit 1
    fi

    echo "Versão publicada no mqtt broker com sucesso!"
}

function check_environment_var(){
    if [ "$MQTT_HOSTNAME" == "" ]; then
        echo "MQTT_HOSTNAME environment var is not defined"
        exit 1
    fi
    if [ "$MQTT_SERVER_PORT" == "" ]; then
        echo "MQTT_SERVER_PORT environment var is not defined"
        exit 1
    fi
    if [ "$MQTT_USER" == "" ]; then
        echo "MQTT_USER environment var is not defined"
        exit 1
    fi
    if [ "$MQTT_PASSWORD" == "" ]; then
        echo "MQTT_PASSWORD environment var is not defined"
        exit 1
    fi
    if [ "$SFTP_PASSWORD" == "" ]; then
        echo "SFTP_PASSWORD environment var is not defined"
        exit 1
    fi
    if [ "$SFTP_USERNAME" == "" ]; then
        echo "SFTP_USERNAME environment var is not defined"
        exit 1
    fi
    if [ "$SFTP_HOSTNAME" == "" ]; then
        echo "SFTP_HOSTNAME environment var is not defined"
        exit 1
    fi
}

echo "--------------------------------------"
echo "- Automatização de deploy de imagens -"
echo "--------------------------------------"

echo "Carregando variáveis de ambiente do arquivo $1"
source $1
echo "Checando variáveis de ambiente"
check_environment_var
echo -e "\tTudo ok ;)\n"

grep -R "CONFIG_VERSION_NUMBER"  openwrt/.config 
VERSION="$(grep -R "CONFIG_VERSION_NUMBER" openwrt/.config  | awk -F[\"] '{print $2}')"
echo -e "\tVersão da imagem a ser gerada: $VERSION\n"

read -p "Digite o ambiente da imagem [STAGING|production]: " ENVIRON
# get default value
ENVIRON=${ENVIRON:-staging}

case $ENVIRON in
    staging | STAGING ) echo -e "\tBuild será feito para STAGING\n" ;;
    production | PRODUCTION ) echo -e "\tBuild será feito para PRODUCTION\n" ;;
    * )  echo "\tPor favor, escolha um ambiente válido" && exit 1;;
esac

# TODO: DO NOT DEPLOY PROD BUILDS, 'cause prod builds should be built only by CI/CD
read -p "Quer fazer o deploy da imagem?[s|N] " SHOULD_I_DEPLOY 
# remove newline
#SHOULD_I_DEPLOY=${SHOULD_I_DEPLOY%$'\n'}
# get default value
SHOULD_I_DEPLOY=${SHOULD_I_DEPLOY:-N}
# just validating input, no actions taken
case $SHOULD_I_DEPLOY in
    [sS]* ) echo -e "\tO deploy ocorrerá após o build\n" ;;
    [nN]* ) echo -e "\tOk, não haverá deploy\n" ;;
    * )  echo "\tPor favor, responda 's' ou 'n'" && exit 1;;
esac

echo -e "Realizando o build da imagem.\n"
build_image
if [ $? -ne 0 ]; then
  echo "Houve um erro ao fazer o build da imagem."
  exit 1
fi

echo -e "Build realizado com sucesso\n"

# Send build to sftp server and publish version to mqtt broker
case $SHOULD_I_DEPLOY in
    [sS]* ) send_to_sftp_server && publish_to_mqtt_broker ;;
    [nN]* ) exit 0 ;;
    *) echo "Opção inválida para o deploy: $SHOULD_I_DEPLOY"
esac

return 0
