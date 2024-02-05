# auto_deploy

一个自动部署 Misc 工具的~~轻量~~sh 脚本</br>
闲的无聊随便写的小玩意

# 目前支持的功能

1：换网络源，允许 root ssh登录</br>
2：安装 docker</br>
3：安装 docker-compose</br>
4：安装 golang</br>
5：安装 java</br>
6：安装 linux 下的部分 misc 工具，具体如下</br>

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
pycdc
sstv
steghide
stegosaurus
stegpy
stegseek
usb-mouse-pcap-visualizer
usbkeyboarddatahacker
volatility2
volatility3
webp
wireshark
zsteg
```

# 支持的系统

1：ubuntu16.04/18.04/20.04/22.04</br>

推荐 ubuntu20 加代理运行</br>

# 使用

本脚本可重复运行安装</br>
工具保存在运行脚本的`misc_tools`目录下</br>

方法一：</br>
git clone https://github.com/dr0n1/auto_deploy</br>
chmod 777 auto_deploy.sh</br>
./auto_deploy.sh [mode]

```shell
usage: ./auto_deploy.sh [mode]
        basics              基础配置(换源，vim，ssh)
        docker              安装docker
        docker-compose      安装docker-compose
        go                  安装golang
        java                安装java
        misc-tools          安装misc工具
```

方法二：</br>
bash <(curl -s https://raw.githubusercontent.com/dr0n1/auto_deploy/main/auto_deploy.sh) [mode]

![](./auto_deploy.gif)

# 更新日志

V1.0: 第一代脚本</br>
V1.1: 增加 python 安装模块</br>
V1.2: 优化安装逻辑等</br>
V1.3：移除 python，新增 golang 和 java</br>
V2.1：增加 CTF-Misc 部分工具的安装</br>
V2.2：优化可重复运行脚本逻辑</br>
V2.3：优化部分 python 模块安装逻辑</br>
V2.4：增加部分misc工具，格式化代码</br>
V3.1：移除了centos的工具支持，增加golang多版本支持等</br>

# 后续计划

1：计划增加 web 系列工具</br>

有疑问或者有更好的建议请联系1930774374@qq.com
