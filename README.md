# PostmarketOS

## TTYescape
```
apk add ttyescape
sudo nano /etc/conf.d/ttyescape.conf
```
```
FONT="/usr/share/consolefonts/LatGrkCyr-12x22.psfu.gz"
```
TTYescape Service
```
sudo nano /etc/init.d/ttyescape
```
```
#!/sbin/openrc-run

name="TTYescape"
description="TTYescape Service"

depend() {
    after *
}

start() {
    ebegin "Open TTYescape"
    /usr/bin/togglevt.sh
    eend $?
}

stop() {
    ebegin "Close TTYescape"
    /usr/bin/togglevt.sh
    eend $?
}
```
```
sudo chmod +x /etc/init.d/ttyescape
```

## ZRAM
```
sudo nano /etc/conf.d/zram-init
```
