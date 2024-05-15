#!/bin/bash
# Author: dr0n1
# Version：3.2 beta
# Email: 1930774374@qq.com

[ $(id -u) != "0" ] && {
	echo "请用root用户运行"
	exit 1
}

misc_tools_dir="misc_tools"
tm=$(date +'%Y%m%d %T')
COLOR_G="\x1b[0;32m"
COLOR_R="\x1b[0;31m"
RESET="\x1b[0m"

function info() {
	echo -e "${COLOR_G}[$tm] [Info] ${1}${RESET}"
}

function error() {
	echo -e "${COLOR_R}[$tm] [Error] ${1}${RESET}"
#	exit 1
}

# function detecting_system() {
# 	OS=$(uname -s)
# 	if [ ${OS} == "Linux" ]; then
# 		source /etc/os-release
# 		case $ID in
# 		debian | ubuntu | devuan)
# 			os_type="Ubuntu"
# 			;;
# 		centos | fedora | rhel)
# 			yumdnf="yum"
# 			c_version="7"
# 			if test "$(echo "$VERSION_ID >= 22" | bc)" -ne 0; then
# 				yumdnf="dnf"
# 				c_version="8"
# 			fi
# 			os_type="Centos"
# 			;;
# 		*)
# 			exit 1
# 			;;
# 		esac
# 	elif [ ${OS} == "Windows_NT" ]; then
# 		os_type="Windows"
# 	else
# 		os_type="Unknow"
# 	fi
# }

function install_docker() {
	if command -v docker &>/dev/null; then
		read -p "Docker已经安装，是否卸载并安装最新版本？ （可能发生某些意外） 默认为：no. Enter [yes/no]: " answer
		if [[ $answer == "Y" || $answer == "y" || $answer == "YES" || $answer == "yes" ]]; then
			info "1.卸载旧版本 Docker..."
			apt-get remove docker docker-engine docker-ce docker.io -y
			apt-get update
			info "卸载完毕"
		else
			info "取消安装最新版本 Docker"
			exit 0
		fi
	fi

	info "2.开始安装 Docker..."
	ubuntu_version=$(lsb_release -r | awk '{print substr($2,1,2)}')
	if [ $ubuntu_version -le 16 ]; then
		apt-get update
		apt-get install -y apt-transport-https ca-certificates curl software-properties-common
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
		add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
		apt-get update
		apt-get install -y docker-ce
	else
		curl -sSL https://get.daocloud.io/docker | sh
		if [ $? -ne 0 ]; then
			curl -fLsS https://get.docker.com/ | sh
		fi
	fi

	if ! command -v docker &>/dev/null; then
		error "可能由于网络原因或其他未知原因导致Docker安装失败，请检查后重试"
		exit 1
	fi

	info "Docker安装完毕"

	info "3.启动 Docker CE..."
	systemctl enable docker
	systemctl start docker
	info "docker启动完毕"

	info "4.检测 Docker 信息"
	docker info
	info "docker检测完毕"
}

function install_docker-compose() {
	if command -v docker-compose &>/dev/null; then
		info "docker-compose已安装"
		exit 0
	fi

	info "1.安装docker-compose"
	# curl -L https://get.daocloud.io/docker/compose/releases/download/v2.6.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
	curl -L https://github.com/docker/compose/releases/download/v2.6.1/docker-compose-$(uname -s)-$(uname -m) >/usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose

	if ! command -v docker-compose &>/dev/null; then
		error "可能由于网络原因或其他未知原因导致docker-compose安装失败，请检查后重试"
		exit 1
	fi

	info "docker-compose安装完毕"

	info "2.验证docker-compose是否安装成功..."
	docker-compose -v
	info "docker-compose检测完毕"
}

