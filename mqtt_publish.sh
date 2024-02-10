#! /bin/bash

# install deps
apt update && apt install -y curl
curl -LO https://www.emqx.com/en/downloads/MQTTX/v1.9.6/mqttx-cli-linux-x64
install ./mqttx-cli-linux-x64 /usr/local/bin/mqttx

# get version
VERSION="$(grep -R "CONFIG_VERSION_NUMBER" /charlinhos*/.config  | awk -F[\"] '{print $2}')"

# calculate sha256
SHA256=$(sha256sum /output/charlinhos-sysupgrade.bin | awk '{print $1}')

MQTT_TOPIC="environments/$ENVIRON/hlk7628/version"
MQTT_MESSAGE='{"version": "'"$VERSION"'", "sha256sum": "'"$SHA256"'"}'

echo $MQTT_MESSAGE

mqttx pub -h $MQTT_HOSTNAME -p $MQTT_SERVER_PORT -u $MQTT_USER -P "$MQTT_PASSWORD" -t $MQTT_TOPIC -m "$MQTT_MESSAGE" --insecure -r --protocol mqtts