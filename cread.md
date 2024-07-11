### 一、编译内核
##### 准备环境 Ubuntu 20.04 
```
sudo apt install binfmt-support qemu-user-static gcc-10-aarch64-linux-gnu kernel-package fakeroot simg2img img2simg mkbootimg bison flex gcc-aarch64-linux-gnu pkg-config libncurses-dev libssl-dev unzip git debootstrap
```

https://github.com/Kiciuk/proprietary_firmware_mido

##### 下载源码与配置
```
# 下载源码
mkdir workspace && cd workspace
git clone https://github.com/msm8953-mainline/linux.git --depth 1

# 下载配置文件
cd ~/workspace/linux
wget https://github.com/lyrnya/linuxformido/blob/main/.config
```
##### 编译内核
```
# 编译内核 生成内核安装包
cd ~/workspace
cat > env.sh << EOF
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
export CC=aarch64-linux-gnu-gcc
EOF
chmod +x env.sh
source ./env.sh
cd ./linux
make clean
rm -r ./debian
make menuconfig
make -j$(nproc)
fakeroot make-kpkg  --initrd --cross-compile aarch64-linux-gnu- --arch arm64 kernel_image kernel_headers -j$(nproc)
```

### 二、制作rootfs镜像
```
cd ~/workspace
dd if=/dev/zero of=root.img bs=1G count=2
mkfs.ext4 root.img

mkdir ~/chroot
sudo mount root.img ~/chroot
sudo debootstrap --arch arm64 stable ~/chroot https://mirrors.tuna.tsinghua.edu.cn/debian/
```

##### Chroot
```
sudo mount --bind /proc ~/chroot/proc
sudo mount --bind /dev ~/chroot/dev
sudo mount --bind /dev/pts ~/chroot/dev/pts
sudo mount --bind /sys ~/chroot/sys
sudo chroot ~/chroot
```

rm /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
useradd -m -s /bin/bash []
usermod -aG sudo,adm []
apt install man man-db bash-completion network-manager wpasupplicant [chrony] openssh-server initramfs-tools --no-install-recommends -y


# kernel
cp ~/workspace/linux*.deb ~/chroot/tmp
cd /tmp
dpkg --get-selections | grep linux
dpkg -l | grep -E "linux-headers|linux-image" |awk '{print $2}'|xargs dpkg -P
rm -rf /lib/modules/*

dpkg -i linux*.deb
dpkg --get-selections | grep linux

ls /lib/modules


cp -r ./firmware/* ~/chroot/usr/lib/firmware/
cd /usr/lib/firmware/
ldconfig


mkdir ~/workspace/tmp_mkboot
rm -rf ~/workspace/tmp_mkboot/*
cp ~/workspace/linux/arch/arm64/boot/dts/qcom/*mido*.dtb ~/workspace/tmp_mkboot/
cp ~/workspace/linux/arch/arm64/boot/Image.gz ~/workspace/tmp_mkboot/
cp ~/chroot/boot/initrd* ~/workspace/tmp_mkboot/

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
        --cmdline "console=tty0 root=UUID=X-X-X-X rw loglevel=3 splash"\
        --kernel ~/workspace/tmp_mkboot/kernel-dtb -o ~/workspace/tmp_mkboot/boot.img



##### 拓展文件系统
```
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
```

##### 配置串口登录
```
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
#如果串口登录失效，可能是g_serial模块没有加载
echo g_serial >> /etc/modules
```

apt clean
rm -f /tmp/*
history -c
Ctrl + D


sudo umount ~/chroot/proc
sudo umount ~/chroot/dev/pts
sudo umount ~/chroot/dev
sudo umount ~/chroot/sys
sudo umount ~/chroot
img2simg ~/workspaces/root.img ~/workspaces/tmp_mkboot/rootfs.img
