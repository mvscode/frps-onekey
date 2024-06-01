
Frps服务端一键配置脚本，脚本已支持获取Frp最新版本
===========

[<img alt="github" src="https://img.shields.io/badge/github/MvsCode/frps_onekey-8da0cb?style=for-the-badge&labelColor=555555&logo=github" height="22">](https://github.com/MvsCode/frps_onekey)
[![Stars](https://img.shields.io/github/stars/MvsCode/frps-onekey?color=green&label=Stars&logo=github_height="24">)](https://github.com/MvsCode/frps-onekey)
[![Fork Badge](https://img.shields.io/github/forks/MvsCode/frps-onekey?style=social)](https://github.com/MvsCode/frps-onekey/fork)




*Frp 是一个高性能的反向代理应用，可以帮助您轻松地进行内网穿透，对外网提供服务，支持 tcp, http, https 等协议类型，并且 web 服务支持根据域名进行路由转发。*

* 详情：fatedier[<img alt="github" src="https://img.shields.io/badge/github/fatedier/frp-8da0cb?style=for-the-badge&labelColor=555555&logo=github" height="16">](https://github.com/fatedier/frp)
* 此脚本原作者：clangcn (https://github.com/clangcn/onekey-install-shell)

## Frps-Onekey-Install-Shell For CentOS/Debian/Ubuntu/Fedora (32bit/64bit)

### Install（安装）

#### Gitee
```Bash
wget https://gitee.com/mvscode/frps-onekey/raw/master/install-frps.sh -O ./install-frps.sh
chmod 700 ./install-frps.sh
./install-frps.sh install
```
#### Github
```Bash
wget https://raw.githubusercontent.com/mvscode/frps-onekey/master/install-frps.sh -O ./install-frps.sh
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
Frps onkey-install-shell
---------------------------------------

 <!-- vim-markdown-toc GFM -->

 * ## [Shell Updated [2023/10/23]]([2023/10/23])
   * ## The install shell hd Support multiple architectures and fetch latest version from Gitee/GitHub
   * ## Thank muxinxy much https://github.com/MvsCode/frps-onekey/pull/92#issue-1957164654
    > Added architecture detection for arm, arm64, mips, mips64, mips64le, mipsle, and riscv64.
    
    > Integrated functionality to retrieve the latest software version from both Gitee and GitHub.
   * ## The Frps Version update details will no longer be indicated today
