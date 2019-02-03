
Frps服务端一键配置脚本，最新版本：0.23.3
===========

*Frp 是一个高性能的反向代理应用，可以帮助您轻松地进行内网穿透，对外网提供服务，支持 tcp, http, https 等协议类型，并且 web 服务支持根据域名进行路由转发。*

* 详情：fatedier (https://github.com/fatedier/frp）
* 此脚本原作者：clangcn （https://github.com/clangcn/onekey-install-shell）

## Frps-Onekey-Install-Shell  

### Install（安装）

```Bash
wget https://raw.githubusercontent.com/jacko1045/frp-test/master/install-frps.sh -O ./install-frps.sh
chmod 700 ./install-frps.sh
./install-frps.sh install
```

### Uninstall（卸载）
```Bash
./install-frps.sh uninstall
```
### Update（更新）
```Bash
./install-frps.sh update
```
### Server management（服务管理器）
```Bash
Usage: /etc/init.d/frps {start|stop|restart|status|config|version}
```