function install_basics() {
	if ! grep -q "mirrors.ustc.edu.cn" /etc/apt/sources.list; then
		info "开始获取对应网络源(USTC)"
		rm -rf /var/cache/apt/archives/lock* && rm -rf /var/lib/dpkg/lock* && rm -rf /var/lib/apt/lists/lock*
		apt update 2>/dev/null #适配ubuntu16
		apt install -y curl    #适配ubuntu16
		ubuntu_lsb=$(lsb_release -a 2>/dev/null | awk -F " " '{if ( $1	~ /Codename/ ){ print $2 } }')
		curl "https://mirrors.ustc.edu.cn/repogen/conf/ubuntu-https-4-"$ubuntu_lsb -o /etc/apt/sources.list
		info "ustc源获取完毕"
	else
		info "已经获取对应网络源(USTC)"
	fi

	info "开始更新源"
	apt-get clean
	apt-get update 2>/dev/null
	apt-get install wget net-tools openssl -y
	info "更新完毕"

	info "开始解决ubuntu vim上下键变成ABCD问题"
	apt-get remove vim-common -y
	apt-get install vim -y
	info "ubuntu vim问题解决完毕"

	info "开始配置root用户登录系统"
	if ! grep -q "greeter-show-manual-login=true" /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf; then
		echo "greeter-show-manual-login=true" >>/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf
	fi
	if ! sed -n '3p' /etc/pam.d/gdm-autologin | grep -q '^#'; then
		sed -i '3s/^/#/' /etc/pam.d/gdm-autologin
	fi
	if ! sed -n '3p' /etc/pam.d/gdm-password | grep -q '^#'; then
		sed -i '3s/^/#/' /etc/pam.d/gdm-password
	fi
	if ! grep -q "mesg" /root/.profile; then
		echo 'tty -s && mesg n || true' >>/root/.profile
		echo 'mesg n || true' >>/root/.profile
	else
		sed -i '/mesg n || true/d' /root/.profile
		echo 'tty -s && mesg n || true' >>/root/.profile
		echo 'mesg n || true' >>/root/.profile
	fi
	info "root用户登录配置完毕"

	info "开始配置ssh"
	apt remove openssh-client -y
	apt install openssh-server openssh-client ssh -y
	sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
	sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
	service sshd restart
	info "ssh配置完毕"

}

