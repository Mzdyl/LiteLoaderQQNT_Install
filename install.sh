#!/bin/bash

# 检查网络连接选择镜像站
function can_connect_to_internet() {
    if [ $(curl -sL --max-time 3 "https://github.com" | wc -c) -gt 0 ]; then
        echo "0"
        return
    fi
    if [ $(curl -sL --max-time 3 "${_reproxy_url}https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest/download/install_mac.sh" | wc -c) -gt 0 ]; then
        echo "1"
        return
    fi
    echo "2"
    return
}

# 下载和解压函数
function download_and_extract() {
    url=$1
    output_dir=$2
    archive_name=$(basename "$url")
    archive_extension="${archive_name##*.}"

    if command -v wget > /dev/null; then
        wget --max-redirect=10 --header="Accept: " "$url" -O "$archive_name"
    elif command -v curl > /dev/null; then
        curl -L -H "Accept: " "$url" -o "$archive_name"
    else
        echo "wget 或 curl 均未安装，无法下载文件."
        exit 1
    fi

    mkdir -p "$output_dir"

    case "$archive_extension" in
        tar.gz)
            tar -zxf "$archive_name" --strip-components=1 -C "$output_dir"
            ;;
        zip)
            if command -v unzip > /dev/null; then
                unzip -q "$archive_name" -d "$output_dir"
            else
                echo "unzip 未安装，无法解压 zip 文件."
                exit 1
            fi
            ;;
        *)
            echo "不支持的文件格式: $archive_extension"
            exit 1
            ;;
    esac

    rm "$archive_name"
}

# 提升权限
function elevate_permissions() {
    echo "请输入您的密码以提升权限："
    sudo -v
}

# 拉取 LiteLoader
function pull_liteloader() {
    echo "正在拉取最新版本的仓库..."
    cd /tmp || { echo "无法进入 /tmp 目录"; exit 1; }
    rm -rf LiteLoader

    git_cmd=$(command -v git)

    echo "正在拉取最新Release版本的仓库"

    case $(can_connect_to_internet) in
        0)
            echo "通过GitHub获取最新Release版本"
            LATEST_RELEASE_URL="https://api.github.com/repos/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest"
            LATEST_RELEASE_INFO=$(curl -s $LATEST_RELEASE_URL)
            LATEST_TAG=$(echo "$LATEST_RELEASE_INFO" | grep -oP '"tag_name": "\K(.*?)(?=")')
            repo_url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git"
            archive_url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/archive/refs/tags/$LATEST_TAG.tar.gz"
            ;;
        1)
            echo "通过GitHub镜像获取最新Release版本"
            LATEST_RELEASE_URL="${_reproxy_url}https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest"
            LATEST_RELEASE_INFO=$(curl -s -o /dev/null -w "%{redirect_url}" "$LATEST_RELEASE_URL")
            LATEST_TAG=$(echo "$LATEST_RELEASE_INFO" | grep -oE "tag/[^/]+" | cut -d'/' -f2)
            repo_url="${_reproxy_url}https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git"
            archive_url="${_reproxy_url}https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/archive/refs/tags/$LATEST_TAG.tar.gz"
            ;;
        2)
            echo "通过GitLink获取最新Release版本"
            TAG_URL="https://gitlink.org.cn/api/shenmo7192/LiteLoaderQQNT/tags.json"
            LATEST_TAG=$(echo $(curl -s $TAG_URL) | grep -oP '"name"\s*:\s*"\K[^"]+' | head -n 1)
            repo_url="https://gitlink.org.cn/shenmo7192/LiteLoaderQQNT.git"
            archive_url="https://www.gitlink.org.cn/api/shenmo7192/liteloaderqqnt/archive/$LATEST_TAG.tar.gz"
            ;;
        *)
            echo "出现错误，请截图"
            exit 1
            ;;
    esac

    if [ -z "$LATEST_TAG" ]; then
        echo "获取最新版本失败，请截图：$LATEST_TAG"
        exit 1
    fi

    if [ -n "$git_cmd" ]; then
        git clone $repo_url LiteLoader -b $LATEST_TAG || { echo "git clone 失败，退出脚本"; exit 1; }
    else
        download_and_extract $archive_url LiteLoader || { echo "下载并解压失败，退出脚本"; exit 1; }
    fi
}

