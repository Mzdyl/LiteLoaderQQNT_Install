#!/bin/bash

LITELOADERQQNT_URL="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest/download/LiteLoaderQQNT.zip"
PLUGIN_LIST_VIEWER_URL="https://github.com/ltxhhz/LL-plugin-list-viewer/releases/latest/download/list-viewer.zip"

# 创建并切换至临时目录
temp_dir=$(mktemp -d)
echo "临时目录创建成功: $temp_dir"
cd "$temp_dir" || exit 1

cleanup() {
    echo "清理临时目录: $temp_dir"
    rm -rf "$temp_dir"
}
trap cleanup EXIT

# 定义代理 URL 列表
github_download_proxies=(
    "$REPROXY_URL"
    "https://mirror.ghproxy.com"
    "https://gh.h233.eu.org"
    "https://gh.ddlc.top"
    "https://slink.ltd"
    "https://gh.con.sh"
    "https://cors.isteed.cc"
    "https://hub.gitmirror.com"
    "https://sciproxy.com"
    "https://ghproxy.cc"
    "https://cf.ghproxy.cc"
    "https://www.ghproxy.cc"
    "https://ghproxy.cn"
    "https://www.ghproxy.cn"
    "https://gh.jiasu.in"
    "https://dgithub.xyz"
    "https://download.ixnic.net"
    "https://download.nuaa.cf"
    "https://download.scholar.rr.nu"
    "https://download.yzuu.cf"
    "https://ghproxy.net"
    "https://kkgithub.com"
    "https://gitclone.com"
    "https://hub.incept.pw"
    "https://github.moeyy.xyz"
    "https://gh.xiu2.us.kg"
    "https://dl.ghpig.top"
    "https://gh-proxy.com"
    "https://github.site"
    "https://github.store"
    "https://github.tmby.shop"
    "https://hub.whtrys.space"
    "https://gh-proxy.ygxz.in"
    "https://gitdl.cn"
    "https://ghp.ci"
    "https://githubfast.com"
    "https://ghproxy.net"
)

# 检查代理是否有效
function check_proxy() {
    local proxy=$1
    local proxy_url="${proxy}/https://github.com"

    if curl -Isf -m 5 -o /dev/null "$proxy_url"; then
        return 0
    fi
    return 1
}

# 获取有效代理
function get_working_proxy() {
    for proxy in "${github_download_proxies[@]}"; do
        if check_proxy "${proxy%/}"; then
            echo "${proxy%/}"
            return 0
        fi
    done
    return 1
}

# 获取下载 URL
function get_github_download_url() {
    local url=$1
    if curl -Isf -m 5 -o /dev/null "$url"; then
        echo "$url"
        return 0
    fi

    # 只代理 Github 链接
    if [[ "$url" =~ ^(https?:\/\/)?(www\.)?github\.com/ ]]; then
        local proxy
        proxy=$(get_working_proxy)
        if [ -z "$proxy" ]; then
            echo "无可用代理" >&2
            return 1
        fi
        echo "${proxy}/${url}"
        return 0
    fi

    echo "无效的下载链接：$url" >&2
    return 1
}

# 定义检查依赖的函数
function check_dependencies() {
    local missing_dependencies=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -ne 0 ]; then
        echo "缺失的依赖项：${missing_dependencies[*]}"
        echo "请安装上述缺失的依赖项。"
        return 1
    fi
}

function download_url() {
    local url
    url=$(get_github_download_url "$1")
    local output=${2:-$(basename "$url")}
    echo "开始下载 $output: $url"
    if wget -t3 -T3 -q -O "$output" "$url"; then
        echo "下载成功：$output"
    else
        echo "下载失败：$url" && return 1
    fi
}

# 提升权限
function elevate_permissions() {
    echo "请输入您的密码以提升权限："
    sudo -v
}

# 获取 LiteLoaderQQNT 的最新 Gitlink URL
function get_liteloaderqqnt_from_gitlink() { # TODO 考虑移除
    # repo_url="https://gitlink.org.cn/shenmo7192/LiteLoaderQQNT.git"
    TAG_URL="https://gitlink.org.cn/api/shenmo7192/LiteLoaderQQNT/tags.json"
    LATEST_TAG=$(perl -nle 'print $1 if /"name"\s*:\s*"([^"]+)/' <<< "$(curl -s $TAG_URL)" | head -n 1)
    [ -z "$LATEST_TAG" ] && { echo "获取最新版本失败，请截图：$LATEST_TAG"; return 1; }
    echo "https://www.gitlink.org.cn/api/shenmo7192/liteloaderqqnt/archive/$LATEST_TAG.tar.gz"
}