function install_go() {
	go_version='1.14.2'

	if command -v go &>/dev/null; then
		go_version=$(go version | awk '{print $3}')
		info "${go_version}已安装"
		exit 0
	fi

	read -p "请输入要安装的Go版本: (e.g. 1.20.4 /默认为${go_version})" input_go_version
	if [[ $input_go_version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)*$ ]]; then
		go_version=$input_go_version
	fi

	info "开始下载golang ${go_version}"
	wget -c https://dl.google.com/go/go${go_version}.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local

	if [ $? -ne 0 ]; then
		error "golang ${go_version}下载失败，请检查版本号或网络后重试"
		exit 1
	fi

	info "创建软连接"
	ln -s /usr/local/go/bin/* /usr/bin/

	go version >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		error "go ${go_version}安装失败"
		exit 1
	else
		go env -w GOPROXY=https://goproxy.cn
		info "go ${go_version}安装成功"
	fi
}

function install_java() {
	info "请输入想要安装的版本 (e.g. 11 or 16):"
	read java_version

	if command -v java &>/dev/null; then
		installed_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
		if [[ $installed_version == $java_version* ]]; then
			info "Java $java_version 已经安装"
			exit 0
		fi
	fi

	info "开始安装java $java_version"
	apt-get install -y openjdk-$java_version-jdk

	if [ $? -ne 0 ]; then
		error "java安装失败，请检查网络或其他原因后重试"
		exit 1
	else
		info "java $java_version 安装完成"
	fi
}

function install_ctf_misc_tools() {
	info "请输入需要安装的工具名，多个工具名请用逗号隔开（例如：binwalk,foremost），支持使用all安装所有工具:"
	read input

	input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
	tools=($(echo "$input" | tr ',' ' '))
	unsupported_tools=()
	supported_tools=()

	for func_name in $(declare -F | awk '{print $3}' | grep "^install_misc_"); do
		supported_tools+=("${func_name#install_misc_}")
	done

	info "正在安装某些必要模块"
	install_misctool_base

	for tool in "${tools[@]}"; do
		if [[ "${tools[*]}" =~ "all" ]]; then
			for tool_name in "${supported_tools[@]}"; do
				info "正在安装 $tool_name 工具..."
				if [ "$(type -t install_misc_$tool_name)" = "function" ]; then
					install_misc_$tool_name
				else
					unsupported_tools+=("$tool_name")
				fi
			done
		else
			if [ "$(type -t install_misc_$tool)" = "function" ]; then
				info "正在安装 $tool 工具..."
				install_misc_$tool
			else
				unsupported_tools+=("$tool")
			fi
		fi
	done

	if [ ${#unsupported_tools[@]} -ne 0 ]; then
		error "暂不支持安装以下工具："
		for tool in "${unsupported_tools[@]}"; do
			error "- $tool"
		done
		list_supported_tools
	fi

	if [ ! -d "$misc_tools_dir" ]; then
		mkdir -p "$misc_tools_dir"
	fi
}

function list_supported_tools {
	info "支持的工具列表:"
	for func_name in $(declare -F | awk '{print $3}' | grep "^install_misc_"); do
		info "- ${func_name#install_misc_}"
	done
}

function install_misctool_base() {
	apt-get install -y git gcc cmake python-dev python3-dev libbz2-dev

	if ! command -v python2 &>/dev/null; then
		info "开始安装python2"
		apt install -y python2
		info "python2安装结束"
	fi

	if ! command -v pip2 &>/dev/null; then
		info "开始安装pip2"
		wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
		python2 get-pip.py
		rm -rf get-pip.py
		info "pip2安装结束"
	fi

	if ! python2 -c "import numpy" &>/dev/null; then
		pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple numpy
	fi

	if ! python2 -c "import matplotlib" &>/dev/null; then
		apt-get install -y python-tk
		pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple matplotlib
	fi

	if ! python2 -c "import PIL" &>/dev/null; then
		pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple pillow
	fi

	if ! python2 -c "import enum" &>/dev/null; then
		pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple enum
	fi

	if ! command -v pip3 &>/dev/null; then
		info "开始安装pip3"
		apt-get install -y python3-distutils
		wget https://bootstrap.pypa.io/pip/get-pip.py
		python3 get-pip.py
		rm -rf get-pip.py
		if command -v pip3 &>/dev/null; then
			info "pip3安装完成"
		else
			apt install -y python3-pip
			info "pip3安装完成"
		fi
	fi

	if ! python3 -c "import numpy" &>/dev/null; then
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple numpy
	fi

	if ! python3 -c "import cv2" &>/dev/null; then
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple opencv-python
	fi

	if ! python3 -c "import matplotlib" &>/dev/null; then
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple matplotlib
	fi

	if ! python3 -c "import pytest" &>/dev/null; then
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pytest
	fi

	if ! python3 -c "import PIL" &>/dev/null; then
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pillow
	fi

	if ! python3 -c "import pyshark" &>/dev/null; then
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pyshark
	fi
}

function install_misc_exif() {
	if command -v exiftool &>/dev/null; then
		info "exiftool 已经安装"
	else
		sudo apt install -y exiftool
		info "exiftool 安装完成"
	fi
}

function install_misc_binwalk() {
	if command -v binwalk &>/dev/null; then
		info "binwalk 已经安装"
	else
		sudo apt-get install -y binwalk
		info "binwalk 安装完成"
	fi
}

function install_misc_foremost() {
	if command -v foremost &>/dev/null; then
		info "foremost 已经安装"
	else
		sudo apt-get install -y foremost
		info "foremost 安装完成"
	fi
}

function install_misc_cloacked-pixel() {
	if [ -f $misc_tools_dir/cloacked-pixel/lsb.py ]; then
		info "clocked-pixel已安装"
	else
		info "开始安装cloacked-pixel"
		git clone https://github.com/livz/cloacked-pixel $misc_tools_dir/cloacked-pixel
		info "cloacked-pixel安装完成"
	fi
}

function install_misc_steghide() {
	if command -v steghide &>/dev/null; then
		info "steghide已安装"
	else
		info "开始安装steghide"
		apt install -y steghide
		info "steghide安装成功"
	fi
}

function install_misc_stegseek() {
	if command -v stegseek &>/dev/null; then
		info "stegseek已安装"
	else
		info "开始安装stegseek"
		wget https://github.com/RickdeJager/stegseek/releases/download/v0.6/stegseek_0.6-1.deb
		apt install -y ./stegseek_0.6-1.deb
		rm -rf stegseek_0.6-1.deb

		if [ -f /usr/share/wordlists/rockyou.txt ]; then
			info "stegseek安装结束"
		else
			wget https://gitee.com/lewiserii/rockyou.txt/releases/download/rockyou/rockyou.zip
			unzip rockyou.zip
			rm -rf rockyou.zip
			mkdir /usr/share/wordlists
			mv rockyou.txt /usr/share/wordlists/rockyou.txt
		fi

		info "stegseek安装结束"
	fi
}

function install_misc_f5-steganography() {
	if [ -f ./$misc_tools_dir/F5-steganography/Extract.java ]; then
		info "F5-steganography已安装"
	else
		info "开始安装F5-steganography"
		git clone https://github.com/matthewgao/F5-steganography $misc_tools_dir/F5-steganography
		info "F5-steganography安装结束"
	fi
}

function install_misc_zsteg() {
	if command -v ruby &>/dev/null; then
		if command -v gem &>/dev/null; then
			if command -v zsteg &>/dev/null; then
				info "zsteg已安装"
			else
				info "开始安装zsteg"
				gem install zsteg
				info "zsteg安装完成"
			fi
		else
			info "未检测到gem命令，开始安装gem和zsteg"
			apt instal -y gem
			gem install zsteg
			info "zsteg和gem安装完成"
		fi
	else
		info "未检测到ruby环境，开始安装ruby,gem和zsteg"
		apt install -y ruby
		apt install -y gem
		gem install zsteg
		info "zsteg,gem和ruby安装完成"
	fi
}

function install_misc_extundelete() {
	if command -v extundelete &>/dev/null; then
		info "extundelete已安装"
	else
		info "开始安装extundelete"
		apt-get install -y extundelete
		info "extundelete安装完成"
	fi
}

function install_misc_outguess() {
	if command -v outguess &>/dev/null; then
		info "outguess已安装"
	else
		info "开始安装outguess"
		apt-get install -y outguess
		info "outguess安装完成"
	fi
}

function install_misc_bkcrack() {
	if [ -f ./$misc_tools_dir/bkcrack-1.5.0-Linux/bkcrack ]; then
		info "bkcrack已安装"
	else
		info "开始安装bkcrack"
		wget https://github.com/kimci86/bkcrack/releases/download/v1.5.0/bkcrack-1.5.0-Linux.tar.gz
		tar xf bkcrack-1.5.0-Linux.tar.gz -C $misc_tools_dir/
		rm -rf bkcrack-1.5.0-Linux.tar.gz
		info "bkcrack安装成功"
	fi
}

function install_misc_gnuplot() {
	if command -v gnuplot &>/dev/null; then
		info "gnuplot已安装"
	else
		info "开始安装gnuplot"
		apt install -y gnuplot
		info "gnuplot安装完成"
	fi
}

function install_misc_blindwatermark() {
	if [ -f ./$misc_tools_dir/BlindWaterMark/bwm.py ]; then
		info "BlindWaterMark已安装"
	else
		info "开始安装BlindWaterMark"
		git clone https://github.com/chishaxie/BlindWaterMark $misc_tools_dir/BlindWaterMark
		info "BlindWaterMark安装完成"
	fi
}

function install_misc_montage() {
	if command -v montage &>/dev/null; then
		info "montage已安装"
	else
		info "开始安装montage"
		apt-get install -y graphicsmagick-imagemagick-compat
		info "montage安装完成"
	fi
}

function install_misc_gaps() {
	if command -v gaps &>/dev/null; then
		info "gaps已安装"
	else
		rm -rf $misc_tools_dir/gaps
		info "开始安装gaps"
		git clone https://github.com/nemanja-m/gaps $misc_tools_dir/gaps

		if ! python3 -c "import poetry" &>/dev/null; then
			pip3 install oct2py --ignore-installed pexpect
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple poetry
		fi

		echo '[[tool.poetry.source]]' >>$misc_tools_dir/gaps/pyproject.toml
		echo 'name = "tsinghua"' >>$misc_tools_dir/gaps/pyproject.toml
		echo 'default = true' >>$misc_tools_dir/gaps/pyproject.toml
		echo 'url = "https://pypi.tuna.tsinghua.edu.cn/simple" ' >>$misc_tools_dir/gaps/pyproject.toml

		cd $misc_tools_dir/gaps && poetry lock --no-update && poetry install && pip3 install . -i https://mirrors.aliyun.com/pypi/simple && cd -
		if command -v gaps &>/dev/null; then
			info "gaps安装成功"
			rm -rf $misc_tools_dir/gaps
		else
			error "gaps安装失败,请检查后重试"
			rm -rf $misc_tools_dir/gaps
		fi
	fi
}

function install_misc_volatility2() {
	if [ -f ./$misc_tools_dir/volatility2/build/scripts-2.7/vol.py ] && python2 -c "from Crypto.Cipher import AES" &>/dev/null; then
		info "volatility2已安装"
	else
		info "开始安装volatility2"
		git clone https://github.com/volatilityfoundation/volatility $misc_tools_dir/volatility2

		if ! python2 -c "import setuptools" &>/dev/null; then
			pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple setuptools
		fi

		if ! python2 -c "from Crypto.Cipher import AES" &>/dev/null; then
			pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple pycrypto
		fi

		if ! python2 -c "import distorm3" &>/dev/null; then
			pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple distorm3
		fi

		cd $misc_tools_dir/volatility2 && python2 setup.py install && cd -
		info "volatility2安装完成"
	fi
}

function install_misc_volatility3() {
	if [ -f ./$misc_tools_dir/volatility3/build/lib/volatility3/__init__.py ]; then
		info "volatility3已安装"
	else
		info "开始安装volatility3"
		git clone https://github.com/volatilityfoundation/volatility3 $misc_tools_dir/volatility3

		if python3 -c "import setuptools" &>/dev/null; then
			if [[ $(pip3 list | grep setuptools | awk '{print $2}') > '66.0.0' ]]; then
				pip3 uninstall -y setuptools
				pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple setuptools==49.2.1
			fi
		else
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple setuptools==49.2.1
		fi

		if ! python3 -c "from Crypto.Cipher import AES" &>/dev/null; then
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pycryptodome
		fi

		if ! python3 -c "import yara" &>/dev/null; then
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple yara-python
		fi

		cd $misc_tools_dir/volatility3 && python3 setup.py install && cd -
		info "volatility3安装完成"
	fi
}

function install_misc_dwarf2json() {
	if [ -f ./$misc_tools_dir/dwarf2json/dwarf2json ]; then
		info "dwarf2json已安装"
	else
		if command -v go &>/dev/null; then
			go_version=$(go version | awk '{print $3}')
			required_version="go1.18"
			if [[ "$(printf '%s\n' "$required_version" "$go_version" | sort -V | head -n1)" == "$required_version" ]]; then
				info "开始安装dwarf2json"
				git clone https://github.com/volatilityfoundation/dwarf2json $misc_tools_dir/dwarf2json
				cd $misc_tools_dir/dwarf2json
				go build
				cd -
				info "dwarf2json安装结束"
			else
				error "dwarf2json安装失败，Go版本过低，请安装Go 1.18或更高版本"
			fi
		else
			info "未检测到go环境，请安装Go 1.18或更高版本"
			install_go
			info "开始安装dwarf2json"
			git clone https://github.com/volatilityfoundation/dwarf2json $misc_tools_dir/dwarf2json
			cd $misc_tools_dir/dwarf2json
			go build
			cd -
			info "dwarf2json安装结束"
		fi
	fi
}

function install_misc_webp() {
	if command -v dwebp &>/dev/null; then
		info "webp已安装"
	else
		info "开始安装webp"
		apt install -y webp
		info "webp安装完成"
	fi
}

function install_misc_stegpy() {
	if pip3 list | grep "stegpy" &>/dev/null; then
		info "stegpy已安装"
	else
		info "开始安装stegpy"
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple stegpy
		info "stegpy安装完成"
	fi
}

function install_misc_minimodem() {
	if command -v minimodem &>/dev/null; then
		info "minimodem已安装"
	else
		info "开始安装minimodem"
		apt install -y minimodem
		info "minimodem安装完成"
	fi
}

function install_misc_dtmf2num() {
	if command -v dtmf2num &>/dev/null; then
		info "dtmf2num已安装"
	else
		info "开始安装dtmf2num"
		apt install -y dtmf2num
		info "dtmf2num安装完成"
	fi
}

function install_misc_sstv() {
	if command -v sstv &>/dev/null; then
		info "sstv已安装"
	else
		if pip3 list | grep -q "scipy"; then
			info "scipy已安装"
		else
			info "开始安装scipy"
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple scipy
			info "scipy安装完成"
		fi

		if pip3 list | grep -q "cffi"; then
			info "cffi已安装"
		else
			info "开始安装cffi"
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple cffi
			info "cffi安装完成"
		fi

		git clone https://github.com/colaclanth/sstv.git $misc_tools_dir/sstv

		if [[ $(pip3 list | grep setuptools | awk '{print $2}') > '66.0.0' ]]; then
			pip3 uninstall -y setuptools
			pip3 install setuptools==49.2.1
		fi

		cd $misc_tools_dir/sstv && python3 setup.py install && cd -

		if command -v sstv &>/dev/null; then
			info "sstv安装成功"
			rm -rf $misc_tools_dir/sstv
		else
			error "sstv安装失败"
			rm -rf $misc_tools_dir/sstv
		fi
	fi
}

function install_misc_usb-mouse-pcap-visualizer() {
	if [ -f ./$misc_tools_dir/USB-Mouse-Pcap-Visualizer/usb-mouse-pcap-visualizer.py ]; then
		info "USB-Mouse-Pcap-Visualizer脚本已存在"
	else
		info "开始下载USB-Mouse-Pcap-Visualizer脚本"
		git clone https://github.com/WangYihang/USB-Mouse-Pcap-Visualizer $misc_tools_dir/USB-Mouse-Pcap-Visualizer
		info "USB-Mouse-Pcap-Visualizer脚本已下载"
	fi
}

function install_misc_usbkeyboarddatahacker() {
	if [ -f ./$misc_tools_dir/UsbKeyboardDataHacker/UsbKeyboardDataHacker.py ]; then
		info "UsbKeyboardDataHacker脚本已存在"
	else
		info "开始下载UsbKeyboardDataHacker脚本"
		git clone https://github.com/WangYihang/UsbKeyboardDataHacker $misc_tools_dir/UsbKeyboardDataHacker
		info "UsbKeyboardDataHacker脚本已下载"
	fi
}

function install_misc_wireshark() {
	if command -v wireshark &>/dev/null; then
		info "wireshark已安装"
	else
		info "开始安装wireshark"
		apt install -y wireshark tshark
		info "wireshark安装完成"
	fi
}

function install_misc_pycdc() {
	if [ -f ./$misc_tools_dir/pycdc/pycdc ]; then
		info "pycdc已存在"
	else
		info "开始下载pycdc脚本"
		git clone https://github.com/zrax/pycdc $misc_tools_dir/pycdc
		cd $misc_tools_dir/pycdc && cmake . && make && cd -
		info "pycdc已安装"
	fi
}

function install_misc_stegosaurus() {
	if command -v stegosaurus &>/dev/null; then
		info "stegosaurus已存在"
	else
		info "开始下载stegosaurus"
		wget https://github.com/AngelKitty/stegosaurus/releases/download/1.0/stegosaurus -O /usr/local/bin/stegosaurus
		chmod +x /usr/local/bin/stegosaurus
		info "stegosaurus已安装"
	fi
}

function usage() {
	echo "usage: ./auto_deploy.sh [mode]"
	echo "		basics				基础配置(换源，vim，ssh等，适合刚安装完的裸机使用)"
	echo "		docker				安装docker"
	echo "		docker-compose			安装docker-compose"
	echo "		go				安装golang"
	echo "		java				安装java"
	echo "		misc-tools			安装misc工具"
}

function main() {
	if [[ -z $* || $* == "-h" || $* == "-help" ]]; then
		usage
		return
	fi

	for i in $*; do
		read -p "警告，该脚本可能会对您的系统进行某些更改和删除操作，继续运行吗？默认为：yes. Enter [yes/no]：" is_is
		if [[ $is_is == "no" || $is_is == "NO" ]]; then
			info "取消安装"
			exit 0
		fi
		case $i in
		basics) install_basics ;;
		docker) install_docker ;;
		docker-compose) install_docker-compose ;;
		go) install_go ;;
		java) install_java ;;
		misc-tools) install_ctf_misc_tools ;;
		*) info "没有这个参数^_^" ;;
		esac
	done
}

main $*
