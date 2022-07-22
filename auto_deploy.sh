#!/bin/bash
# Author: lewiserii
# Version：1.3 beta


# root运行
[ $(id -u) != "0" ] && { echo "请用root用户运行"; exit 1; }


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
	info "1.卸载旧版本docker"
	apt-get remove docker docker-engine docker-ce docker.io -y
	apt-get update
    info "卸载完毕"

	info "2.开始安装docker"
	ubuntu_version=`lsb_release -r | awk '{print substr($2,1,2)}'`
	if [ $ubuntu_version -le 16 ];then
		apt-get update
		apt-get install -y apt-transport-https ca-certificates curl software-properties-common
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
		add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
		apt-get update
		apt-get install -y docker-ce
	else
		curl -sSL https://get.daocloud.io/docker | sh
	fi
	info "Docker安装完毕"

	info "3.启动 Docker CE..."
	systemctl enable docker
	systemctl start docker
    info "docker启动完毕"

	info "4.检测docker信息"
	docker info
    info "docker检测完毕"
}


function install_docker-compose(){
	info "1.安装docker-compose"
	curl -L "https://github.com/docker/compose/releases/download/v2.4.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
	chmod +x /usr/bin/docker-compose
    info "docker-compose安装完毕"

	info "2.验证docker-compose是否安装成功..."
	docker-compose -v
    info "docker-compose检测完毕"
}


function ubuntu_Basics(){
	info "1.开始获取对应网络源(USTC)"
    rm -rf /var/cache/apt/archives/lock* && rm -rf /var/lib/dpkg/lock* && rm -rf /var/lib/apt/lists/lock*
	apt update 2> /dev/null #适配ubuntu16
	apt install -y curl  #适配ubuntu16
	ubuntu_lsb=$(lsb_release -a 2>/dev/null| awk -F " " '{if ( $1	~ /Codename/ ){ print $2 } }')
	curl  "https://mirrors.ustc.edu.cn/repogen/conf/ubuntu-https-4-"$ubuntu_lsb -o /etc/apt/sources.list
    info "获取源完毕"

	info "2.开始更新"
	rm -rf /var/cache/apt/archives/lock* && rm -rf /var/lib/dpkg/lock* && rm -rf /var/lib/apt/lists/lock*
	apt-get clean
	apt-get update 2> /dev/null
	apt-get install wget net-tools openssl -y
    info "更新完毕"

	info "3.开始解决ubuntu上下键变成ABCD问题"
	apt-get remove vim-common -y
	apt-get install vim -y
    info "ubuntu上下键问题解决完毕"

	info "4.开始配置root用户登录系统"
	echo "greeter-show-manual-login=true" >> /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf
	sed -i -e '3 s/^/#/' /etc/pam.d/gdm-autologin
	sed -i -e '3 s/^/#/' /etc/pam.d/gdm-password
	sed -i '$d' /root/.profile
	echo "tty -s && mesg n || true" >> /root/.profile
	echo "mesg n || true" >> /root/.profile
    info "允许root用户登录配置完毕"

	info "5.开始配置ssh"
	apt remove openssh-client -y
	apt install openssh-server openssh-client ssh -y
	sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
	sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
	service sshd restart
    info "ssh配置完毕"
}