# 安装 LiteLoader
function install_liteloader() {
    echo "拉取完成，正在安装 LiteLoader..."
    if [ "$platform" == "linux" ]; then
        qq_path="/opt/QQ/resources"
        ll_path="/opt"
        sudo_cmd="sudo"
    elif [ "$platform" == "macos" ]; then
        qq_path="Applications/QQ.app/Contents/Resources/"
        ll_path="$HOME/Library/Containers/com.tencent.qq/Data/Documents"
        sudo_cmd=""
    fi

    # 如果目标目录存在且不为空，则先备份处理
    if [ -e "$ll_path/LiteLoader" ]; then
        $sudo_cmd rm -rf "$ll_path/LiteLoader_bak"
        $sudo_cmd mv "$ll_path/LiteLoader" "$ll_path/LiteLoader_bak"
        echo "已将原LiteLoader目录备份为LiteLoader_bak"
    fi

    $sudo_cmd mv -f LiteLoader "$ll_path"

    $sudo_cmd cp -f "$ll_path"/LiteLoader/src/preload.js $qq_path/app/application/preload.js

    # 恢复插件和数据
    if [ -d "$ll_path/LiteLoader_bak/plugins" ]; then
        if [ "$platform" == "Darwin" ]; then
            echo "正在恢复插件数据..."
            echo "PS:由于macOS限制，对Sandbox目录操作预计耗时数分钟左右"
        fi
        $sudo_cmd cp -r "$ll_path/LiteLoader_bak/plugins" "$ll_path/LiteLoader/"
        echo "已将 LiteLoader_bak 中的旧插件复制到新的 LiteLoader 目录"

    fi

    if [ -d "$ll_path/LiteLoader_bak/data" ]; then
        $sudo_cmd cp -r "$ll_path/LiteLoader_bak/data" "$ll_path/LiteLoader/"
        echo "已将 LiteLoader_bak 中的数据文件复制到新的 LiteLoader 目录"
    fi

    cd $qq_path/app/app_launcher || { echo "无法进入安装目录"; exit 1; }
    echo "开始修补 index.js..."
    
    if grep -q "require('$ll_path/LiteLoader');" index.js; then
        echo "index.js 已包含相同的修改，无需再次修改。"
    else
        sudo sed -i '' -e "1i\\
require('$ll_path/LiteLoader');\
" -e '$a\' index.js
    echo "已修补 index.js。"
    fi
}


function install_plugin_store() {
    response=$(curl -s https://api.github.com/repos/ltxhhz/LL-plugin-list-viewer/releases/latest)
    version=$(echo "$response" | grep 'tag_name' | cut -d'"' -f4 )
    download_url=https://github.com/ltxhhz/LL-plugin-list-viewer/releases/download/$version/list-viewer.zip

    if [ "$platform" == "linux" ]; then
        pluginsDir=${LITELOADERQQNT_PROFILE:-/opt/LiteLoader/plugins}
        echo "修改LiteLoader文件夹权限(可能解决部分错误)"
        sudo chmod -R 0777 /opt/LiteLoader
    elif [ "$platform" == "macos" ]; then
        pluginsDir="$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/plugins"
    fi

    pluginStoreFolder="$pluginsDir/list-viewer"

    if [ ! -e "$pluginsDir" ]; then
        mkdir -p "$pluginsDir" || exit 1
    fi
    cd "$pluginsDir" || exit 1

    if [ -e "$pluginStoreFolder" ]; then
        echo "插件列表查看已存在"
    else
        echo "正在拉取最新版本的插件列表查看..."
    fi
    URL="${_reproxy_url}${download_url}"
    if [ $(can_connect_to_internet) -eq 0 ]; then
        URL="${download_url}"
    fi
    download_and_extract "$URL" list-viewer
    if [ $? -eq 0 ]; then
        echo "插件商店安装成功"
    else
        echo "插件商店安装失败"
    fi
}

function modify_plugins_directory() {
    read -p "是否通过环境变量修改插件目录 (y/N): " modify_env_choice
    
    if [[ "$modify_env_choice" =~ ^[Yy]$ ]]; then
        read -p "请输入LiteLoader插件目录（默认为$HOME/.config/LiteLoader-Plugins）: " custompluginsDir
        pluginsDir=${custompluginsDir:-"$HOME/.config/LiteLoader-Plugins"}
        echo "插件目录: $pluginsDir"
        
        # 检测当前 shell 类型
        case "${SHELL##*/}" in
            zsh) config_file="$HOME/.zshrc" ;;
            bash) config_file="$HOME/.bashrc" ;;
            *) echo "非bash或者zsh，跳过修改环境变量"
            echo "请将用户目录下 .bashrc 文件内 LL 相关内容自行拷贝到相应配置文件中"
            config_file="$HOME/.bashrc" ;;
        esac
        
        # 检查是否已存在LITELOADERQQNT_PROFILE
        if grep -q "export LITELOADERQQNT_PROFILE=" "$config_file"; then
            read -p "LITELOADERQQNT_PROFILE 已存在，是否要修改？ (y/N): " modify_choice
            if [[ "$modify_choice" =~ ^[Yy]$ ]]; then
                sudo sed -i 's|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE="'$pluginsDir'"|' "$config_file"
                echo "LITELOADERQQNT_PROFILE 已修改为: $pluginsDir"
            else
                echo "未修改 LITELOADERQQNT_PROFILE。"
            fi
        else
            echo 'export LITELOADERQQNT_PROFILE="'$pluginsDir'"' >> "$config_file"
            echo "已添加 LITELOADERQQNT_PROFILE: $pluginsDir"
        fi
        source "$config_file"
    else
        pluginsDir='/opt/LiteLoader/plugins'
    fi
}

