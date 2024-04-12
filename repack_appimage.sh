
echo "标记可执行"
chmod +x QQ.AppImage
echo "自解压"
./QQ.AppImage --appimage-extract >/dev/null
cd squashfs-root
target_dir=$PWD
install_dir="$target_dir/resources/app/app_launcher"
config_file="$target_dir/AppRun"
echo "当前关键变量 target_dir:$target_dir"

# 检查是否已存在LITELOADERQQNT_PROFILE
if grep -q "export LITELOADERQQNT_PROFILE=" "$config_file"; then
    sed -i 's|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE="'$install_dir/LiteLoader/plugins'"|' "$config_file"
else
    # 如果不存在，则添加新的行
    echo 'export LITELOADERQQNT_PROFILE="'$install_dir/LiteLoader/plugins'"' >> "$config_file"
    echo "已添加 LITELOADERQQNT_PROFILE: $install_dir/LiteLoader/plugins"
fi

echo "正在拉取最新版本的仓库..."
cd /tmp
rm -rf LiteLoader
git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader

# 移动到安装目录
echo "拉取完成，正在安装LiteLoader..."
cp -f LiteLoader/src/preload.js $target_dir/resources/app/application/preload.js

tmp_bak_dir="/tmp/LiteLoader_bak"
# 如果目标目录存在且不为空，则先备份处理
if [ -e "$install_dir/LiteLoader" ]; then
    # 删除上次的备份
    rm -rf "$tmp_bak_dir"

    # 将已存在的目录重命名为LiteLoader_bak
    mv "$install_dir/LiteLoader" $tmp_bak_dir
    echo "已将原LiteLoader目录暂时移动为LiteLoader_bak"
fi

# 移动LiteLoader
mv -f LiteLoader "$install_dir/LiteLoader"

# 如果LiteLoader_bak中存在plugins文件夹，则复制到新的LiteLoader目录
if [ -d "$tmp_bak_dir/plugins" ]; then
    cp -r "$tmp_bak_dir/plugins" "$install_dir/LiteLoader/plugins"
    echo "已将 LiteLoader_bak 中旧数据复制到新的 LiteLoader 目录"
    cp "$tmp_bak_dir/config.json" "$install_dir/LiteLoader/plugins"
    echo "已将 LiteLoader_bak 中旧 config.json 复制到新的 LiteLoader 目录"
fi

# 如果LiteLoader_bak中存在data文件夹，则复制到新的LiteLoader目录
if [ -d "$tmp_bak_dir/data" ]; then
    cp -r "$tmp_bak_dir/data" "$install_dir/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧数据复制到新的 LiteLoader 目录"
fi

# 进入安装目录
cd "$install_dir"

# 修改index.js
echo "正在修补index.js...$PWD"

# 检查是否已存在相同的修改
if grep -q "require('./LiteLoader');" index.js; then
    echo "index.js 已包含相同的修改，无需再次修改。"
else
    # 如果不存在，则进行修改
    sed -i '' -e "1i\\
require('./LiteLoader');\
" -e '$a\' index.js
    echo "已修补 index.js。"
fi

chmod -R 0777 $install_dir

cd "$target_dir/.."
./appimagetool-x86_64.AppImage -vgn $target_dir

echo "安装完成！脚本将自动退出..."

# 清理临时文件
rm -rf /tmp/LiteLoader
rm -rf $tmp_bak_dir
if [ "$GITHUB_ACTIONS" == "true" ]; then
    echo "Do not clear $target_dir"
else
    rm -r $target_dir
fi

# 错误处理
if [ $? -ne 0 ]; then
    echo "发生错误，安装失败"
    exit 1
fi

exit 0