function centos_Basics(){
	info "1.获取网络源(aliyun+huaweicloud)"
	$yumdnf -y install wget
	cd /etc/yum.repos.d/
	rm -rf /etc/yum.repos.d/*
	wget -O /etc/yum.repos.d/CentOS-Base-ali.repo http://mirrors.aliyun.com/repo/Centos-$c_version.repo
	wget -O /etc/yum.repos.d/CentOS-Base-huawei.repo https://repo.huaweicloud.com/repository/conf/CentOS-$c_version-reg.repo

	info "2.更新"
	$yumdnf clean all
	$yumdnf makecache
	$yumdnf update
	$yumdnf -y install git wget bash* net-tools bind-utils vim wget
}


function install_python(){
	py_version=''
	read -p "想要安装python2 or python3(e.g. 3,默认空)" py_version
	if [[ "$py_version" == '' ]];then
		info "没有选择版本哦"
		exit
	elif [[ "$py_version" == '2' ]];then
		read -p "想要安装的版本：（e.g. 2.7.10,默认2.7.10）" py2_version
		if [[ "$py2_version" == '' ]];then
			py2_version="2.7.10"
		fi
		python2 --version > /dev/null 2>&1
		if [ $? -ne 0 ];then
			info "开始安装Python$py2_version 依赖"
			yum install -y wget zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make libffi-devel  
			apt install -y build-essential zlib1g-dev libbz2-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev
			info "开始下载并编译安装Python$py2_version"
			wget https://www.python.org/ftp/python/$py2_version/Python-$py2_version.tgz
			tar -zxvf Python-$py2_version.tgz
			cd Python-$py2_version
			./configure prefix=/usr/local/python2
			make && make install
			ln -s /usr/local/python2/bin/python2.$(echo $py2_version|cut -d '.' -f2) /usr/bin/python2
			python2 --version> /dev/null 2>&1
			if [ $? -ne 0 ];then
				info "python$py2_version安装失败"
				info "清理安装包"
				cd ../
				rm -rf Python-$py2_version*
				info "清理安装包完成"
			else
				info "python$py2_version安装成功"
				info "安装pip2"
				wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
				python2 get-pip.py
				info "清理安装包"
				rm -rf get-pip.py
				cd ../
				rm -rf Python-$py2_version*
				info "清理安装包完成"
			fi
		else
			info "已有python2版本:$(python2 --version),无需再安装python2，如果需要请手动安装"
		fi
	elif [[ "$py_version" == '3' ]];then
		read -p "想要安装的版本：（e.g. 3.9.0,默认3.9.0）" py3_version
		if [[ "$py3_version" == '' ]];then
			py3_version="3.9.0"
		fi
		python3 --version > /dev/null 2>&1
		if [ $? -ne 0 ];then
			info "开始安装Python$py3_version 依赖"
			yum install -y wget zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make libffi-devel 
			apt install -y build-essential zlib1g-dev libbz2-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev		
			info "开始下载并编译安装Python$py3_version"
			wget https://www.python.org/ftp/python/$py3_version/Python-$py3_version.tgz
			tar -zxvf Python-$py3_version.tgz
			cd Python-$py3_version
			./configure prefix=/usr/local/python3
			make && make install
			ln -s /usr/local/python3/bin/python3.$(echo $py3_version|cut -d '.' -f2) /usr/bin/python3
			python3 --version> /dev/null 2>&1
			if [ $? -ne 0 ];then
				info "python$py3_version安装失败"
				info "清理安装包"
				cd ../
				rm -rf Python-$py3_version*
				info "清理安装包完成"
			else
				info "python$py3_version安装成功"
				info "安装pip3"
				wget https://bootstrap.pypa.io/pip/get-pip.py
				python3 get-pip.py
				info "清理安装包"
				rm -rf get-pip.py
				cd ../
				rm -rf Python-$py3_version*
				info "清理安装包完成"
			fi
		else
			info "已有python3版本:$(python3 --version),无需再安装python3，如果需要请手动安装"
		fi
	fi
}


function install_basics(){
	# 判断版本
	OS=`uname -s`
	if [ ${OS} == "Linux" ];then
		source /etc/os-release
		case $ID in
			debian|ubuntu|devuan)
				info "识别到当前系统为ubuntu系列"
				run_function "ubuntu_Basics"
			;;
			centos|fedora|rhel)
				yumdnf="yum"
				c_version="7"
				if test "$(echo "$VERSION_ID >= 22" | bc)" -ne 0;
				then
					yumdnf="dnf"
					c_version="8"
				fi
				info "识别到当前系统为centos系列"
				run_function "centos_Basics"
			;;
			*)
				exit 1
			;;
		esac
	else
		echo "Other OS: ${OS}"
	fi
}


function install_all(){
	install_basics
	install_docker
	install_docker-compose
	install_python
	install_all
}


function usage(){
	echo	"usage: ./auto_deploy.sh [mode]"
	echo	"	  basics            基础配置(换源，root，ssh)"
	echo	"	  docker            安装docker"
	echo	"	  docker-compoer            安装docker-compose"
	echo	"	  python            安装python"
	echo	"	  all           执行上述全部命令"
}



function main(){
	if [[ -z $* ||  $* == "-h" || $* == "-help" ]]; then
		usage
		return
	fi

	for i in $*
	do
		read -p "警告，该脚本可能会对您的计算机进行更改和删除操作，继续运行吗？默认为：yes. Enter [yes/no]：" is_is
		if [[ "$is_is" == 'no' ]];then
			exit
		fi
		case $i in
			basics) install_basics  ;;
			docker) install_docker;;
			docker-compose) install_docker-compose  ;;
			python) install_python   ;;
			all)	install_all ;;
			*)  info "没有这个参数^_^"   ;;
		esac
	done
}

main $*


