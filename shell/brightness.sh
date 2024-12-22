#!/bin/sh

# 创建service文件
cat <<EOF | sudo tee /usr/lib/systemd/system/brightness.service > /dev/null
[Unit]
Description=Brightness
After=multi-user.target
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStartPre=/bin/sleep 60
ExecStart=/bin/sh -c 'echo 0 > /sys/class/backlight/backlight/brightness'
ExecStop=/bin/sh -c 'echo 128 > /sys/class/backlight/backlight/brightness'

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用并启动service
sudo systemctl enable brightness.service
sudo systemctl start brightness.service
