# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：禁止以 root 用户执行此脚本。"
    echo "请使用普通用户执行"
    exit 1
fi

if [ "$GITHUB_ACTIONS" == "true" ]; then
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
        if [ -n "$ZSH_VERSION" ] || [ "$(ps -p $$ -o comm=)" = "zsh" ]; then
            # 当前 shell 为 Zsh
            config_file="$HOME/.zshrc"
        else
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

echo "正在拉取最新版本的仓库..."
cd /tmp
rm -rf LiteLoader
git clone https://github.com/LiteLoaderQQNT/LiteLoaderQQNT.git LiteLoader

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
    sudo cp "/opt/LiteLoader_bak/config.json" "/opt/LiteLoader/"
    echo "已将 LiteLoader_bak 中旧 config.json 复制到新的 LiteLoader 目录"
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

pluginStoreFolder="$pluginsDir/pluginStore"

if [ -e "$pluginsDir" ]; then
    if [ -e "$pluginsDir/LiteLoaderQQNT-Plugin-Plugin-Store/" ] || [ -e "$pluginStoreFolder" ]; then
        echo "插件商店已存在"
    else
        echo "正在拉取最新版本的插件商店..."
        cd "$pluginsDir" || exit 1
        git clone https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store pluginStore
        if [ $? -eq 0 ]; then
            echo "插件商店安装成功"
        else
            echo "插件商店安装失败"
        fi
    fi
else
    sudo mkdir -p "$pluginsDir"
    echo "正在拉取最新版本的插件商店..."
    cd "$pluginsDir" || exit 1
    sudo git clone https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store pluginStore
    if [ $? -eq 0 ]; then
        echo "插件商店安装成功"
    else
        echo "插件商店安装失败"
    fi
fi

sudo chmod -R 0777 /opt/LiteLoader

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
