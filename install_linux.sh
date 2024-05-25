#!/bin/bash
# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：禁止以 root 用户执行此脚本。"
    echo "请使用普通用户执行"
    exit 1
fi

_reproxy_url=${REPROXY_URL:-"https://mirror.ghproxy.com/"}
if [ ${_reproxy_url: -1} != "/" ]; then
    _reproxy_url="$REPROXY_URL""/"
fi

# 检查网络连接选择镜像站
function can_connect_to_internet() {
    if [ `curl -sL --max-time 3 "https://github.com" | wc -c` > 0 ]; then
        echo "0"
        return 
    fi
    if [ `curl -sL --max-time 3 "$_reproxy_url""https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest/download/install_linux.sh" | wc -c` > 0 ]; then
        echo "1"
        return
    fi
    echo "2"
    return
}

function download_and_extract() {
    url=$1
    output_dir=$2
    archive_name=$(basename "$url")
    archive_extension="${archive_name##*.}"

    if command -v wget > /dev/null; then
        wget "$url" -O "$archive_name"
    elif command -v curl > /dev/null; then
        curl -L "$url" -o "$archive_name"
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


if [ -f /usr/bin/pacman ]; then
    # AUR 中的代码本身就需要对 GitHub 进行访问，故不添加网络判断了
    if grep -q "Arch Linux" /etc/os-release; then
        echo "检测到系统是 Arch Linux"
        echo "3 秒后将使用 aur 中的 liteloader-qqnt-bin 进行安装"
        echo "或按任意键切换传统安装方式"
        read -r -t 3 -n 1 response
        # Check if user input is empty (no input within 3 seconds)
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

if [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "Detected GitHub Actions environment. Setting default values for non-interactive mode."
    pluginsDir="/opt/LiteLoader/plugins"
else
    # 如果不在 GitHub Actions 环境中，继续使用用户输入
    echo "请输入您的密码以提升权限："
    sudo -v

    read -p "是否通过环境变量修改插件目录 (y/N): " modify_env_choice

    if [ "$modify_env_choice" = "y" ] || [ "$modify_env_choice" = "Y" ]; then
        read -p "请输入LiteLoader插件目录（默认为$HOME/.config/LiteLoader-Plugins）: " custompluginsDir
        pluginsDir=${custompluginsDir:-"$HOME/.config/LiteLoader-Plugins"}
        echo "插件目录: $pluginsDir"

        # 检测当前 shell 类型
        if [ "${SHELL##*/}" = "zsh" ]; then
            config_file="$HOME/.zshrc"
        elif [ "${SHELL##*/}" = "bash" ]; then
            config_file="$HOME/.bashrc"
        else
            echo "非bash或者zsh，跳过修改环境变量"
            echo "请将用户目录下 .bashrc 文件内 LL 相关内容自行拷贝到相应配置文件中"
            config_file="$HOME/.bashrc"
        fi

        # 检查是否已存在LITELOADERQQNT_PROFILE
        if grep -q "export LITELOADERQQNT_PROFILE=" "$config_file"; then
            read -p "LITELOADERQQNT_PROFILE 已存在，是否要修改？ (y/N): " modify_choice
            if [ "$modify_choice" = "y" ] || [ "$modify_choice" = "Y" ]; then
                # 如果用户同意修改，则替换原有的行
                sudo sed -i 's|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE="'$pluginsDir'"|' "$config_file"
                echo "LITELOADERQQNT_PROFILE 已修改为: $pluginsDir"
            else
                echo "未修改 LITELOADERQQNT_PROFILE。"
            fi
        else
            # 如果不存在，则添加新的行
            echo 'export LITELOADERQQNT_PROFILE="'$pluginsDir'"' >> "$config_file"
            echo "已添加 LITELOADERQQNT_PROFILE: $pluginsDir"
        fi
        source $config_file
    else
        pluginsDir='/opt/LiteLoader/plugins'
    fi

fi

cd /tmp
rm -rf LiteLoader

git_cmd=$(command -v git)
# 判断网络连接
case $(can_connect_to_internet) in
    0)
        echo "正在拉取最新版本的Github仓库"
        if [ -n "$git_cmd" ]; then
            git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader
        else
            download_and_extract https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/archive/refs/heads/main.tar.gz LiteLoader
        fi
    ;;
    1)
        echo "正在拉取最新版本的Github仓库"
        if [ -n "$git_cmd" ]; then
            git clone "${_reproxy_url}https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git" LiteLoader
        else
            download_and_extract "${_reproxy_url}https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/archive/refs/heads/main.tar.gz" LiteLoader
        fi
    ;;
    2)
        echo "正在拉取最新版本的GitLink仓库"
        if [ -n "$git_cmd" ]; then
            git clone https://gitlink.org.cn/shenmo7192/LiteLoaderQQNT.git LiteLoader
        else
            download_and_extract https://gitlink.org.cn/shenmo7192/LiteLoaderQQNT/archive/main.tar.gz LiteLoader
        fi
    ;;
    *)
        echo "出现错误，请截图"
    ;;
