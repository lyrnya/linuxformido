#!/bin/sh

# 创建service文件
cat <<EOF | sudo tee /etc/systemd/system/brightness.service > /dev/null
[Unit]
Description=Set the brightness to 0
After=multi-user.target

[Service]
ExecStart=/bin/sh -c 'echo 0 > /sys/class/backlight/backlight/brightness'

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用并启动service
sudo systemctl enable brightness.service
sudo systemctl start brightness.service
