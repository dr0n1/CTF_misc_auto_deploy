#!/bin/bash
# Author: lewiserii
# Version：1.0 beta


# root运行
[ $(id -u) != "0" ] && { echo "Error: This script must be run as root!"; exit 1; }


# 日志
install_log=/var/log/auto_deploy.log
tm=$(date +'%Y%m%d %T')
COLOR_G="\x1b[0;32m"
RESET="\x1b[0m"

function info(){
    echo -e "${COLOR_G}[$tm] [Info] ${1}${RESET}"
}

function run_cmd(){
    sh -c "$1 | $(tee -a "$install_log")"
}

function run_function(){
    $1 | tee -a "$install_log"
}


function install_docker(){
    info "1.使用脚本自动安装docker..."
    a=$(date "+%s")
    curl -sSL https://get.daocloud.io/docker | sh
    b=$(date "+%s")
    echo "Docker Install Finish. Time: $(($b-$a))s"
		
    info "2.启动 Docker CE..."
    systemctl enable docker
    systemctl start docker

    info "3.测试 Docker 是否安装正确..."
    docker run hello-world

    info "4.检测..."
    docker info

}


function install_docker-compose(){
    info "1.安装docker-compose"
    curl -L "https://github.com/docker/compose/releases/download/v2.4.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
    chmod +x /usr/bin/docker-compose

    info "2.验证docker-compose是否安装成功..."
    docker-compose -v
}
 

function ubuntu_Basics(){
    echo -e "deb https://mirrors.ustc.edu.cn/ubuntu/ kinetic main restricted universe multiverse\ndeb-src https://mirrors.ustc.edu.cn/ubuntu/ kinetic main restricted universe multiverse\ndeb https://mirrors.ustc.edu.cn/ubuntu/ kinetic-security main restricted universe multiverse\ndeb-src https://mirrors.ustc.edu.cn/ubuntu/ kinetic-security main restricted universe multiverse\ndeb https://mirrors.ustc.edu.cn/ubuntu/ kinetic-updates main restricted universe multiverse\ndeb-src https://mirrors.ustc.edu.cn/ubuntu/ kinetic-updates main restricted universe multiverse\ndeb https://mirrors.ustc.edu.cn/ubuntu/ kinetic-backports main restricted universe multiverse\ndeb-src https://mirrors.ustc.edu.cn/ubuntu/ kinetic-backports main restricted universe multiverse" > /etc/apt/sources.list
    apt-get clean
    apt-get update
    apt-get install wget curl net-tools vim openssl -y
}


function centos_Basics(){
    $yumdnf -y install wget
    cd /etc/yum.repos.d/
    rm -rf /etc/yum.repos.d/*
    wget -O /etc/yum.repos.d/CentOS-Base-ali.repo http://mirrors.aliyun.com/repo/Centos-$c_version.repo
    wget -O /etc/yum.repos.d/CentOS-Base-huawei.repo https://repo.huaweicloud.com/repository/conf/CentOS-$c_version-reg.repo
    $yumdnf clean all
    $yumdnf makecache
    $yumdnf update
    $yumdnf -y install git wget bash* net-tools bind-utils vim wget
}



read -p "警告，该脚本可能会对您的计算机进行更改和删除操作，继续运行吗？默认为：yes. Enter [yes/no]：" is_is
if [[ "$is_is" == 'no' ]];then
    exit
fi



# 判断版本
OS=`uname -s`
if [ ${OS} == "Linux" ];then
    source /etc/os-release
    case $ID in
        debian|ubuntu|devuan)
            read -p "是否运行基础配置(换源)？默认为：no. Enter [yes/no]：" is_Basics
            if [[ "$is_Basics" == 'yes' ]];then
                run_function "ubuntu_Basics"
            fi
        ;;
        centos|fedora|rhel)
            yumdnf="yum"
            c_version="7"
            if test "$(echo "$VERSION_ID >= 22" | bc)" -ne 0;
            then
                yumdnf="dnf"
                c_version="8"
            fi
            read -p "是否运行基础配置(换源)？默认为：no. Enter [yes/no]：" is_Basics
            if [[ "$is_Basics" == 'yes' ]];then
                run_function "centos_Basics"
            fi
        ;;
        *)
            exit 1
        ;;
    esac
else
    echo "Other OS: ${OS}"
fi




# 安装docker
read -p "是否安装docker？默认为：no. Enter [yes/no]：" is_docker
if [[ "$is_docker" == 'yes' ]];then
    run_function "install_docker"
fi


# 安装docker-compose
read -p "是否安装docker-compose？默认为 no. Enter [yes/no]：" is_compose
if [[ "$is_compose" == 'yes' ]];then
    run_function "install_docker-compose"
fi
