#!/bin/bash

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


# 提升权限
echo "请输入您的密码以提升权限："
sudo -v

# 拉取最新版本的仓库
echo "正在拉取最新版本的仓库..."
cd /tmp || { echo "无法进入 /tmp 目录"; exit 1; }
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
        exit 1
    ;;
esac

# 安装 LiteLoader
echo "拉取完成，正在安装 LiteLoader..."
sudo cp -f LiteLoader/src/preload.js /Applications/QQ.app/Contents/Resources/app/application/preload.js

# 处理 LiteLoader 目录
if [ -e "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader" ]; then
    # 删除上次的备份
    rm -rf "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak"

    # 备份已存在的目录
    mv "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader" "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak"
    echo "已将原 LiteLoader 目录备份为 LiteLoader_bak"
fi

# 移动 LiteLoader
mv -f LiteLoader "$HOME/Library/Containers/com.tencent.qq/Data/Documents/"

# 恢复插件和数据
if [ -d "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/plugins" ]; then
    echo "正在恢复插件数据..."
    echo "PS:由于macOS限制，对Sandbox目录操作预计耗时数分钟左右"
    cp -r "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/plugins" "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/"
    echo "已将 LiteLoader_bak 中的旧插件复制到新的 LiteLoader 目录"
fi

if [ -d "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/data" ]; then
    echo "正在恢复数据文件..."
    cp -r "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/data" "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/"
    echo "已将 LiteLoader_bak 中的数据文件复制到新的 LiteLoader 目录"
fi

# 是否为插件目录创建软连接
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

# 进入安装目录
cd /Applications/QQ.app/Contents/Resources/app/app_launcher || { echo "无法进入安装目录"; exit 1; }

# 修改 index.js
echo "正在修补 index.js..."

# 检查是否已存在相同的修改
if grep -q "require('$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader');" index.js; then
    echo "index.js 已包含相同的修改，无需再次修改。"
else
    # 如果不存在，则进行修改
    sudo sed -i '' -e "1i\\
require('$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader');\
" -e '$a\' index.js
    echo "已修补 index.js。"
fi

targetFolder="$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/plugins"
pluginStoreFolder="$targetFolder/list-viewer"
response=$(curl -s https://api.github.com/repos/ltxhhz/LL-plugin-list-viewer/releases/latest)
version=$(echo "$response" | grep 'tag_name' | cut -d'"' -f4 )
download_url=https://github.com/ltxhhz/LL-plugin-list-viewer/releases/download/$version/list-viewer.zip

if [ -e "$targetFolder" ]; then
    if [ -e "$pluginStoreFolder" ]; then
        echo "插件列表查看已存在"
    else
        echo "正在拉取最新版本的插件列表查看..."
        if [ "$(can_connect_to_internet)" -eq 0 ]; then
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
    mkdir -p "$targetFolder"
    echo "正在拉取最新版本的插件列表查看..."
    cd "$targetFolder" || exit 1
    if [ "$(can_connect_to_internet)" -eq 0 ]; then
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

# 清理临时文件
rm -rf /tmp/LiteLoader

# 错误处理
if [ $? -ne 0 ]; then
    echo "发生错误，安装失败"
    exit 1
fi

# 等待3秒后退出
echo "脚本将在 3 秒后退出..."
sleep 3
exit 0
