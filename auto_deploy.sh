#!/bin/bash
# Author: dr0n1
# Version：4.2 beta
# Email: 1930774374@qq.com

ubuntu_version=$(lsb_release -rs | cut -d. -f1)
misc_tools_dir="misc_tools"
pwn_tools_dir="pwn_tools"
web_tools_dir="web_tools"
COLOR_G="\x1b[0;32m"
COLOR_R="\x1b[0;31m"
COLOR_Y="\x1b[0;33m"
RESET="\x1b[0m"

function info() {
	printf "${COLOR_G}[$(date +'%Y%m%d %T')] [Info] %s${RESET}\n" "$1"
}

function warn() {
	printf "${COLOR_Y}[$(date +'%Y%m%d %T')] [Warning] %s${RESET}\n" "$1"
}

function error() {
	printf "${COLOR_R}[$(date +'%Y%m%d %T')] [Error] %s${RESET}\n" "$1"
}

function install_basics() {
	if ! grep -q "mirrors.ustc.edu.cn" /etc/apt/sources.list; then
		info "开始获取对应网络源(USTC)"

		if ! command -v curl >/dev/null 2>&1; then
			info "安装 curl..."
			apt-get update -q
			apt-get install -y curl
		fi

		ubuntu_lsb=$(lsb_release -c -s)
		src_url="https://mirrors.ustc.edu.cn/repogen/conf/ubuntu-https-4-${ubuntu_lsb}"

		if curl -fsSL "$src_url" -o /etc/apt/sources.list; then
			info "USTC 源配置成功"
		else
			error "获取 USTC 源失败，检查网络或 codename: $ubuntu_lsb"
		fi
	else
		info "系统已使用 USTC 源，跳过"
	fi

	info "更新软件包索引"
	apt-get clean
	apt-get update -q
	apt-get install -y wget net-tools openssl >/dev/null 2>&1
	info "基础工具安装完成"

	if ! vim --version 2>/dev/null | grep -q "+mouse"; then
		info "修复 vim 上下键异常问题"
		apt-get remove -y vim-common >/dev/null 2>&1
		apt-get install -y vim >/dev/null 2>&1
		info "vim 修复完成"
	else
		info "vim 已为完整版，跳过修复"
	fi

	info "配置 root 图形登录"
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
	info "root 登录配置完成"

	info "配置 SSH 服务"
	apt remove openssh-client -y
	apt install openssh-server openssh-client ssh -y
	sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
	sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
	if systemctl list-units --type=service | grep -q ssh; then
		systemctl enable ssh
		systemctl restart ssh
	else
		service ssh restart
	fi
	info "ssh配置完毕"

}

function install_docker() {
	if command -v docker &>/dev/null; then
		read -p "Docker已经安装，是否卸载并安装最新版本？ （可能发生某些意外） 默认为：no. Enter [yes/no]: " answer
		if [[ $answer =~ ^([yY][eE][sS]|[yY])$ ]]; then
			info "卸载旧版 Docker..."
			apt-get remove -y docker docker-engine docker-ce docker.io containerd runc >/dev/null 2>&1
			apt-get purge -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
			rm -rf /var/lib/docker /var/lib/containerd
			info "旧版本卸载完毕"
		else
			info "取消安装 Docker"
			return
		fi
	fi

	info "准备安装 Docker..."
	ubuntu_codename=$(lsb_release -cs)
	ubuntu_version=$(lsb_release -rs | cut -d'.' -f1)

	if [ "$ubuntu_version" -le 16 ]; then
		info "Ubuntu $ubuntu_version 为旧版本，使用 Docker 官方源手动添加方式"
		apt-get update -q
		apt-get install -y apt-transport-https ca-certificates curl software-properties-common

		if ! apt-key list 2>/dev/null | grep -q "Docker Release"; then
			curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - >/dev/null 2>&1
		fi

		if ! grep -q "^deb .*download.docker.com" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
			add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $ubuntu_codename stable" >/dev/null 2>&1
		fi

		apt-get update -q
		apt-get install -y docker-ce
	else
		info "尝试使用 Daocloud 安装脚本"
		if curl -fsSL https://get.daocloud.io/docker -o /tmp/docker_install.sh; then
			bash /tmp/docker_install.sh
			info "使用 Daocloud 安装成功"
		else
			warn "无法连接 get.daocloud.io，切换至 Docker 官方安装脚本"
			if curl -fsSL https://get.docker.com -o /tmp/docker_install.sh; then
				bash /tmp/docker_install.sh
				info "使用官方脚本安装成功"
			else
				error "Docker 安装失败，无法从任何源获取"
				exit 1
			fi
		fi
	fi

	rm -rf /tmp/docker_install.sh
	if ! command -v docker &>/dev/null; then
		error "Docker 安装失败，可能是网络问题或安装源故障"
		exit 1
	fi

	info "Docker 安装成功，正在启动服务..."
	systemctl enable docker >/dev/null 2>&1
	systemctl restart docker

	info "Docker 信息如下："
	if ! docker info 2>/dev/null; then
		error "docker info 执行失败，请确认服务是否正常运行"
	fi
	info "Docker 安装与检测完成"
}

function install_docker-compose() {
	if command -v docker-compose &>/dev/null; then
		info "docker-compose 已安装，版本：$(docker-compose --version)"
		return
	fi

	if ! curl -fsSL https://github.com/docker/compose/releases/download/v2.6.1/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose; then
		warn "GitHub 下载失败，尝试使用备用源（daocloud）"
		if ! curl -fsSL https://get.daocloud.io/docker/compose/releases/download/v2.6.1/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose; then
			error "docker-compose 下载失败，请检查网络或稍后重试"
			exit 1
		fi
	fi

	chmod +x /usr/local/bin/docker-compose
	if ! command -v docker-compose &>/dev/null; then
		error "可能由于网络原因或其他未知原因导致docker-compose安装失败，请检查后重试"
		exit 1
	fi

	info "docker-compose 安装成功"
	docker-compose --version
}

