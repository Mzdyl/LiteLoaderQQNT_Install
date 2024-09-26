#!/bin/bash

# 修补 index.js 的函数，创建 *.js 文件，并修改 package.json
function patch_index_js() {
    local path=$1
    local file_name="ml_install.js"  # 这里的文件名可以随意设置
    
    echo "正在创建 $path/$file_name..."
    
    # 写入 require(String.raw`*`) 到 *.js 文件
    echo 'require("./LiteLoader");' > "$path/$file_name"
    echo "已创建 $path/$file_name，内容为 require("./LiteLoader")"
    
    # 检查 package.json 文件是否存在
    local package_json="$path/../package.json"
    if [ -f "$package_json" ]; then
        echo "正在修改 $package_json 的 main 字段..."
        
        # 修改 package.json 中的 main 字段为 ./app_launcher/launcher.js
        $sudo_cmd sed -i 's|"main":.*|"main": "./app_launcher/'"$file_name"'",|' "$package_json"
        echo "已将 $package_json 中的 main 字段修改为 ./app_launcher/$file_name"
    else
        echo "未找到 $path/../package.json，跳过修改"
    fi
}

if [ $# -eq 0 ]; then
    echo "未提供 QQ.AppImage 文件的路径，默认使用当前目录下的 QQ.AppImage"
    appimage_path="$PWD/QQ.AppImage"
else
    appimage_path="$1"
fi

qq_path=$(dirname "$appimage_path")

if [ -f "$appimage_path" ]; then
    echo "当前 QQ.AppImage 路径: $appimage_path"
    cp "$appimage_path" QQ.AppImage.bak
    chmod +x "$appimage_path"
else
    echo "未找到指定的 QQ.AppImage 文件"
    exit 1
fi
echo "处理原AppImage"
chmod +x $appimage_path
$appimage_path --appimage-extract >/dev/null
rm "$appimage_path"

cd $qq_path/squashfs-root
target_dir="$qq_path/squashfs-root"
install_dir="$target_dir/resources/app/app_launcher"
config_file="$target_dir/AppRun"
plugin_dir="\$HOME/.config/QQ/LiteLoader"
echo "当前target_dir:$target_dir"

# 检查是否已存在LITELOADERQQNT_PROFILE
if grep -q "export LITELOADERQQNT_PROFILE=" "$config_file"; then
    sed -i 's|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE="'$plugin_dir'"|' "$config_file"
else
    # 如果不存在，则添加新的行
    echo 'export LITELOADERQQNT_PROFILE="'$plugin_dir'"' >> "$config_file"
    echo "已添加 LITELOADERQQNT_PROFILE: $plugin_dir"
fi

cd /tmp
echo "正在拉取最新版本的仓库..."
rm -rf LiteLoader
git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader

# 移动到安装目录
echo "拉取完成，正在安装LiteLoader..."

# 移动LiteLoader
mv -f LiteLoader "$install_dir/LiteLoader"

# 修改index.js
echo "正在修补index.js... $install_dir"

patch_index_js "$install_dir"


chmod -R 0777 $install_dir

cd "$target_dir/.."
echo "正在重打包"
mksquashfs squashfs-root tmp.squashfs -root-owned -noappend >/dev/null
cat runtime-x86_64 >> QQ.AppImage
cat tmp.squashfs >> QQ.AppImage
chmod a+x QQ.AppImage
echo "注意，插件与配置文件将放在 $plugin_dir"

echo "清理临时文件"
# 清理临时文件
rm -rf /tmp/LiteLoader
rm -rf tmp.squashfs
rm -r $target_dir

# 错误处理.
if [ $? -ne 0 ]; then
    echo "发生错误，安装失败"
    exit 1
fi

exit 0
