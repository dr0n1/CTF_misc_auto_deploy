# auto_deploy

一个自动部署工具的轻量sh脚本


# 目前支持的功能

1：换源等基础操作</br>
2：安装docker</br>
3：安装docker-compose</br>


# 支持的系统（已测试）

1：ubuntu20.04 later</br>
2：centos7/8</br>


# 使用

本脚本可重复运行安装</br>
日志位置：/var/log/auto_deploy.log

方法一：</br>
chmod 777 auto_deploy.sh</br>
./auto_deploy.sh


方法二：</br>
bash <(curl -s https://raw.githubusercontent.com/lewiserii/auto_deploy/main/auto_deploy.sh)
