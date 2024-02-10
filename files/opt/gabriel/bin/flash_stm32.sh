#!/bin/bash

FILENAME=$1

echo "###"
echo "Script to flash STM32 firmware"
echo -e "###\n"
echo "Setting ports to enable flashing"
echo "default-on" > /sys/class/leds/BOOT_STM32/trigger
sleep 1
echo "none" > /sys/class/leds/RESET_STM32/trigger
sleep 1
echo "default-on" > /sys/class/leds/RESET_STM32/trigger
sleep 1

echo "Flashing $1"
stm32flash -w $FILENAME -v -b 115200 /dev/ttyS1

RETURNCODE=$?

if [ $RETURNCODE != 0 ]; then
    echo "Error, please try again"
else
    echo "Flashing succeeded \o/"
fi

echo "Reseting ports to default values"
echo "none" > /sys/class/leds/BOOT_STM32/trigger
sleep 1
echo "none" > /sys/class/leds/RESET_STM32/trigger
sleep 1
echo "default-on" > /sys/class/leds/RESET_STM32/trigger

echo "Bye, happy hacking :)"
exit 0