function install_go() {
	default_go_version="1.18"

	if command -v go &>/dev/null; then
		info "$(go version) 已安装"
		return
	fi

	read -p "请输入要安装的 Go 版本 (默认为 ${default_go_version}，格式如 1.20.4): " input_version
	if [[ $input_go_version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)*$ ]]; then
		go_version="$input_version"
	else
		go_version="$default_go_version"
	fi

	info "开始下载golang ${go_version}"
	if ! wget -c https://golang.google.cn/dl/go${go_version}.linux-amd64.tar.gz -O /tmp/go${go_version}.tar.gz; then
		error "无法下载 Go 安装包（https://golang.google.cn），请检查版本号或网络"
		exit 1
	fi

	info "解压并安装 Go ${go_version}..."
	rm -rf /usr/local/go
	tar -C /usr/local -xzf /tmp/go${go_version}.tar.gz
	ln -sf /usr/local/go/bin/go /usr/local/bin/go
	ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

	if ! command -v go &>/dev/null; then
		error "Go 安装失败，请检查 tar 解压或路径问题"
		exit 1
	fi

	go env -w GOPROXY=https://goproxy.cn,direct

	info "Go ${go_version} 安装成功: $(go version)"
}

function install_java() {
	if command -v java &>/dev/null; then
		current_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
		info "当前已安装 Java 版本：$current_version"

		read -p "是否继续安装其他版本？默认为 no，输入 yes 安装: " choice
		if [[ ! "$choice" =~ ^([yY][eE][sS]?|[yY])$ ]]; then
			info "已取消安装其他版本"
			return
		fi
	fi

	read -p "请输入要安装的 OpenJDK 版本（例如 8 或 11），默认为 11: " input_version
	installed_version=${input_version:-11}

	if update-alternatives --list java 2>/dev/null | grep -q "java-$installed_version-openjdk"; then
		info "OpenJDK $installed_version 已经存在，无需重复安装"
	else
		info "安装 OpenJDK $installed_version..."
		apt-get update -q
		if ! apt-get install -y openjdk-${installed_version}-jdk; then
			error "Java 安装失败，请检查版本号或网络连接"
			exit 1
		fi
	fi

	info "配置默认 Java 版本..."
	update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-${installed_version}-openjdk-amd64/bin/java 1
	update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-${installed_version}-openjdk-amd64/bin/javac 1
	update-alternatives --set java /usr/lib/jvm/java-${installed_version}-openjdk-amd64/bin/java
	update-alternatives --set javac /usr/lib/jvm/java-${installed_version}-openjdk-amd64/bin/javac

	info "当前 Java 版本为：$(java -version 2>&1 | head -n 1)"
}

function install_ctf_pwn_tools() {
	info "开始安装 pwntools 及常用PWN工具"

	install_misctool_base
	if [[ $ubuntu_version -le 22 ]]; then
		apt-get install -y libssl-dev libffi-dev build-essential gdb ruby ruby-full ruby-dev build-essential qemu qemu-user qemu-user-static
	else
		apt-get install -y libssl-dev libffi-dev build-essential gdb ruby ruby-full ruby-dev build-essential qemu-user qemu-user-static
	fi

	if ! python3 -c "import pwn" &>/dev/null; then
		info "正在安装 pwntools ..."
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pwntools $PIP_BREAK_ARG
	else
		info "pwntools 已安装"
	fi

	if ! command -v ropper &>/dev/null; then
		info "正在安装 ropper ..."
		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple ropper $PIP_BREAK_ARG
	else
		info "ropper 已安装"
	fi

	if ! command -v one_gadget &>/dev/null; then
		info "安装 one_gadget ..."

		ruby_ver=$(ruby -v | awk '{print $2}')
		ruby_major=$(echo "$ruby_ver" | cut -d. -f1)
		ruby_minor=$(echo "$ruby_ver" | cut -d. -f2)

		if [[ "$ruby_major" -lt 3 || ("$ruby_major" -eq 3 && "$ruby_minor" -lt 1) ]]; then
			info "当前 Ruby 版本为 $ruby_ver，安装 one_gadget 兼容版本..."
			gem install elftools -v 1.2.0
			gem install one_gadget -v 1.7.2
		else
			info "Ruby 版本满足要求，安装最新版 one_gadget"
			gem install one_gadget
		fi
	else
		info "one_gadget 已安装"
	fi

	if [ ! -d "$pwn_tools_dir/pwndbg" ]; then
		info "正在安装 pwndbg ..."
		git clone https://github.com/pwndbg/pwndbg "$pwn_tools_dir/pwndbg"
		pushd "$pwn_tools_dir/pwndbg" >/dev/null
		./setup.sh
		popd >/dev/null
	else
		info "pwndbg 已安装"
	fi

	if [ ! -f "$HOME/.gdbinit-gef.py" ]; then
		info "正在安装 gef ..."
		curl -s -L -o "$HOME/.gdbinit-gef.py" https://gef.blah.cat/gef.py
		if ! grep -q "gef.py" "$HOME/.gdbinit"; then
			echo "source ~/.gdbinit-gef.py" >>"$HOME/.gdbinit"
		fi
	else
		info "gef 已安装"
	fi

	if ! command -v seccomp-tools &>/dev/null; then
		info "安装 seccomp-tools ..."
		gem install seccomp-tools
	else
		info "seccomp-tools 已安装"
	fi

	if command -v qemu-x86_64 &>/dev/null; then
		info "QEMU 已安装"
	else
		error "QEMU 安装失败，请手动检查"
	fi

	info "所有 PWN 工具安装完成"
}