function create_symlink_func() {
    read -p "是否为插件目录创建软连接以方便安装插件 (y/N): " create_symlink
    if [[ "$create_symlink" =~ ^[Yy]$ ]]; then
        read -p "请输入 LiteLoader 插件目录（默认为 $HOME/Downloads/plugins）: " custom_plugins_dir
        plugins_dir=${custom_plugins_dir:-"$HOME/Downloads/plugins"}
        echo "插件目录: $plugins_dir"
        
        # 创建插件目录
        if [ ! -d "$plugins_dir" ]; then
            mkdir -p "$plugins_dir"
            echo "已创建插件目录: $plugins_dir"
        fi
        
        # 创建软连接
        lite_loader_plugins_dir="$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/plugins"
        if [ ! -d "$lite_loader_plugins_dir" ]; then
            mkdir -p "$lite_loader_plugins_dir"
        fi
        
        sudo ln -s "$lite_loader_plugins_dir" "$plugins_dir"
        echo "已为插件目录创建软连接到 $plugins_dir"
    fi
}
    
function aur_install_func() {
    if [ -f /usr/bin/pacman ]; then
        # AUR 中的代码本身就需要对 GitHub 进行访问，故不添加网络判断了
        if grep -q "Arch Linux" /etc/os-release; then
            echo "检测到系统是 Arch Linux"
            echo "3 秒后将使用 aur 中的 liteloader-qqnt-bin 进行安装"
            echo "或按任意键切换传统安装方式"
            read -r -t 3 -n 1 response
            # 检查用户输入是否为空（3 秒内无输入）
            if [[ -z "$response" ]]; then
                echo "开始使用 aur 安装..."
                git clone https://aur.archlinux.org/liteloader-qqnt-bin.git
                cd liteloader-qqnt-bin
                makepkg -si
                rm -rf liteloader-qqnt-bin
                exit 0
            else
                echo "切换使用传统方式安装"
            fi
        fi
    fi
}

# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：禁止以 root 用户执行此脚本。"
    echo "请使用普通用户执行"
    exit 1
fi

# 设置默认的代理 URL
_reproxy_url=${REPROXY_URL:-"https://mirror.ghproxy.com/"}
if [ "${_reproxy_url: -1}" != "/" ]; then
    _reproxy_url="${_reproxy_url}/"
fi

# 检查平台
platform="unknown"
unamestr=$(uname)
if [[ "$unamestr" == "Linux" ]]; then
    platform="linux"
    aur_install_func
elif [[ "$unamestr" == "Darwin" ]]; then
    platform="macos"
fi

elevate_permissions

if [[ "$platform" == "linux" || "$GITHUB_ACTIONS" != "true" ]]; then
    modify_plugins_directory
fi

pull_liteloader

install_liteloader

if [ "$platform" == "macos" ]; then
    create_symlink_func
fi

install_plugin_store

# 清理临时文件
rm -rf /tmp/LiteLoader

# 错误处理
if [ $? -ne 0 ]; then
    echo "发生错误，安装失败"
    exit 1
fi

echo "如果安装过程中没有提示发生错误"
echo "但 QQ 设置界面没有 LiteLoaderQQNT"
echo "请检查已安装过的插件"
echo "插件错误会导致 LiteLoaderQQNT 无法正常启动"

echo "脚本将在 3 秒后退出..."
sleep 3
exit 0
    