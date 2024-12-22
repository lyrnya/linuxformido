#!/bin/bash

USB_PATH="/sys/class/power_supply/qcom-smbchg-usb"
MAX_CAPACITY=80
MIN_CAPACITY=30
CURRENT_CAPACITY=$(cat /sys/class/power_supply/qcom-battery/capacity)
echo Now Battery Capacity: $(cat /sys/class/power_supply/qcom-battery/capacity)
if [ $CURRENT_CAPACITY -ge $MAX_CAPACITY ]; then

    echo "Battery capacity is above $MAX_CAPACITY%. Charging stopped."
    echo 0 > $USB_PATH/input_current_limit 
elif [ $CURRENT_CAPACITY -le $MIN_CAPACITY ]; then
    echo "Battery capacity is below $MIN_CAPACITY%. Charging started."
    echo 300000 > $USB_PATH/input_current_limit
fi