esac


# 移动到安装目录
echo "拉取完成，正在安装LiteLoader..."
sudo cp -f LiteLoader/src/preload.js /opt/QQ/resources/app/application/preload.js

# 如果目标目录存在且不为空，则先备份处理
if [ -e "/opt/LiteLoader" ]; then
    # 删除上次的备份
    sudo rm -rf "/opt/LiteLoader_bak"

    # 将已存在的目录重命名为LiteLoader_bak
    sudo mv "/opt/LiteLoader" "/opt/LiteLoader_bak"
    echo "已将原LiteLoader目录备份为LiteLoader_bak"
fi

# 移动LiteLoader
sudo mv -f LiteLoader /opt

# 如果LiteLoader_bak中存在plugins文件夹，则复制到新的LiteLoader目录
if [ -d "/opt/LiteLoader_bak/plugins" ]; then
    sudo cp -r "/opt/LiteLoader_bak/plugins" "/opt/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧数据复制到新的 LiteLoader 目录"
fi

# 如果LiteLoader_bak中存在data文件夹，则复制到新的LiteLoader目录
if [ -d "/opt/LiteLoader_bak/data" ]; then
    sudo cp -r "/opt/LiteLoader_bak/data" "/opt/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧数据复制到新的 LiteLoader 目录"
fi

# 进入安装目录
cd /opt/QQ/resources/app/app_launcher

# 修改index.js
echo "正在修补index.js..."

# 检查是否已存在相同的修改
if grep -q "require('/opt/LiteLoader');" index.js; then
    echo "index.js 已包含相同的修改，无需再次修改。"
else
    # 如果不存在，则进行修改
    sudo sed -i '' -e "1i\\
require('/opt/LiteLoader');\
    " -e '$a\' index.js
    echo "已修补 index.js。"
fi

response=$(curl -s https://api.github.com/repos/ltxhhz/LL-plugin-list-viewer/releases/latest)
version=$(echo "$response" | grep 'tag_name' | cut -d'"' -f4 )
download_url=https://github.com/ltxhhz/LL-plugin-list-viewer/releases/download/$version/list-viewer.zip

echo "修改LiteLoader文件夹权限(可能解决部分错误)"
sudo chmod -R 0777 /opt/LiteLoader

pluginStoreFolder="$pluginsDir/list-viewer"

if [ -e "$pluginsDir" ]; then
   if [ -e "$pluginStoreFolder" ]; then
       echo "插件列表查看已存在"
   else
       echo "正在拉取最新版本的插件列表查看..."
       cd "$pluginsDir" || exit 1
       # 判断网络连接
       if can_connect_to_internet; then
           echo "正在拉取最新版本的Github仓库"
           download_and_extract "${download_url}" list-viewer
       else
           echo "正在拉取最新版本镜像仓库"
           download_and_extract "${_reproxy_url}${download_url}" list-viewer
       fi
       if [ $? -eq 0 ]; then
           echo "插件商店安装成功"
       else
           echo "插件商店安装失败"
       fi
   fi
else
   mkdir -p "$pluginsDir"
   echo "正在拉取最新版本的插件列表查看..."
   cd "$pluginsDir" || exit 1
       if can_connect_to_internet; then
           echo "正在拉取最新版本的Github仓库"
        download_and_extract "${download_url}" list-viewer
    else
        echo "正在拉取最新版本镜像仓库"
        download_and_extract "${_reproxy_url}${download_url}" list-viewer
    fi
   if [ $? -eq 0 ]; then
       echo "插件商店安装成功"
   else
       echo "插件商店安装失败"
   fi
fi



echo "脚本将在3秒后退出..."

# 清理临时文件
rm -rf /tmp/LiteLoader

# 错误处理
if [ $? -ne 0 ]; then
    echo "发生错误，安装失败"
    exit 1
fi

# 等待3秒后退出
sleep 3
exit 0
