# auto_deploy

一个自动部署工具的~~轻量~~sh脚本


# 目前支持的功能

1：换源，允许root登录（ubuntu），开启ssh等基础操作</br>
2：安装docker</br>
3：安装docker-compose</br>
4：安装python2/3，pip2/3


# 支持的系统（已测试）

1：ubuntu16.04/18.04/20.04/22.04</br>
2：centos7/8</br>


# 使用

本脚本可重复运行安装</br>
日志位置：/var/log/auto_deploy.log

方法一：</br>
chmod 777 auto_deploy.sh</br>
./auto_deploy.sh [mode]

```shell
usage: ./auto_deploy.sh [mode]
        basics		   基础配置(换源，root，ssh)
        docker		   安装docker
        docker-compoer           安装docker-compose
        python		   安装python
        all			   执行上述全部命令
```

方法二：</br>
bash <(curl -s https://raw.githubusercontent.com/lewiserii/auto_deploy/main/auto_deploy.sh) [mode]


# 更新日志
V1.0：第一代脚本</br>
V1.1：增加python安装模块</br>
V1.2: 优化安装逻辑等
