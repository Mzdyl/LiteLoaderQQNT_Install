#!/bin/bash

os_arch=${ARCH:=$(uname -m)}

[ "$os_arch" = "x86_64" ] && _arch="$os_arch" || _arch="aarch64"
runtime_url="https://github.com/AppImage/AppImageKit/releases/download/13/runtime-$_arch"

liteloaderqqnt_check_url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest"
liteloaderqqnt_version=$(basename "$(wget --spider "$liteloaderqqnt_check_url" 2>&1 | grep -m1 -o 'https://.*releases/tag[^ ]*')")
liteloaderqqnt_url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest/download/LiteLoaderQQNT.zip"
echo "最新 LiteLoaderQQNT 版本：$liteloaderqqnt_version"

workdir="$PWD"

# 创建临时目录
temp_dir=$(mktemp -d)
echo "临时目录创建成功: $temp_dir"
cd "$temp_dir" || exit 1

cleanup() {
    echo "清理临时目录: $temp_dir"
    rm -rf "$temp_dir"
}

trap cleanup EXIT


# 修补 resources，创建 *.js 文件，并修改 package.json
function patch_resources() {
    local app_path=$1
    local jsfile_name="ml_install.js"  # 这里的文件名可以随意设置
    local jsfile_path="$app_path/app_launcher/$jsfile_name"
    
    # 写入 require(String.raw`*`) 到 *.js 文件
    echo "正在将 'require(\"./LiteLoader\");' 写入 $jsfile_path"
    echo 'require("./LiteLoader");' > "$jsfile_path"
    echo "写入成功"
    
    # 检查 package.json 文件是否存在
    local package_json="$app_path/package.json"
    if [ -f "$package_json" ]; then
        # 修改 package.json 中的 main 字段为 ./app_launcher/launcher.js
        echo "正在修改 $package_json 的 main 字段为 './app_launcher/$jsfile_name'"
        sed -i 's|"main":.*|"main": "./app_launcher/'"$jsfile_name"'",|' "$package_json"
        echo "修改成功"
    else
        echo "未找到 $package_json，跳过修改"
    fi
}

# 获取qq appimage 最新链接
function get_qqnt_appimage_url() {
    [ "$os_arch" != "x86_64" ] && os_arch="arm64"
    check_url="$(curl -s https://im.qq.com/linuxqq/index.shtml| grep -o 'https://.*linuxQQDownload.js?[^"]*')"
    appimage_url=$(curl -s "$check_url" | grep -o 'https://[^,]*AppImage' | grep "$os_arch")

    [ -z "$appimage_url" ] && { echo "获取qq下载链接失败"; exit 1; }
    echo "$appimage_url"
}

function download_url() {
    local url=$1
    local output=$2
    echo "开始下载 $output: $url"
    if wget -q "$url" -O "$output"; then
        echo "下载成功：$output"
    else
        echo "下载失败：$url" && exit 1
    fi
}

# 修改 AppRun 文件以定义配置路径
function patch_appiamge_apprun() {
    target_dir="$1"
    apprun_file="$target_dir/AppRun"
    profile_dir="\$HOME/.config/QQ/LiteLoader"
    echo "当前target_dir:$target_dir"

    # 检查是否已存在LITELOADERQQNT_PROFILE
    if grep -q "export LITELOADERQQNT_PROFILE=" "$apprun_file"; then
        sed -i "s|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE=\${LITELOADERQQNT_PROFILE:=$profile_dir}|" "$apprun_file"
    else
        # 如果不存在，则添加新的行
        echo "export LITELOADERQQNT_PROFILE=\${LITELOADERQQNT_PROFILE:=$profile_dir}" >> "$apprun_file"
        echo "已添加 LITELOADERQQNT_PROFILE: $profile_dir"
    fi
}

# 重新打包 appimage 文件
function repack_appimage() {
    local appdir="$1"
    local output="$2"
    echo "正在重新打包"
    mksquashfs "$appdir" tmp.squashfs -root-owned -noappend >/dev/null
    cat "$runtime_filename" >> "$output"
    cat "tmp.squashfs" >> "$output"
    rm -rf "tmp.squashfs"
    chmod a+x "$output"
    echo "打包完成：$output"
}

# 修改 appimage 文件
function patch_appiamge() {
    local appimage="$1"
    echo "开始操作 $appimage"
    chmod +x "$appimage"
    $appimage --appimage-extract >/dev/null
    patch_appiamge_apprun "squashfs-root"
    patch_resources "squashfs-root/resources/app"

    install_dir="squashfs-root/resources/app/app_launcher/LiteLoader"
    unzip -q "$liteloaderqqnt_filename" -d "$install_dir"
    # chmod -R 0777 "$install_dir"
    repack_appimage "squashfs-root" "$new_qq_filename"
    rm -rf "squashfs-root"
}

# 使用指定 appimage 或从网络获取
qq_url=$(get_qqnt_appimage_url)
if [ $# -eq 0 ]; then
    echo "未提供 QQ.AppImage 文件的路径，默认从官网下载最新版"
    qq_filename=$(basename "$qq_url")
    download_url "$qq_url" "$qq_filename"
    appimage_path=$(realpath "$qq_filename")
else
    qq_filename=$(basename "$1")
    appimage_path="$(cd "$workdir" || exit; realpath "$1")"
fi

new_qq_filename=${qq_filename//.AppImage/_patch-${liteloaderqqnt_version}.AppImage}
runtime_filename=$(basename "$runtime_url")
liteloaderqqnt_filename=$(basename "$liteloaderqqnt_url")

download_url "$runtime_url" "$runtime_filename"
download_url "$liteloaderqqnt_url" "$liteloaderqqnt_filename"

patch_appiamge "$appimage_path"
cp "$new_qq_filename" "$workdir"
