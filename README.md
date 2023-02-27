# auto_deploy

一个自动部署Misc工具的~~轻量~~sh脚本</br>
闲的无聊随便写的小玩意（部分代码由chatgpt完成）


# 目前支持的功能

1：换源，允许root登录（ubuntu），开启ssh等基础操作</br>
2：安装docker</br>
3：安装docker-compose</br>
4：安装golang</br>
5：安装java</br>
6：安装linux下的部分misc工具，具体如下</br>

```text
binwalk
bkcrack
blindwatermark
cloacked-pixel
dtmf2num
dwarf2json
exif
extundelete
f5-steganography
foremost
gaps
gnuplot
minimodem
montage
outguess
sstv
steghide
stegpy
stegseek
volatility2
volatility3
webp
zsteg
```



# 支持的系统

1：ubuntu16.04/18.04/20.04/22.04</br>
2：~~centos7/8~~(只有部分功能适配了centos)</br>

推荐ubuntu20</br>

# 使用

本脚本可重复运行安装</br>
工具保存在运行脚本的`misc_tools`目录下</br>


方法一：</br>
git clone https://github.com/lewiserii/auto_deploy</br>
chmod 777 auto_deploy.sh</br>
./auto_deploy.sh [mode]

```shell
usage: ./auto_deploy.sh [mode]
        basics              基础配置(换源，root，ssh)
        docker              安装docker
        docker-compoer      安装docker-compose
        go                  安装golang
        java                安装java
        misc-tools          安装misc工具
```

方法二：</br>
bash <(curl -s https://raw.githubusercontent.com/lewiserii/auto_deploy/main/auto_deploy.sh) [mode]

![](https://lewiserii.oss-cn-hangzhou.aliyuncs.com/auto_deploy/auto_deploy.gif)

# 更新日志
V1.0: 第一代脚本</br>
V1.1: 增加python安装模块</br>
V1.2: 优化安装逻辑等</br>
V1.3：移除python，新增golang和java</br>
V2.1：增加CTF-Misc部分工具的安装</br>
V2.2：优化可重复运行脚本逻辑</br>


# 后续计划 #

1：计划增加web系列工具
