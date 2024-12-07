## 准备工作

#### 安装依赖
```
# 使用 Ubuntu 20.04
sudo apt install binfmt-support qemu-user-static gcc-10-aarch64-linux-gnu kernel-package fakeroot simg2img img2simg mkbootimg bison flex gcc-aarch64-linux-gnu pkg-config libncurses-dev libssl-dev unzip git debootstrap rsync libelf-dev dwarves
```

#### 克隆
```
mkdir workspace && cd workspace

# 克隆firmware
git clone https://github.com/Kiciuk/proprietary_firmware_mido

# 克隆kernel
git clone https://github.com/msm8953-mainline/linux.git --depth=1 -b 6.7.5/main

# 下载config
cd ~/workspace/linux
wget https://mirror.ghproxy.com/https://raw.githubusercontent.com/lyrnya/debianformido/main/.config
```

## 编译内核

#### 设置环境变量
```
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
export CC=aarch64-linux-gnu-gcc
```

#### 编译内核
```
cd ~/workspace/linux
make clean
make menuconfig
LOCALVERSION="" make -j$(nproc)
LOCALVERSION="" fakeroot make-kpkg  --initrd --cross-compile aarch64-linux-gnu- --arch arm64 kernel_image kernel_headers -j$(nproc)
```

## 制作rootfs

#### 使用debootstrap生成最小化rootfs
```
cd ~/workspace
dd if=/dev/zero of=root.img bs=1G count=2
mkfs.ext4 root.img
mkdir ~/workspace/chroot
sudo mount root.img ~/workspace/chroot
sudo debootstrap --arch arm64 stable ~/workspace/chroot https://mirrors.tuna.tsinghua.edu.cn/debian/
```

#### chroot
```
sudo mount --bind /proc ~/workspace/chroot/proc
sudo mount --bind /dev ~/workspace/chroot/dev
sudo mount --bind /dev/pts ~/workspace/chroot/dev/pts
sudo mount --bind /sys ~/workspace/chroot/sys
sudo chroot ~/workspace/chroot /bin/bash

# 安装基本软件
apt install apt-transport-https ca-certificates sudo man man-db bash-completion network-manager wpasupplicant openssh-server initramfs-tools locales perl systemd-timesyncd iptables usbutils --no-install-recommends -y

# 设置时区
export PATH=$PATH:/usr/sbin
dpkg-reconfigure tzdata
dpkg-reconfigure locales

# 新建用户
sudo useradd -m -G sudo,adm -s /bin/bash []
passwd root
passwd []

# 复制内核安装包 (host)
cp ~/workspace/linux*.deb ~/workspace/chroot/tmp

# 安装内核 (chroot)
cd /tmp
dpkg --get-selections | grep linux
dpkg -l | grep -E "linux-headers|linux-image" |awk '{print $2}'|xargs dpkg -P
rm -rf /lib/modules/*

dpkg -i linux*.deb
dpkg --get-selections | grep linux

ls /lib/modules

# 复制firmware (host)
mkdir /usr/lib/firmware
sudo cp -r ~/workspace/proprietary_firmware_mido/apnhlos/* ~/workspace/chroot/usr/lib/firmware/
sudo cp -r ~/workspace/proprietary_firmware_mido/firmware/* ~/workspace/chroot/usr/lib/firmware/
sudo cp -r ~/workspace/proprietary_firmware_mido/modem/* ~/workspace/chroot/usr/lib/firmware/

# 执行 (chroot)
cd /usr/lib/firmware/
ldconfig

# 拓展文件系统
cat > /etc/systemd/system/resizefs.service << 'EOF'
[Unit]
Description=Expand root filesystem to fill partition
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'exec /usr/sbin/resize2fs $(findmnt -nvo SOURCE /)'
ExecStartPost=/usr/bin/systemctl disable resizefs.service
RemainAfterExit=true

[Install]
WantedBy=default.target
EOF
systemctl enable resizefs.service

# 开启串口登录
cat > /etc/systemd/system/serial-getty@ttyGS0.service << EOF
[Unit]
Description=Serial Console Service on ttyGS0

[Service]
ExecStart=-/usr/sbin/agetty -L 115200 ttyGS0 xterm+256color
Type=idle
Restart=always
RestartSec=0

[Install]
WantedBy=multi-user.target
EOF
systemctl enable serial-getty@ttyGS0.service

# 如果串口登录失效，可能是g_serial模块没有加载
echo g_serial >> /etc/modules

# 清理
apt clean
rm -f /tmp/*
history -c
Ctrl + D

# 转换刷机镜像
sudo umount ~/workspace/chroot/proc
sudo umount ~/workspace/chroot/dev/pts
sudo umount ~/workspace/chroot/dev
sudo umount ~/workspace/chroot/sys
sudo umount ~/workspace/chroot

sudo e2fsck -p -f root.img
sudo resize2fs -M root.img
img2simg ~/workspace/root.img ~/workspace/tmp_mkboot/rootfs.img
```

#### 生成boot
```
mkdir ~/workspace/tmp_mkboot
rm -rf ~/workspace/tmp_mkboot/*
cp ~/workspace/linux/arch/arm64/boot/dts/qcom/*mido*.dtb ~/workspace/tmp_mkboot/
cp ~/workspace/linux/arch/arm64/boot/Image.gz ~/workspace/tmp_mkboot/
cp ~/workspace/chroot/boot/initrd* ~/workspace/tmp_mkboot/

cp ~/workspace/tmp_mkboot/initrd* ~/workspace/tmp_mkboot/initrd.img
cp ~/workspace/tmp_mkboot/msm*.dtb ~/workspace/tmp_mkboot/dtb
cat ~/workspace/tmp_mkboot/Image.gz ~/workspace/tmp_mkboot/dtb > ~/workspace/tmp_mkboot/kernel-dtb
mkbootimg --base 0x80000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x00000100 \
        --pagesize 2048 \
        --second_offset 0x00f00000 \
        --ramdisk ~/workspace/tmp_mkboot/initrd.img \
        --cmdline "console=tty0 root=UUID=fcf40267-74a1-42b4-909b-e6785814bac7 rw loglevel=3 splash"\
        --kernel ~/workspace/tmp_mkboot/kernel-dtb -o ~/workspace/tmp_mkboot/boot.img
```

### 感谢
https://www.cnblogs.com/holdmyhand/articles/18048158
