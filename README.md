
Frps服务端一键配置脚本，最新版本：0.26.0
===========

*Frp 是一个高性能的反向代理应用，可以帮助您轻松地进行内网穿透，对外网提供服务，支持 tcp, http, https 等协议类型，并且 web 服务支持根据域名进行路由转发。*

* 详情：fatedier (https://github.com/fatedier/frp)
* 此脚本原作者：clangcn (https://github.com/clangcn/onekey-install-shell)

## Frps-Onekey-Install-Shell  

### Install（安装）

```Bash
wget https://raw.githubusercontent.com/MvsCode/frp-onekey/master/install-frps.sh -O ./install-frps.sh
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
Frps onkey-install-shell Changelog<br>Frp版本更新说明
---------------------------------------

 <!-- vim-markdown-toc GFM -->
* ## [v0.27.0 [2019/04/25]](#v0.27.0[2019/04/25])
    * ### New
     > Proxy Protocol support plugin unix_domain_socket.  
     > frps support custom 404 page.

* ## [v0.26.0 [2019/04/10]](#v0.26.0[2019/04/10])
    * ### New
     > Support Proxy Protocol.  
       New plugin https2http.
    * ### Fix
     > Fix router config conflict when frpc start by command line mode. #1165

* ## [v0.25.3 [2019/03/26]](#v0.25.3[2019/03/26])
    * ### Fix
     > Fix panic error when reconnection with tls_enable is true.

* ## [v0.25.2 [2019/03/25]](#v0.25.2[2019/03/25])
    * ### Change
     > Change Update version of kcp-go.
    * ### Fix
     > Fix connection leak of http health check. #1155

* ## [v0.25.1 [2019/03/15]](#v0.25.1[2019/03/15])
    * ### Fix
     >Fix a match problem with multilevel subdomain. #1132  
      frps --log_file is useless. #1125

* ## [v0.25.0 [2019/03/11]](#v0.25.0[2019/03/11])
    * ### New
     > Support TLS between frpc and frps, Set
 tls enable to enable this feature in frpC.Improve stability of xtcp.
    * ### Fix
     > Fix a bug that xtcp don't release connections in some case.
     
    ##### Note: xtcp is incompatible with old versions.
 
    ##### 注意:此版本的xtcp和之前版本不兼容,需要同步升级服务端和客户端才能正常使用
 
* ## [v0.24.1 [2019/02/12]](#v0.24.1[2019/02/12])
    * ### Fix
     > Fix Error clear frpc configure file when /api/config called without token set
     
* ## [v0.24.0 [2019/02/11]](#v0.24.0[2019/02/11])
    * ### New
     > New Support admin UI for frpc
     
* ## [v0.23.3 [2019/01/30]](#v0.23.3[2019/01/30])
    * ### Fix
     > Fix Reload proxy not saved after reconnecting
  
* ## [v0.23.2 [2019/01/26]](#v0.23.2[2019/01/26])  
    * ### Fix 
     > Fix client not working caused by reconnecting.

* ## [v0.23.1 [2019/01/16]](#v0.23.1[2019/01/16])  
    * ### Fix 
     >Fix status api.<br> 
     >Fix reload and status command error.

* ## [v0.23.0 [2019/01/15]](#v0.23.0[2019/01/15])
    * ### New
     >Support render configure file template with os environment.
    * ### Change
     >Remove check for authentication timeout.
