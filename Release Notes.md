Frps onkey-install-shell Changelog<br>Frp版本更新说明
---------------------------------------

 <!-- vim-markdown-toc GFM -->

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