function install_ctf_web_tools() {
	info "支持的工具列表如下（可输入 all 全部安装）："
	list_supported_tools

	read -p "请输入要安装的工具名，多个工具用英文逗号分隔（如：frp,nps）: " input
	input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
	[ -z "$input" ] && {
		error "未输入任何工具名称，已取消安装"
		return
	}

	tools=($(echo "$input" | tr ',' ' '))
	supported_tools=()
	unsupported_tools=()

	for func in $(declare -F | awk '{print $3}' | grep '^install_web_'); do
		supported_tools+=("${func#install_web_}")
	done

	info "正在安装基础依赖..."
	install_misctool_base

	if [[ " ${tools[*]} " =~ " all " ]]; then
		for tool in "${supported_tools[@]}"; do
			info "正在安装 $tool ..."
			install_web_"$tool"
		done
	else
		declare -A installed_map=()
		for tool in "${tools[@]}"; do
			if [[ -n "${installed_map[$tool]}" ]]; then
				continue
			fi
			installed_map[$tool]=1

			if [[ " ${supported_tools[*]} " =~ " $tool " ]]; then
				info "正在安装 $tool ..."
				install_web_"$tool"
			else
				unsupported_tools+=("$tool")
			fi
		done
	fi

	if [[ ${#unsupported_tools[@]} -ne 0 ]]; then
		error "以下工具暂不支持："
		for tool in "${unsupported_tools[@]}"; do
			error "- $tool"
		done
	fi

	[ ! -d "$web_tools_dir" ] && mkdir -p "$web_tools_dir"
}

function install_ctf_misc_tools() {
	info "支持的工具列表如下（可输入 all 全部安装）："
	list_supported_tools

	read -p "请输入要安装的工具名，多个工具用英文逗号分隔（如：binwalk,foremost）: " input
	input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
	[ -z "$input" ] && {
		error "未输入任何工具名称，已取消安装"
		return
	}

	tools=($(echo "$input" | tr ',' ' '))
	supported_tools=()
	unsupported_tools=()

	for func in $(declare -F | awk '{print $3}' | grep '^install_misc_'); do
		supported_tools+=("${func#install_misc_}")
	done

	info "正在安装基础依赖..."
	install_misctool_base

	if [[ " ${tools[*]} " =~ " all " ]]; then
		for tool in "${supported_tools[@]}"; do
			info "正在安装 $tool ..."
			install_misc_"$tool"
		done
	else
		declare -A installed_map=()
		for tool in "${tools[@]}"; do
			if [[ -n "${installed_map[$tool]}" ]]; then
				continue
			fi
			installed_map[$tool]=1

			if [[ " ${supported_tools[*]} " =~ " $tool " ]]; then
				info "正在安装 $tool ..."
				install_misc_"$tool"
			else
				unsupported_tools+=("$tool")
			fi
		done
	fi

	if [[ ${#unsupported_tools[@]} -ne 0 ]]; then
		error "以下工具暂不支持："
		for tool in "${unsupported_tools[@]}"; do
			error "- $tool"
		done
	fi

	[ ! -d "$misc_tools_dir" ] && mkdir -p "$misc_tools_dir"
}

function list_supported_tools {
	local caller=${FUNCNAME[1]}
	local prefix=""

	case "$caller" in
	install_ctf_misc_tools)
		prefix="install_misc_"
		;;
	install_ctf_web_tools)
		prefix="install_web_"
		;;
	*)
		echo "Unknown caller: $caller"
		return 1
		;;
	esac

	for func_name in $(declare -F | awk '{print $3}' | grep "^${prefix}"); do
		info "- ${func_name#${prefix}}"
	done
}

function install_misctool_base() {
	info "安装系统依赖包"
	apt-get update -q
	apt-get install -y git gcc make cmake python3-dev libbz2-dev build-essential zlib1g-dev libssl-dev libreadline-dev libsqlite3-dev curl checkinstall libncursesw5-dev tk-dev libgdbm-dev libc6-dev libffi-dev

	if [[ $ubuntu_version -le 22 ]]; then
		apt-get install -y python2-dev python-tk python3-distutils
		if ! command -v python2 &>/dev/null; then
			info "安装 python2..."
			if ! apt-get install -y python2; then
				error "python2 安装失败，请检查网络或软件源配置"
				exit 1
			fi
		fi
	else
		pip3 install --upgrade setuptools -i https://pypi.tuna.tsinghua.edu.cn/simple --break-system-packages
		if ! command -v python2 &>/dev/null; then
			info "Ubuntu $ubuntu_version 未检测到 python2，开始从源码安装 Python 2.7.18"

			tmp_dir=$(mktemp -d)
			pushd "$tmp_dir" >/dev/null

			wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
			tar -xzf Python-2.7.18.tgz
			pushd Python-2.7.18 >/dev/null

			./configure --enable-optimizations
			make altinstall

			ln -sfn '/usr/local/bin/python2.7' '/usr/bin/python2'

			popd >/dev/null
			popd >/dev/null
			rm -rf "$tmp_dir"

			if ! command -v python2 &>/dev/null; then
				error "Python2 安装失败，请检查编译日志"
				exit 1
			fi
		fi

	fi

	if ! command -v pip2 &>/dev/null; then
		info "安装 pip2..."
		wget -q https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /tmp/get-pip2.py
		python2 /tmp/get-pip2.py && rm -f /tmp/get-pip2.py
	fi

	if ! command -v pip2 &>/dev/null; then
		error "pip2安装失败，请重试"
		exit 1
	fi

	declare -A py2_modules_map=(
		[numpy]=numpy
		[matplotlib]=matplotlib
		[pillow]=PIL
		[enum]=enum
		[setuptools]=setuptools
		[requests]=requests
	)

	for pkg in "${!py2_modules_map[@]}"; do
		mod="${py2_modules_map[$pkg]}"
		if ! python2 -c "import ${mod}" &>/dev/null; then
			info "安装 Python2 模块：$pkg (import 名: $mod)"
			pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade "$pkg"
		fi
	done

	if ! command -v pip3 &>/dev/null; then
		info "安装 pip3..."
		wget -q https://bootstrap.pypa.io/pip/get-pip.py -O /tmp/get-pip3.py
		python3 /tmp/get-pip3.py && rm -f /tmp/get-pip3.py
	fi

	if ! command -v pip3 &>/dev/null; then
		apt-get install -y -q python3-pip
	fi

	if ! command -v pip3 &>/dev/null; then
		error "pip3安装失败，请重试"
		exit 1
	fi

	PIP_VERSION=$(pip3 --version | awk '{print $2}')
	PIP_MAJOR=$(echo "$PIP_VERSION" | cut -d. -f1)
	PIP_MINOR=$(echo "$PIP_VERSION" | cut -d. -f2)

	if [ "$PIP_MAJOR" -gt 23 ] || { [ "$PIP_MAJOR" -eq 23 ] && [ "$PIP_MINOR" -ge 0 ]; }; then
		PIP_BREAK_ARG="--break-system-packages"
	else
		PIP_BREAK_ARG=""
	fi

	declare -A py3_modules_map=(
		[numpy]=numpy
		[opencv-python]=cv2
		[matplotlib]=matplotlib
		[pytest]=pytest
		[pillow]=PIL
		[pyshark]=pyshark
		[yara-python]=yara
		[coloredlogs]=coloredlogs
		[loguru]=loguru
		[tqdm]=tqdm
		[soundfile]=soundfile
		[pefile]=pefile
	)

	for pkg in "${!py3_modules_map[@]}"; do
		mod="${py3_modules_map[$pkg]}"
		if ! python3 -c "import ${mod}" &>/dev/null; then
			info "安装 Python3 模块：$pkg (import 名: $mod)"
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade "$pkg" $PIP_BREAK_ARG
		fi
	done
}

# apt install
function install_misc_exif() {
	if command -v exiftool &>/dev/null; then
		info "exiftool 已经安装，版本：$(exiftool -ver 2>/dev/null)"
		return
	fi

	info "开始安装 exiftool..."
	if apt-get install -y exiftool; then
		if command -v exiftool &>/dev/null; then
			info "exiftool 安装完成，版本：$(exiftool -ver 2>/dev/null)"
		else
			error "exiftool 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "exiftool 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_binwalk() {
	if command -v binwalk &>/dev/null; then
		info "binwalk 已经安装"
		return
	fi

	info "开始安装 binwalk..."
	if apt-get install -y binwalk; then
		if command -v binwalk &>/dev/null; then
			info "binwalk 安装完成"
		else
			error "binwalk 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "binwalk 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_foremost() {
	if command -v foremost &>/dev/null; then
		info "foremost 已经安装"
		return
	fi

	info "开始安装 foremost..."
	if apt-get install -y foremost; then
		if command -v foremost &>/dev/null; then
			info "foremost 安装完成"
		else
			error "foremost 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "foremost 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_extundelete() {
	if command -v extundelete &>/dev/null; then
		info "extundelete 已经安装"
		return
	fi

	info "开始安装 extundelete..."
	if apt-get install -y extundelete; then
		if command -v extundelete &>/dev/null; then
			info "extundelete 安装完成"
		else
			error "extundelete 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "extundelete 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_outguess() {
	if command -v outguess &>/dev/null; then
		info "outguess 已经安装"
		return
	fi

	info "开始安装 outguess..."
	if apt-get install -y outguess; then
		if command -v outguess &>/dev/null; then
			info "outguess 安装完成"
		else
			error "outguess 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "outguess 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_gnuplot() {
	if command -v gnuplot &>/dev/null; then
		info "gnuplot 已经安装"
		return
	fi

	info "开始安装 gnuplot..."
	if apt-get install -y gnuplot; then
		if command -v gnuplot &>/dev/null; then
			info "gnuplot 安装完成"
		else
			error "gnuplot 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "gnuplot 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_montage() {
	if command -v montage &>/dev/null; then
		info "montage 已经安装"
		return
	fi

	info "开始安装 montage..."
	if apt-get install -y graphicsmagick-imagemagick-compat; then
		if command -v montage &>/dev/null; then
			info "montage 安装完成"
		else
			error "montage 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "montage 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_webp() {
	if command -v dwebp &>/dev/null; then
		info "webp 已经安装"
		return
	fi

	info "开始安装 webp..."
	if apt-get install -y webp; then
		if command -v dwebp &>/dev/null; then
			info "webp 安装完成"
		else
			error "webp 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "webp 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_minimodem() {
	if command -v minimodem &>/dev/null; then
		info "minimodem 已经安装"
		return
	fi

	info "开始安装 minimodem..."
	if apt-get install -y minimodem; then
		if command -v minimodem &>/dev/null; then
			info "minimodem 安装完成"
		else
			error "minimodem 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "minimodem 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_dtmf2num() {
	if command -v dtmf2num &>/dev/null; then
		info "dtmf2num 已经安装"
		return
	fi

	info "开始安装 dtmf2num..."
	if apt-get install -y dtmf2num; then
		if command -v dtmf2num &>/dev/null; then
			info "dtmf2num 安装完成"
		else
			error "dtmf2num 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "dtmf2num 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_wireshark() {
	if command -v wireshark &>/dev/null; then
		info "wireshark 已经安装"
		return
	fi

	info "开始安装 wireshark..."
	if apt-get install -y wireshark tshark; then
		if command -v wireshark &>/dev/null; then
			info "wireshark 安装完成"
		else
			error "wireshark 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "wireshark 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_identify() {
	if command -v identify &>/dev/null; then
		info "identify 已经安装"
		return
	fi

	info "开始安装 identify..."
	if apt-get install -y imagemagick; then
		if command -v identify &>/dev/null; then
			info "identify 安装完成"
		else
			error "identify 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "identify 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_steghide() {
	if command -v steghide &>/dev/null; then
		info "steghide 已经安装"
		return
	fi

	info "开始安装 steghide..."
	if apt-get install -y steghide; then
		if command -v steghide &>/dev/null; then
			info "steghide 安装完成"
		else
			error "steghide 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "steghide 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_stegseek() {
	if command -v stegseek &>/dev/null; then
		info "stegseek 已经安装"
		return
	fi

	info "开始安装 stegseek..."
	if wget https://github.com/RickdeJager/stegseek/releases/download/v0.6/stegseek_0.6-1.deb && apt-get install -y ./stegseek_0.6-1.deb; then
		rm -rf stegseek_0.6-1.deb

		if command -v stegseek &>/dev/null; then
			if [ -f /usr/share/wordlists/rockyou.txt ]; then
				info "stegseek 安装完成"
			else
				info "下载 rockyou.txt 字典文件..."
				if wget https://gitee.com/lewiserii/rockyou.txt/releases/download/rockyou/rockyou.zip && unzip rockyou.zip; then
					rm -rf rockyou.zip
					mkdir -p /usr/share/wordlists
					mv rockyou.txt /usr/share/wordlists/rockyou.txt
					info "stegseek 安装完成，字典文件已配置"
				else
					error "rockyou.txt 字典文件下载失败"
				fi
			fi
		else
			error "stegseek 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "stegseek 安装失败，请检查网络或软件源配置"
	fi
}

function install_misc_zsteg() {
	if command -v zsteg &>/dev/null; then
		info "zsteg 已经安装"
		return
	fi

	info "开始安装 zsteg..."

	if ! command -v ruby &>/dev/null; then
		info "安装 ruby 环境..."
		if ! apt-get install -y ruby; then
			error "ruby 安装失败，请检查网络或软件源配置"
			return
		fi
	fi

	if ! command -v gem &>/dev/null; then
		info "安装 gem 包管理器..."
		if ! apt-get install -y gem; then
			error "gem 安装失败，请检查网络或软件源配置"
			return
		fi
	fi

	if gem install zsteg; then
		if command -v zsteg &>/dev/null; then
			info "zsteg 安装完成"
		else
			error "zsteg 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "zsteg 安装失败，请检查gem源配置"
	fi
}

# git clone
function install_misc_cloacked-pixel() {
	if [ -d "$misc_tools_dir/cloacked-pixel" ] && [ -f "$misc_tools_dir/cloacked-pixel/lsb.py" ]; then
		info "cloacked-pixel 已经安装"
		return
	fi

	info "开始安装 cloacked-pixel..."
	if git clone https://github.com/livz/cloacked-pixel $misc_tools_dir/cloacked-pixel; then
		if [ -d "$misc_tools_dir/cloacked-pixel" ] && [ -f "$misc_tools_dir/cloacked-pixel/lsb.py" ]; then
			info "cloacked-pixel 安装完成"
		else
			error "cloacked-pixel 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "cloacked-pixel 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_f5-steganography() {
	if [ -d "$misc_tools_dir/F5-steganography" ] && [ -f "$misc_tools_dir/F5-steganography/Extract.java" ]; then
		info "F5-steganography 已经安装"
		return
	fi

	info "开始安装 F5-steganography..."
	if git clone https://github.com/matthewgao/F5-steganography $misc_tools_dir/F5-steganography; then
		if [ -d "$misc_tools_dir/F5-steganography" ] && [ -f "$misc_tools_dir/F5-steganography/Extract.java" ]; then
			info "F5-steganography 安装完成"
		else
			error "F5-steganography 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "F5-steganography 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_blindwatermark() {
	if [ -d "$misc_tools_dir/BlindWaterMark" ] && [ -f "$misc_tools_dir/BlindWaterMark/bwm.py" ]; then
		info "BlindWaterMark 已经安装"
		return
	fi

	info "开始安装 BlindWaterMark..."
	if git clone https://github.com/chishaxie/BlindWaterMark $misc_tools_dir/BlindWaterMark; then
		if [ -d "$misc_tools_dir/BlindWaterMark" ] && [ -f "$misc_tools_dir/BlindWaterMark/bwm.py" ]; then
			info "BlindWaterMark 安装完成"
		else
			error "BlindWaterMark 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "BlindWaterMark 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_volatility2() {
	if [ -d "$misc_tools_dir/volatility2" ] && [ -f "$misc_tools_dir/volatility2/build/scripts-2.7/vol.py" ] && python2 -c "from Crypto.Cipher import AES" &>/dev/null; then
		info "volatility2已安装"
		return
	fi

	info "开始安装 volatility2..."
	if git clone https://github.com/volatilityfoundation/volatility $misc_tools_dir/volatility2; then
		if ! python2 -c "from Crypto.Cipher import AES" &>/dev/null; then
			pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple pycrypto
		fi
		if ! python2 -c "import distorm3" &>/dev/null; then
			pip2 install -i https://pypi.tuna.tsinghua.edu.cn/simple distorm3
		fi

		pushd "$misc_tools_dir/volatility2" >/dev/null
		python2 setup.py install
		popd >/dev/null

		if [ -d "$misc_tools_dir/volatility2" ] && [ -f "$misc_tools_dir/volatility2/build/scripts-2.7/vol.py" ] && python2 -c "from Crypto.Cipher import AES" &>/dev/null; then
			info "volatility2 安装完成"
		else
			error "volatility2 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "volatility2 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_volatility3() {
	if [ -d "$misc_tools_dir/volatility3" ] && [ -f "$misc_tools_dir/volatility3/volatility3/__init__.py" ]; then
		info "volatility3已安装"
		return
	fi

	info "开始安装 volatility3..."
	if git clone https://github.com/volatilityfoundation/volatility3 $misc_tools_dir/volatility3; then
		# if python3 -c "import setuptools" &>/dev/null; then
		# 	if [[ $(pip3 list | grep setuptools | awk '{print $2}') > '66.0.0' ]]; then
		# 		pip3 uninstall -y setuptools
		# 		pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple setuptools==49.2.1 $PIP_BREAK_ARG
		# 	fi
		# else
		# 	pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple setuptools==49.2.1 $PIP_BREAK_ARG
		# fi

		if ! python3 -c "from Crypto.Cipher import AES" &>/dev/null; then
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pycryptodome $PIP_BREAK_ARG
		fi

		pushd "$misc_tools_dir/volatility3" >/dev/null
		pip3 install --user -e ".[full]" -i https://pypi.tuna.tsinghua.edu.cn/simple $PIP_BREAK_ARG
		popd >/dev/null

		if [ -d "$misc_tools_dir/volatility3" ] && [ -f "$misc_tools_dir/volatility3/volatility3/__init__.py" ]; then
			info "volatility3 安装完成"
		else
			error "volatility3 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "volatility3 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_usb-mouse-pcap-visualizer() {
	if [ -d "$misc_tools_dir/USB-Mouse-Pcap-Visualizer" ] && [ -f "$misc_tools_dir/USB-Mouse-Pcap-Visualizer/usb-mouse-pcap-visualizer.py" ]; then
		info "USB-Mouse-Pcap-Visualizer 已经安装"
		return
	fi

	info "开始安装 USB-Mouse-Pcap-Visualizer..."
	if git clone https://github.com/WangYihang/USB-Mouse-Pcap-Visualizer $misc_tools_dir/USB-Mouse-Pcap-Visualizer; then
		if [ -d "$misc_tools_dir/USB-Mouse-Pcap-Visualizer" ] && [ -f "$misc_tools_dir/USB-Mouse-Pcap-Visualizer/usb-mouse-pcap-visualizer.py" ]; then
			info "USB-Mouse-Pcap-Visualizer 安装完成"
		else
			error "USB-Mouse-Pcap-Visualizer 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "USB-Mouse-Pcap-Visualizer 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_usbkeyboarddatahacker() {
	if [ -d "$misc_tools_dir/UsbKeyboardDataHacker" ] && [ -f "$misc_tools_dir/UsbKeyboardDataHacker/UsbKeyboardDataHacker.py" ]; then
		info "UsbKeyboardDataHacker 已经安装"
		return
	fi

	info "开始安装 UsbKeyboardDataHacker..."
	if git clone https://github.com/WangYihang/UsbKeyboardDataHacker $misc_tools_dir/UsbKeyboardDataHacker; then
		if [ -d "$misc_tools_dir/UsbKeyboardDataHacker" ] && [ -f "$misc_tools_dir/UsbKeyboardDataHacker/UsbKeyboardDataHacker.py" ]; then
			info "UsbKeyboardDataHacker 安装完成"
		else
			error "UsbKeyboardDataHacker 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "UsbKeyboardDataHacker 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_sstv() {
	if command -v sstv &>/dev/null; then
		info "sstv 已经安装"
		return
	fi

	info "开始安装 sstv..."

	if ! pip3 list | grep -q "scipy"; then
		info "安装 scipy 依赖..."
		if ! pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple scipy $PIP_BREAK_ARG; then
			error "scipy 安装失败，请检查网络或pip源配置"
			return
		fi
	fi

	if ! pip3 list | grep -q "cffi"; then
		info "安装 cffi 依赖..."
		if ! pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple cffi $PIP_BREAK_ARG; then
			error "cffi 安装失败，请检查网络或pip源配置"
			return
		fi
	fi

	if git clone https://github.com/colaclanth/sstv.git $misc_tools_dir/sstv; then
		# if [[ $(pip3 list | grep setuptools | awk '{print $2}') > '66.0.0' ]]; then
		# 	pip3 uninstall -y setuptools
		# 	pip3 install setuptools==49.2.1 $PIP_BREAK_ARG
		# fi

		pushd "$misc_tools_dir/sstv" >/dev/null
		if python3 setup.py install; then
			popd >/dev/null
			rm -rf $misc_tools_dir/sstv
			if command -v sstv &>/dev/null; then
				info "sstv 安装完成"
			else
				error "sstv 安装过程未报错，但命令未找到，可能路径未正确配置"
			fi
		else
			popd >/dev/null
			rm -rf $misc_tools_dir/sstv
			error "sstv 编译安装失败，请检查Python环境"
		fi
	else
		error "sstv 下载失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_pycdc() {
	if [ -d "$misc_tools_dir/pycdc" ] && [ -f "$misc_tools_dir/pycdc/pycdc" ]; then
		info "pycdc 已经安装"
		return
	fi

	info "开始安装 pycdc..."
	if git clone https://github.com/zrax/pycdc $misc_tools_dir/pycdc; then
		pushd "$misc_tools_dir/pycdc" >/dev/null
		if cmake . && make; then
			popd >/dev/null
			if [ -d "$misc_tools_dir/pycdc" ] && [ -f "$misc_tools_dir/pycdc/pycdc" ]; then
				info "pycdc 安装完成"
			else
				error "pycdc 编译完成，但可执行文件未找到，可能编译失败"
			fi
		else
			popd >/dev/null
			error "pycdc 编译失败，请检查cmake和make环境"
		fi
	else
		error "pycdc 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_gaps() {
	if [[ $ubuntu_version -ge 24 ]]; then
		warn "暂不支持ubuntu24，如需要可手动安装"
		return
	fi

	if command -v gaps &>/dev/null; then
		info "gaps已安装"
	else
		rm -rf $misc_tools_dir/gaps
		info "开始安装 gaps..."
		git clone https://github.com/nemanja-m/gaps $misc_tools_dir/gaps

		if ! python3 -c "import poetry" &>/dev/null; then
			pip3 install oct2py --ignore-installed pexpect $PIP_BREAK_ARG
			pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple poetry $PIP_BREAK_ARG
		fi

		poetry config repositories.tsinghua https://pypi.tuna.tsinghua.edu.cn/simple

		pushd "$misc_tools_dir/gaps" >/dev/null
		poetry install && pip3 install . -i https://mirrors.aliyun.com/pypi/simple $PIP_BREAK_ARG
		popd >/dev/null

		if command -v gaps &>/dev/null; then
			info "gaps安装成功"
			rm -rf $misc_tools_dir/gaps
		else
			error "gaps安装失败,请检查后重试"
			rm -rf $misc_tools_dir/gaps
		fi
	fi
}

function install_misc_dwarf2json() {
	if [ -d "$misc_tools_dir/dwarf2json" ] && [ -f $misc_tools_dir/dwarf2json/dwarf2json ]; then
		info "dwarf2json已安装"
	else
		if command -v go &>/dev/null; then
			go_version=$(go version | awk '{print $3}')
			required_version="go1.18"
			if [[ "$(printf '%s\n' "$required_version" "$go_version" | sort -V | head -n1)" == "$required_version" ]]; then
				info "开始安装 dwarf2json..."
				git clone https://github.com/volatilityfoundation/dwarf2json $misc_tools_dir/dwarf2json
				pushd "$misc_tools_dir/dwarf2json" >/dev/null
				go build
				popd >/dev/bull
				info "dwarf2json安装结束"
			else
				error "dwarf2json安装失败，Go版本过低，请安装Go 1.18或更高版本"
			fi
		else
			info "未检测到go环境，请安装Go 1.18或更高版本"
			install_go
			info "开始安装 dwarf2json..."
			git clone https://github.com/volatilityfoundation/dwarf2json $misc_tools_dir/dwarf2json
			cd $misc_tools_dir/dwarf2json
			go build
			cd -
			info "dwarf2json安装结束"
		fi
	fi
}

# wget
function install_misc_bkcrack() {
	if [ -f ./$misc_tools_dir/bkcrack-1.5.0-Linux/bkcrack ]; then
		info "bkcrack 已经安装"
		return
	fi

	info "开始安装 bkcrack..."
	mkdir -p "$misc_tools_dir"
	if wget https://github.com/kimci86/bkcrack/releases/download/v1.5.0/bkcrack-1.5.0-Linux.tar.gz && tar xf bkcrack-1.5.0-Linux.tar.gz -C $misc_tools_dir/; then
		rm -rf bkcrack-1.5.0-Linux.tar.gz
		if [ -f ./$misc_tools_dir/bkcrack-1.5.0-Linux/bkcrack ]; then
			info "bkcrack 安装完成"
		else
			error "bkcrack 下载完成，但可执行文件未找到，可能压缩包结构已变更"
		fi
	else
		rm -rf bkcrack-1.5.0-Linux.tar.gz
		error "bkcrack 安装失败，请检查网络连接或GitHub访问"
	fi
}

function install_misc_stegosaurus() {
	if command -v stegosaurus &>/dev/null; then
		info "stegosaurus 已经安装"
		return
	fi

	info "开始安装 stegosaurus..."
	if wget https://github.com/AngelKitty/stegosaurus/releases/download/1.0/stegosaurus -O /usr/local/bin/stegosaurus && chmod +x /usr/local/bin/stegosaurus; then
		if command -v stegosaurus &>/dev/null; then
			info "stegosaurus 安装完成"
		else
			error "stegosaurus 安装过程未报错，但命令未找到，可能路径未正确配置"
		fi
	else
		error "stegosaurus 安装失败，请检查网络连接"
	fi
}

# pip
function install_misc_stegpy() {
	if pip3 list | grep "stegpy" &>/dev/null; then
		info "stegpy 已经安装"
		return
	fi

	info "开始安装 stegpy..."
	if pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple stegpy $PIP_BREAK_ARG; then
		if pip3 list | grep "stegpy" &>/dev/null; then
			info "stegpy 安装完成"
		else
			error "stegpy 安装过程未报错，但模块未找到，可能安装失败"
		fi
	else
		error "stegpy 安装失败，请检查网络或pip源配置"
	fi
}

function install_web_reverse-shell-generator() {
	if ! command -v docker &>/dev/null; then
		info "Docker 未安装，开始安装..."
		install_docker
	else
		info "Docker 已安装"
	fi

	if docker images --format "{{.Repository}}" | grep -q "^reverse_shell_generator$"; then
		info "镜像 reverse_shell_generator 已存在，跳过执行"
		return 0
	fi

	if [ ! -f "$web_tools_dir/reverse-shell-generator/Dockerfile" ]; then
		info "克隆 reverse-shell-generator 项目..."
		git clone https://github.com/0dayCTF/reverse-shell-generator.git $web_tools_dir/reverse-shell-generator
		if [ $? -ne 0 ]; then
			error "克隆项目失败"
			return 1
		fi

		cat >"$web_tools_dir/reverse-shell-generator/Dockerfile" <<EOF
FROM nginx:alpine
COPY . /usr/share/nginx/html
EOF
	fi

	info "构建 Docker 镜像 reverse_shell_generator..."
	docker build -t reverse_shell_generator $web_tools_dir/reverse-shell-generator
	if [ $? -ne 0 ]; then
		error "镜像构建失败"
		return 1
	fi

	read -p "[?] 是否启动容器？(y/n): " confirm
	if [[ "$confirm" =~ ^[Yy]$ ]]; then
		read -p "[?] 请输入映射到容器的端口（默认 80）: " port
		port=${port:-80}
		info "启动容器，映射端口 $port ..."
		docker run -d -p "$port":80 reverse_shell_generator
		if [ $? -eq 0 ]; then
			info "容器已启动，访问地址：http://localhost:$port/"
		else
			error "容器启动失败"
		fi
	else
		warn "用户选择不启动容器"
	fi
}

function install_web_neo-regorg() {
	if [ -d "$web_tools_dir/neo-regorg" ] && [ -f "$web_tools_dir/neo-regorg/neoreg.py" ]; then
		info "neo-regorg 已经下载"
		return
	fi

	info "开始下载 neo-regorg..."
	if git clone https://github.com/L-codes/Neo-reGeorg.git $web_tools_dir/neo-regorg; then
		if [ -d "$web_tools_dir/neo-regorg" ] && [ -f "$web_tools_dir/neo-regorg/neoreg.py" ]; then
			info "neo-regorg 下载完成"
		else
			error "neo-regorg 下载完成，但关键文件未找到，可能仓库结构已变更"
		fi
	else
		error "neo-regorg 下载失败，请检查网络连接或GitHub访问"
	fi
}

function install_web_stowaway() {
	local target_dir="$web_tools_dir/stowaway"
	mkdir -p "$target_dir"

	if [ -d "$target_dir" ] && [ -f "$target_dir/linux_x64_admin" ]; then
		info "stowaway 已经下载"
		return
	fi

	info "开始下载 stowaway..."

	local base_url="https://github.com/ph4ntonn/Stowaway/releases/download/v2.2"
	local files=(
		arm_eabi5_agent
		freebsd_arm_admin
		freebsd_arm_agent
		freebsd_x86_admin
		freebsd_x86_agent
		linux_arm64_admin
		linux_arm64_agent
		linux_x64_admin
		linux_x64_agent
		linux_x86_admin
		linux_x86_agent
		macos_arm64_admin
		macos_arm64_agent
		macos_x64_admin
		macos_x64_agent
		mipsel_agent
		windows_x64_admin.exe
		windows_x64_agent.exe
		windows_x86_admin.exe
		windows_x86_agent.exe
	)

	local success=1
	for file in "${files[@]}"; do
		local url="$base_url/$file"
		local dest="$target_dir/$file"

		if curl -L -o "$dest" "$url"; then
			chmod +x "$dest" 2>/dev/null || true
			info "已下载 $file"
		else
			error "下载失败: $file"
			success=0
		fi
	done

	if [ "$success" -eq 1 ] && [ -f "$target_dir/linux_x64_admin" ]; then
		info "stowaway 安装完成"
	else
		error "下载过程中可能存在问题，请检查下载内容"
	fi
}

function install_web_frp() {
	local target_dir="$web_tools_dir/frp"
	mkdir -p "$target_dir"

	if [ -d "$target_dir/current" ]; then
		info "frp 已解压到 $target_dir/current 并准备好使用"
		return
	fi

	info "开始下载 frp..."

	local base_url="https://github.com/fatedier/frp/releases/download/v0.63.0"
	local files=(
		frp_0.63.0_android_arm64.tar.gz
		frp_0.63.0_darwin_amd64.tar.gz
		frp_0.63.0_darwin_arm64.tar.gz
		frp_0.63.0_freebsd_amd64.tar.gz
		frp_0.63.0_linux_amd64.tar.gz
		frp_0.63.0_linux_arm.tar.gz
		frp_0.63.0_linux_arm64.tar.gz
		frp_0.63.0_linux_arm_hf.tar.gz
		frp_0.63.0_linux_loong64.tar.gz
		frp_0.63.0_linux_mips.tar.gz
		frp_0.63.0_linux_mips64.tar.gz
		frp_0.63.0_linux_mips64le.tar.gz
		frp_0.63.0_linux_mipsle.tar.gz
		frp_0.63.0_linux_riscv64.tar.gz
		frp_0.63.0_openbsd_amd64.tar.gz
		frp_0.63.0_windows_amd64.zip
		frp_0.63.0_windows_arm64.zip
		frp_sha256_checksums.txt
	)

	local success=1
	for file in "${files[@]}"; do
		local url="$base_url/$file"
		local dest="$target_dir/$file"

		if [ ! -f "$dest" ]; then
			if curl -L -o "$dest" "$url"; then
				info "已下载 $file"
			else
				error "下载失败: $file"
				success=0
			fi
		else
			info "$file 已存在，跳过下载"
		fi
	done

	if [ "$success" -ne 1 ]; then
		error "下载过程中可能存在问题，请检查下载内容"
		return
	fi

	# 自动识别平台并解压
	local uname_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local uname_arch="$(uname -m)"

	case "$uname_arch" in
	x86_64) arch="amd64" ;;
	aarch64 | arm64) arch="arm64" ;;
	armv7l) arch="arm" ;;
	armv6l) arch="arm" ;;
	loongarch64) arch="loong64" ;;
	riscv64) arch="riscv64" ;;
	mips64) arch="mips64" ;;
	mips64el) arch="mips64le" ;;
	mipsel) arch="mipsle" ;;
	mips) arch="mips" ;;
	i386 | i686) arch="386" ;;
	*) arch="unknown" ;;
	esac

	local match=""
	for file in "${files[@]}"; do
		if [[ "$file" == *"${uname_os}_${arch}"* ]]; then
			match="$file"
			break
		fi
	done

	if [ -z "$match" ]; then
		error "未找到适用于当前系统 ($uname_os $arch) 的 frp 包"
		return
	fi

	info "开始解压 $match"

	mkdir -p "$target_dir/current"
	if [[ "$match" == *.tar.gz ]]; then
		tar -xzf "$target_dir/$match" -C "$target_dir/current" --strip-components=1
	elif [[ "$match" == *.zip ]]; then
		unzip -o "$target_dir/$match" -d "$target_dir/current"
	else
		error "不支持的文件格式: $match"
		return
	fi

	info "frp 安装完成，已解压到 $target_dir/current"
}

function usage() {
	echo "usage: ./auto_deploy.sh [mode]"
	echo "		base				基础配置"
	echo "		docker				安装docker"
	echo "		docker-compose			安装docker-compose"
	echo "		go				安装golang"
	echo "		java				安装java"
	echo "		misctools			安装misc工具"
	echo "		pwntools			安装pwn工具"
	echo "		webtools			安装web工具"
	echo
	echo "示例: ./auto_deploy.sh base docker"
}

function main() {
	[ $(id -u) != "0" ] && {
		error "请用root用户运行"
		exit 1
	}

	[[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]] && {
		usage
		return
	}

	read -p "警告，该脚本可能会对您的系统进行某些更改和删除操作，继续运行吗？默认为：yes. Enter [yes/no]：" is_is
	if [[ $is_is == "no" || $is_is == "NO" ]]; then
		info "取消安装"
		exit 0
	fi

	for i in "$@"; do
		case $i in
		base) install_basics ;;
		docker) install_docker ;;
		docker-compose) install_docker-compose ;;
		go) install_go ;;
		java) install_java ;;
		misctools) install_ctf_misc_tools ;;
		pwntools) install_ctf_pwn_tools ;;
		webtools) install_ctf_web_tools ;;
		*) info "没有这个参数^_^" ;;
		esac
	done
}

main "$@"