# 拉取 LiteLoader
function pull_liteloader() {
    local url=$LITELOADERQQNT_URL

    echo "正在拉取最新Release版本的仓库"
    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -q "$_name" -d LiteLoader && return 0
    fi

    echo "下载并解压失败，尝试通过 GitLink 获取最新 Release 版本"
    url=$(get_liteloaderqqnt_from_gitlink)
    [ -z "$url" ] && { echo "获取 GitLink 链接失败"; return 1; }
    _name=$(basename "$url")
    if wget -t3 -T3 -q --header="Accept: " -O "$_name" "$url"; then
        tar -zxf "$_name" --strip-components=1 -C LiteLoader && return 0
    fi

    echo "LiteLoaderQQNT 获取失败"
    return 1
}

# 安装 LiteLoader 的函数
function install_liteloader() {
    echo "拉取完成，正在安装 LiteLoader..."
    
    # 设置路径和命令
    if [ "$platform" == "linux" ]; then
        qq_path="/opt/QQ/resources"
        ll_path="/opt"
        sudo_cmd="sudo"
    elif [ "$platform" == "macos" ]; then
        qq_path="/Applications/QQ.app/Contents/Resources"
        ll_path="$HOME/Library/Containers/com.tencent.qq/Data/Documents"
        sudo_cmd=""
    else
        echo "不支持的平台: $platform，退出..."
        return 1
    fi
    
    # 如果目标目录存在且不为空，则先备份处理
    if [ -e "$ll_path/LiteLoader" ]; then
        if ! $sudo_cmd rm -rf "$ll_path/LiteLoader_bak"; then
            echo "备份 LiteLoader 失败，退出..."
            return 1
        fi
        
        if ! $sudo_cmd mv "$ll_path/LiteLoader" "$ll_path/LiteLoader_bak"; then
            echo "移动 LiteLoader 到备份目录失败，退出..."
            return 1
        fi
        echo "已将原 LiteLoader 目录备份为 LiteLoader_bak"
    fi
    
    if ! $sudo_cmd mv -f LiteLoader "$ll_path"; then
        echo "移动 LiteLoader 到目标目录失败，退出..."
        return 1
    fi
    
    # 恢复插件和数据
    if [ -d "$ll_path/LiteLoader_bak/plugins" ]; then
        if [ "$platform" == "macos" ]; then
            echo "正在恢复插件数据..."
            echo "PS:由于 macOS 限制，对 Sandbox 目录操作预计耗时数分钟左右"
        fi
        
        if ! $sudo_cmd rsync -a --info=progress2 "$ll_path/LiteLoader_bak/plugins" "$ll_path/LiteLoader/"; then
            echo "恢复插件数据失败，退出..."
            return 1
        fi
        echo "已将 LiteLoader_bak 中的旧插件复制到新的 LiteLoader 目录"
    fi
    
    if [ -d "$ll_path/LiteLoader_bak/data" ]; then
        if ! $sudo_cmd rsync -a --info=progress2 "$ll_path/LiteLoader_bak/data" "$ll_path/LiteLoader/"; then
            echo "恢复数据文件失败，退出..."
            return 1
        fi
        echo "已将 LiteLoader_bak 中的数据文件复制到新的 LiteLoader 目录"
    fi

    # 修补 resources
    patch_resources "$qq_path/app" "$ll_path/LiteLoader" || return 1
    
    # 针对 macOS 官网版热更新适配
    if [ "$platform" == "macos" ]; then
        echo "正在对 macOS 热更新版本进行补丁"
        versions_path="$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/versions"
        for version_dir in "$versions_path"/*; do
            _dir="$version_dir/QQUpdate.app/Contents/Resources/app"
            [ -d "$_dir" ] && patch_resources "$_dir" "$ll_path/LiteLoader"
        done
    fi
}

# 修补 resources，创建 *.js 文件，并修改 package.json
function patch_resources() {
    local app_path=$1
    local ll_path=${2:-./LiteLoaderQQNT} # LiteLoaderQQNT 路径，默认相对 $app_path
    local jsfile_name="ml_install.js"    # 这里的文件名可以随意设置
    local jsfile_path="$app_path/app_launcher/$jsfile_name"

    [ ! -d "$app_path" ] && { echo "路径无效：$app_path"; return 1; }
    echo "开始处理 $app_path"

    # 写入 require(String.raw`*`) 到 *.js 文件
    echo "正在将 'require(\"${ll_path%/}\");' 写入 app_launcher/$jsfile_name"
    echo "require(\"${ll_path%/}\");" | sudo tee "$jsfile_path" > /dev/null
    echo "写入成功"

    # 检查 package.json 文件是否存在
    local package_json="$app_path/package.json"
    if [ -f "$package_json" ]; then
        # 修改 package.json 中的 main 字段为 ./app_launcher/launcher.js
        echo "正在修改 package.json 的 main 字段为 './app_launcher/$jsfile_name'"

        case "$platform" in
            linux) sed_command=("sudo" sed "-i") ;;
            macos) sed_command=("sudo" sed "-i" "") ;;
            *) echo "Unsupported platform: $platform"; return 1 ;;
        esac

        if "${sed_command[@]}" 's|"main":.*|"main": "./app_launcher/'"$jsfile_name"'",|' "$package_json"; then
            echo "修改成功: $app_path"
            return 0
        fi
        echo "修改失败：$app_path" && return 1
    else
        echo "未找到 package.json ，跳过修改"
        return 1
    fi
}

function install_plugin_store() {
    local url=$PLUGIN_LIST_VIEWER_URL

    if [ "$platform" == "linux" ]; then
        pluginsDir=${LITELOADERQQNT_PROFILE:-/opt/LiteLoader/plugins}
        echo "修改LiteLoader文件夹权限(可能解决部分错误)"
        sudo chmod -R 0777 /opt/LiteLoader
    elif [ "$platform" == "macos" ]; then
        pluginsDir="$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoader/plugins"
    fi

    pluginStoreFolder="$pluginsDir/list-viewer"

    if [ ! -e "$pluginsDir" ]; then
        mkdir -p "$pluginsDir" || return 1
    fi

    if [ -e "$pluginStoreFolder" ]; then
        echo "插件列表查看已存在"
        return 0
    else
        echo "正在拉取最新版本的插件列表查看..."
    fi

    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -q "$_name" -d "$pluginsDir/list-viewer" && { echo "插件商店安装成功"; return 0; }
    fi

    echo "插件商店安装失败"
    return 1
}

function modify_plugins_directory() {
    read -rp "是否通过环境变量修改插件目录 (y/N): " modify_env_choice
    
    if [[ "$modify_env_choice" =~ ^[Yy]$ ]]; then
        read -rp "请输入LiteLoader插件目录（默认为$HOME/.config/LiteLoader-Plugins）: " custompluginsDir
        pluginsDir=${custompluginsDir:-"$HOME/.config/LiteLoader-Plugins"}
        echo "插件目录: $pluginsDir"
        
        # 检测当前 shell 类型
        environment_variables="export LITELOADERQQNT_PROFILE="
        case "${SHELL##*/}" in
            zsh) config_file="$HOME/.zshrc" ;;
            bash) config_file="$HOME/.bashrc" ;;
            fish) environment_variables="set -gx LITELOADERQQNT_PROFILE "
            config_file=$(fish -c 'printf $__fish_config_dir')"/config.fish";;
            *) echo "非bash、zsh、fish，跳过修改环境变量"
            echo "请将用户目录下 .bashrc 文件内 LL 相关内容自行拷贝到相应配置文件中"
            config_file="$HOME/.bashrc" ;;
        esac
        
        # 检查是否已存在LITELOADERQQNT_PROFILE
        if grep -q "$environment_variables" "$config_file"; then
            read -rp "LITELOADERQQNT_PROFILE 已存在，是否要修改？ (y/N): " modify_choice
            if [[ "$modify_choice" =~ ^[Yy]$ ]]; then
                sudo sed -i "s|$environment_variables.*|$environment_variables\"$pluginsDir\"|" "$config_file"
                echo "LITELOADERQQNT_PROFILE 已修改为: $pluginsDir"
            else
                echo "未修改 LITELOADERQQNT_PROFILE。"
            fi
        else
            echo $environment_variables'"'$pluginsDir'"' >> "$config_file"
            echo "已添加 LITELOADERQQNT_PROFILE: $pluginsDir"
        fi
        source "$config_file"
    else
        pluginsDir='/opt/LiteLoader/plugins'
    fi
}

