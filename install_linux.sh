echo "请输入您的密码以提升权限："
sudo -v

echo "正在拉取最新版本的仓库..."
cd /tmp
rm -rf LiteLoader
git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader

# 移动到安装目录
echo "拉取完成，正在安装LiteLoader..."
sudo cp -f LiteLoader/src/preload.js /opt/QQ/resources/app/application/preload.js
# 如果目标目录存在且不为空，则先备份处理
if [ -e "/opt/QQ/resources/app/LiteLoader" ]; then
    # 删除上次的备份
    rm -rf "/opt/QQ/resources/app/LiteLoader_bak"

    # 将已存在的目录重命名为LiteLoader_bak
    mv "/opt/QQ/resources/app/LiteLoader" "/opt/QQ/resources/app/LiteLoader_bak"
    echo "已将原LiteLoader目录备份为LiteLoader_bak"
fi
# 移动LiteLoader
sudo mv -f LiteLoader /opt/QQ/resources/app

# 如果LiteLoader_bak中存在plugins和data文件夹，则复制到新的LiteLoader目录
if [ -d "/opt/QQ/resources/app/LiteLoader_bak/data" ]; then
    sudo cp -r "/opt/QQ/resources/app/LiteLoader_bak/plugins" "/opt/QQ/resources/app/LiteLoader/"
    sudo cp -r "/opt/QQ/resources/app/LiteLoader_bak/data" "/opt/QQ/resources/app/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧数据复制到新的 LiteLoader 目录"
fi

read -p "是否通过环境变量修改插件目录 (y/N): " modify_env_choice
    if [ "$modify_env_choice" = "y" ] || [ "$modify_env_choice" = "Y" ]; then
    # 自定义插件，默认为~/.config/LiteLoader-Plugins
    read -p "请输入LiteLoader插件目录（默认为$HOME/.config/LiteLoader-Plugins）: " custompluginsDir
    pluginsDir=${custompluginsDir:-"$HOME/.config/LiteLoader-Plugins"}
    echo "插件目录: $pluginsDir"

    # 检测当前 shell 类型
    if [ -n "$ZSH_VERSION" ]; then
        # 当前 shell 为 Zsh
        config_file="$HOME/.zshrc"
    else
        config_file="$HOME/.bashrc"
    fi

    # 检查是否已存在LITELOADERQQNT_PROFILE
    if grep -q "export LITELOADERQQNT_PROFILE=" "$config_file"; then
        read -p "LITELOADERQQNT_PROFILE 已存在，是否要修改？ (y/n): " modify_choice
        if [ "$modify_choice" = "y" ] || [ "$modify_choice" = "Y" ]; then
            # 如果用户同意修改，则替换原有的行
            sed -i '' 's|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE="'$pluginsDir'"|' "$config_file"
            echo "LITELOADERQQNT_PROFILE 已修改为: $pluginsDir"
        else
            echo "未修改 LITELOADERQQNT_PROFILE。"
        fi
    else
        # 如果不存在，则添加新的行
        echo 'export LITELOADERQQNT_PROFILE="'$pluginsDir'"' >> "$config_file"
        echo "已添加 LITELOADERQQNT_PROFILE: $pluginsDir"
    fi
fi



# 进入安装目录
cd /opt/QQ/resources/app/app_launcher

# 修改index.json
echo "正在修补index.json..."

# 检查是否已存在相同的修改
if grep -q "require('/opt/QQ/resources/app/LiteLoader');" index.js; then
    echo "index.json 已包含相同的修改，无需再次修改。"
else
    # 如果不存在，则进行修改
    sudo sed -i '' "1i\\
require('/opt/QQ/resources/app/LiteLoader');\
" index.js
    echo "已修补 index.json。"
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
