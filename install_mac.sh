echo "请输入您的密码以提升权限："
sudo -v

echo "正在拉取最新版本的仓库..."
cd /tmp
rm -rf LiteLoader
git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader

# 移动到安装目录
echo "拉取完成，正在安装LiteLoader..."
sudo cp -f LiteLoader/src/preload.js /Applications/QQ.app/Contents/Resources/app/application/preload.js

# 如果目标目录存在且不为空，则先备份处理
if [ -e "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader" ]; then
    # 删除上次的备份
    rm -rf "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak"

    # 将已存在的目录重命名为LiteLoader_bak
    mv "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader" "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak"
    echo "已将原LiteLoader目录备份为LiteLoader_bak"
fi


# 移动LiteLoader
mv -f LiteLoader $HOME/Library/Containers/com.tencent.qq/Data/Documents/

# 如果LiteLoader_bak中存在plugins文件夹，则复制到新的LiteLoader目录
if [ -d "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/plugins" ]; then
    cp -r "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/plugins" "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧插件Plugins复制到新的 LiteLoader 目录"
fi

# 如果LiteLoader_bak中存在data文件夹，则复制到新的LiteLoader目录
if [ -d "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/data" ]; then
    cp -r "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader_bak/data" "$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧数据文件data复制到新的 LiteLoader 目录"
fi


# 是否为插件目录创建软连接
read -p "是否为插件目录创建软连接方便安装插件 (y/N): " create_symlink
if [ "$create_symlink" = "y" ] || [ "$create_symlink" = "Y" ]; then
    # 自定义插件，默认为~/Downloads/plugins
    read -p "请输入LiteLoader插件目录（默认为$HOME/Downloads/plugins）: " custompluginsDir
    pluginsDir=${custompluginsDir:-"$HOME/Downloads"}
    echo "插件目录: $pluginsDir"

    # 创建pluginsDir目录
    if [ ! -d "$pluginsDir" ]; then
        mkdir -p "$pluginsDir"
        echo "已创建插件目录: $pluginsDir"
    fi

    # 创建软连接
    liteLoaderPluginsDir="$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/plugins"
    if [ ! -d "$liteLoaderPluginsDir" ]; then
        mkdir -p "$liteLoaderPluginsDir"
    fi

    sudo ln -s "$liteLoaderPluginsDir" "$pluginsDir"
    echo "已为插件目录创建软连接到 $pluginsDir"
fi

# 进入安装目录
cd /Applications/QQ.app/Contents/Resources/app/app_launcher

# 修改index.js
echo "正在修补index.js..."

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
pluginStoreFolder="$targetFolder/pluginStore"

if [ -e "$targetFolder" ]; then
    if [ -e "$targetFolder/LiteLoaderQQNT-Plugin-Plugin-Store/" ] || [ -e "$pluginStoreFolder" ]; then
        echo "插件商店已存在"
    else
        echo "正在拉取最新版本的插件商店..."
        cd "$targetFolder" || exit 1
        git clone https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store pluginStore
        if [ $? -eq 0 ]; then
            echo "插件商店安装成功"
        else
            echo "插件商店安装失败"
        fi
    fi
else
    mkdir -p "$targetFolder"
    echo "正在拉取最新版本的插件商店..."
    cd "$targetFolder" || exit 1
    git clone https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store pluginStore
    if [ $? -eq 0 ]; then
        echo "插件商店安装成功"
    else
        echo "插件商店安装失败"
    fi
fi


echo "安装完成！脚本将在3秒后退出..."

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
