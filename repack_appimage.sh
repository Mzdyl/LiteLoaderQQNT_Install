
echo "标记可执行"
chmod +x QQ.AppImage.old
echo "自解压"
./QQ.AppImage.old --appimage-extract >/dev/null
cd squashfs-root
target_dir=$PWD
install_dir="$target_dir/resources/app/app_launcher"
config_file="$target_dir/AppRun"
plugin_dir="\$HOME/.config/QQ/LiteLoader/plugins"
echo "当前关键变量 target_dir:$target_dir"

# 检查是否已存在LITELOADERQQNT_PROFILE
if grep -q "export LITELOADERQQNT_PROFILE=" "$config_file"; then
    sed -i 's|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE="'$plugin_dir'"|' "$config_file"
else
    # 如果不存在，则添加新的行
    echo 'export LITELOADERQQNT_PROFILE="'$plugin_dir'"' >> "$config_file"
    echo "已添加 LITELOADERQQNT_PROFILE: $plugin_dir"
fi

echo "正在拉取最新版本的仓库..."
cd /tmp
rm -rf LiteLoader
git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader

# 移动到安装目录
echo "拉取完成，正在安装LiteLoader..."
cp -f LiteLoader/src/preload.js $target_dir/resources/app/application/preload.js

# 移动LiteLoader
mv -f LiteLoader "$install_dir/LiteLoader"

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
mksquashfs squashfs-root tmp.squashfs -root-owned -noappend
cat runtime-x86_64 >> QQ.AppImage
cat tmp.squashfs >> QQ.AppImage
chmod a+x QQ.AppImage

echo "安装完成！脚本将自动退出..."

# 清理临时文件
rm -rf /tmp/LiteLoader
rm -rf tmp.squashfs
if [ "$GITHUB_ACTIONS" == "true" ]; then
    echo "Do not clear $target_dir"
else
    rm -r $target_dir
fi

# 错误处理.
if [ $? -ne 0 ]; then
    echo "发生错误，安装失败"
    exit 1
fi

exit 0