function create_symlink_func() {
    read -rp "是否为插件目录创建软连接以方便安装插件 (y/N): " create_symlink
    if [[ "$create_symlink" =~ ^[Yy]$ ]]; then
        read -rp "请输入 LiteLoader 插件目录（默认为 $HOME/Downloads/plugins）: " custom_plugins_dir
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
        if grep -Eq "Arch Linux|ID_LIKE=\"arch\"" /etc/os-release; then
            echo "检测到系统是 Arch Linux"
            echo "3 秒后将使用 aur 中的 liteloader-qqnt-bin 进行安装"
            echo "或按任意键切换传统安装方式"
            read -r -t 3 -n 1 response
            # 检查用户输入是否为空（3 秒内无输入）
            if [[ -z "$response" ]]; then
                echo "开始使用 aur 安装..."
                if git clone https://aur.archlinux.org/liteloader-qqnt-bin.git; then
                    { cd liteloader-qqnt-bin && makepkg -si; } || return 1
                fi
            else
                echo "切换使用传统方式安装"
            fi
        fi
    fi
}       

function flatpak_qq_func() {
    # 检查 Flatpak 是否安装
    if command -v flatpak &> /dev/null; then        
        # 检查是否安装了 Flatpak 版的 QQ
        if flatpak list --app --columns=application | grep -xq "com.qq.QQ"; then
            echo "检测到 Flatpak 版 QQ 已安装"
            pull_liteloader || return 1
            
            LITELOADER_DIR=$HOME/.config/LiteLoaderQQNT
            LITELOADER_DATA_DIR=$LITELOADER_DIR
            mv -f LiteLoader "$LITELOADER_DIR"
            
            # 提示用户输入自定义的 LITELOADERQQNT_PROFILE 值（如果需要自定义）
            read -rp "是否需要自定义 LiteLoaderQQNT 数据目录? (当前目录: $LITELOADER_DATA_DIR) (y/n): " custom_dir
            if [[ "$custom_dir" == "y" ]]; then
                read -rp "请输入新的 LiteLoaderQQNT 数据目录路径: " user_defined_dir
                LITELOADER_DATA_DIR="$user_defined_dir"
            fi
            
            FLATPAK_QQ_DIR=$(flatpak info --show-location com.qq.QQ)/files/extra/QQ/resources/app
            
            mkdir -p "$LITELOADER_DATA_DIR" # 确保目录存在
            
            # 授予 Flatpak 访问 LiteLoaderQQNT 数据目录的权限
            echo "授予 Flatpak 版 QQ 对数据目录 $LITELOADER_DATA_DIR 和本体目录 $LITELOADER_DIR 的访问权限"
            sudo flatpak override --filesystem="$LITELOADER_DATA_DIR" com.qq.QQ
            sudo flatpak override --filesystem="$LITELOADER_DIR" com.qq.QQ

            # 将 LITELOADERQQNT_PROFILE 作为环境变量传递给 Flatpak 版 QQ
            sudo flatpak override --env=LITELOADERQQNT_PROFILE="$LITELOADER_DATA_DIR" com.qq.QQ
            
            echo "设置完成！LiteLoaderQQNT 数据目录：$LITELOADER_DATA_DIR"
            
            patch_resources "$FLATPAK_QQ_DIR" "$LITELOADER_DIR/LiteLoader" && return 0
            return 1
        fi
    fi
}

dependencies=("wget" "curl" "unzip" "sudo")
check_dependencies || exit 1

# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：禁止以 root 用户执行此脚本。"
    echo "请使用普通用户执行"
    exit 1
fi

# 检查平台
platform="unknown"
unamestr=$(uname)
if [[ "$unamestr" == "Linux" ]]; then
    platform="linux"
    aur_install_func || exit 1
    flatpak_qq_func || exit 1
elif [[ "$unamestr" == "Darwin" ]]; then
    platform="macos"
fi

elevate_permissions

if [[ "$platform" == "linux" && "$GITHUB_ACTIONS" != "true" ]]; then
    modify_plugins_directory
fi

pull_liteloader || exit 1

install_liteloader || exit 1

if [ "$platform" == "macos" ]; then
    create_symlink_func
fi

install_plugin_store || { echo "发生错误，安装失败"; exit 1; }

echo "如果安装过程中没有提示发生错误"
echo "但 QQ 设置界面没有 LiteLoaderQQNT"
echo "请检查已安装过的插件"
echo "插件错误会导致 LiteLoaderQQNT 无法正常启动"

echo "打开QQ后会弹出初始化失败，此为正常现象，请按照说明完成后续操作"

echo "脚本将在 3 秒后退出..."
sleep 3
