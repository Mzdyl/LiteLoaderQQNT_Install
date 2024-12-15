#!/bin/bash

readonly LITELOADERQQNT_URL="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest/download/LiteLoaderQQNT.zip"
readonly PLUGIN_LIST_VIEWER_URL="https://github.com/ltxhhz/LL-plugin-list-viewer/releases/latest/download/list-viewer.zip"

readonly WORKDIR="$PWD"

cleanup() {
    [ -d "$temp_dir" ] && {
        echo "清理临时目录: $temp_dir"
        rm -rf "$temp_dir"
    }
}
trap cleanup EXIT

# 显示帮助信息的函数
function show_help() {
    cat << EOF
Usage: $0 [options]...

Options:
  --appimage[=<path>]     操作 AppImage，未指定路径时自动从官网下载
  --ll-dir <options|path>         指定 LiteLoaderQQNT 本体存放路径，可选值
                            - 'xdg' 默认，位于 '\$HOME/.local/share/LiteLoaderQQNT'
                            - 'qq' 位于 qq 安装目录的 app 文件夹内
                            - 'opt' 位于 /opt/LiteLoaderQQNT
                            - 其他值则为相对/绝对路径
  --ll-profile <path>     指定 LiteLoaderQQNT 数据存放路径
  -h, --help              显示帮助信息
  -u, --update            尝试更新 LiteLoaderQQNT

默认会自动检测系统，尝试可能的 QQ 安装方式，提供如下变量供自定义：
- 'LITELOADERQQNT_DIR' LiteLoaderQQNT 本体位置，默认值：
    Linux: '\$HOME/.local/share/LiteLoaderQQNT'
    macOS: '\$HOME/Library/Containers/com.tencent.qq/Data/Documents/LiteLoaderQQNT'
- 'LITELOADERQQNT_PROFILE' LiteLoaderQQNT 数据目录，默认值：
    Linux: 'HOME/.config/LiteLoaderQQNT'
    macOS: 则与本体位于同一目录
- 'QQ_PATH' 自定义 QQ 位置（其 app 文件夹所在的父目录）
- 'PLATFORM' 强制指定系统，非必要勿使用，为可能的系统检测失败预留，值必须为 'linux' 或 'macos'
EOF
}

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

# 获取有效代理
function get_github_working_proxy() {
    for proxy in "${github_download_proxies[@]}"; do
        if curl -Isf -m 5 -o /dev/null "${proxy%/}/https://github.com"; then
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
        proxy=$(get_github_working_proxy)
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
        echo "下载失败：$url"
        rm -rf "$output"
        return 1
    fi
}

# 提升权限
function elevate_permissions() {
    echo "请输入您的密码以提升权限："
    sudo -v
}

# 获取 LiteLoaderQQNT 本体安装位置
# 调用该函数必须传递 $qq_path ，考虑优化
function get_liteloaderqqnt_path() {
    local qq_path=$1
    local _dir="${LITELOADERQQNT_DIR:-$DEFAULT_LITELOADERQQNT_DIR}"
    case "$_dir" in
        "xdg")  _dir="$HOME/.local/share/$LITELOADERQQNT_NAME" ;;
        "qq")   _dir="$qq_path/$LITELOADERQQNT_NAME" ;;
        "opt")  _dir="/opt/$LITELOADERQQNT_NAME" ;;
        *)      _dir="$(cd "$WORKDIR" && realpath "$_dir")"
    esac
    mkdir -p "$_dir" || { echo "创建失败：'$_dir'" >&2; return 1; }
    echo "$_dir"
}

# 拉取 LiteLoaderQQNT
function pull_liteloaderqqnt() {
    local new_ll_path="${1:-$LITELOADERQQNT_NAME}"
    local url=$LITELOADERQQNT_URL

    echo "正在拉取最新Release版本的仓库"
    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -q "$_name" -d "$new_ll_path" && return 0
    fi

    echo "LiteLoaderQQNT 获取失败"
    return 1
}

# 安装 LiteLoaderQQNT 的函数
function install_liteloaderqqnt() {
    local ll_path

    # 设置路径和命令
    case "$PLATFORM" in
        linux)  local qq_path="/opt/QQ/resources"
                local restore_dir="$liteloaderqqnt_config" ;; # 分离本体与数据
        macos)  local qq_path="/Applications/QQ.app/Contents/Resources"
                local restore_dir="$ll_path" ;; # 暂时保持与数据融合
        # *) echo "Unsupported platform: $PLATFORM"; return 1 ;;
    esac

    qq_path=${QQ_PATH:-$qq_path} # 提供自定义 QQ 路径

    [ -d "$qq_path" ] || { echo "QQ未安装，退出"; return 0; }

    ll_path=$(get_liteloaderqqnt_path "$qq_path" ) || {
        echo "获取 LiteLoaderQQNT 本体路径失败" >&2
        return 1
    }
    local new_ll_path="$LITELOADERQQNT_NAME"
    pull_liteloaderqqnt "$new_ll_path" || return 1
    echo "拉取完成，正在安装 LiteLoaderQQNT..."

    # TODO 更好的更新逻辑
    local backup_data_dir="${LITELOADERQQNT_NAME}_bak"
    mkdir -p "$backup_data_dir"
    for _dir in "data" "plugins"; do
        if ls -A "$ll_path/$_dir" &>/dev/null; then
            echo "正在备份 LiteLoaderQQNT 数据目录 $_dir ..."
            if $sudo_cmd rsync -a "$ll_path/$_dir" "$backup_data_dir/"; then
                echo "已备份至 '$backup_data_dir/$_dir'"
            else
                echo "备份失败：$_dir"
                return 1
            fi
        fi
    done
    [ -z "$(ls -A "$backup_data_dir" 2>/dev/null)" ] && rm -rf "$backup_data_dir"

    mv "$ll_path" "${ll_path}_bak"
    if $sudo_cmd rsync -a "$new_ll_path/" "$ll_path"; then
        # 恢复插件和数据
        if [ -d "$backup_data_dir" ]; then
            if ! $sudo_cmd rsync -a "$backup_data_dir/" "$restore_dir"; then
                echo "恢复插件数据失败，退出..."
                return 1
            fi
            echo "已恢复 LiteLoaderQQNT 数据"
            rm -rf "${ll_path}_bak"
        fi
        echo "LiteLoaderQQNT 安装/更新成功"
    else
        echo "移动 LiteLoaderQQNT 到目标目录失败"
        rm -rf "$ll_path"
        mv "${ll_path}_bak" "$ll_path" && echo "更新失败，已恢复，退出..."
        return 1
    fi

    # 修补 resources
    patch_resources "$qq_path/app" "$ll_path" || return 1

    # 针对 macOS 官网版热更新适配
    if [ "$PLATFORM" == "macos" ]; then
        echo "正在对 macOS 热更新版本进行补丁"
        versions_path="$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/versions"
        for version_dir in "$versions_path"/*; do
            _dir="$version_dir/QQUpdate.app/Contents/Resources/app"
            [ -d "$_dir" ] && patch_resources "$_dir" "$ll_path"
        done
        return 0 # 无论是否成功都返回 true,待优化？
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

        case "$PLATFORM" in
            linux) sed_command=("sudo" sed "-i") ;;
            macos) sed_command=("sudo" sed "-i" "") ;;
            *) echo "Unsupported platform: $PLATFORM"; return 1 ;;
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
    local plugins_dir="$liteloaderqqnt_config/plugins"
    local plugin_store_dir="$plugins_dir/list-viewer"

    echo "修改 LiteLoaderQQNT 文件夹权限(可能解决部分错误)"
    sudo chmod -R 0755 "$liteloaderqqnt_config"

    mkdir -p "$plugins_dir" || return 1

    if ls -A "$plugin_store_dir" &> /dev/null; then
        echo "插件列表查看已存在"
        return 0
    fi

    echo "正在拉取最新版本的插件列表查看..."
    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -q "$_name" -d "$plugin_store_dir" && { echo "插件商店安装成功"; return 0; }
    fi

    echo "插件商店安装失败"
    return 1
}

function set_liteloaderqqnt_profile() {
    local var_value="$liteloaderqqnt_config"
    local var_name="LITELOADERQQNT_PROFILE"
    local start_marker="# BEGIN LITELOADERQQNT"
    local end_marker="# END LITELOADERQQNT"

    # 获取 config_file
    local config_file="$HOME/.profile"
    local _perfix="export $var_name="
    case "${SHELL##*/}" in
        zsh)    config_file="$HOME/.zshrc" ;;
        bash)   config_file="$HOME/.bashrc" ;;
        fish)   _perfix="set -gx LITELOADERQQNT_PROFILE "
                config_file="$(fish -c 'printf $__fish_config_dir')/config.fish" ;;
        *)  echo "非bash、zsh、fish，将尝试修改 ~/.profile"
            echo "若不生效，请自行根据 ~/.profile 内新增内容修改 shell 配置" ;;
    esac

    echo "尝试为shell ${SHELL##*/} 设置环境变量: LITELOADERQQNT_PROFILE"

    # 获取已定义值
    existing_value=$(sed -n "s/^$_perfix//gp" "$config_file" | awk 'END { print }')
    if [ -n "$existing_value" ]; then
        var_value=$(echo "${existing_value#\"}" | sed 's/^\"//;s/\"$//;s/^'\''//;s/'\''$//')
        echo "变量 $var_name 将使用已设置的值：'$var_value'"
    else
        echo "变量 $var_name 将使用默认值：'$var_value'"
    fi

    # 写入
    local context="$_perfix\"$var_value\""
    context="$start_marker\n# 请勿在行内填写任何其他配置\n$context\n$end_marker"

    if grep -q "^$start_marker$" "$config_file" && grep -q "^$end_marker$" "$config_file"; then
        # TODO 添加一个函数或从脚本参数获取以更新变量
        # echo "配置已存在，跳过修改"
        sed -i "/$start_marker/,/$end_marker/c $context" "$config_file"
        echo "使用已设置值更新 $var_name，值为 '$var_value'"
    else
        sed -i "s/^$_perfix//d" "$$config_file"
        echo -e "\n$context" >> "$config_file"
        echo "已添加变量 $var_name 至 $config_file，值为：'$var_value'"
    fi
}

function install_liteloaderqqnt_with_aur() {
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

function install_for_flatpak_qq() {
    # 检查 Flatpak 是否安装
    if command -v flatpak &> /dev/null; then
        # 检查是否安装了 Flatpak 版的 QQ
        if flatpak list --app --columns=application | grep -xq "com.qq.QQ"; then
            echo "检测到 Flatpak 版 QQ 已安装"
            
            local qq_path
            qq_path=$(flatpak info --show-location com.qq.QQ)/files/extra/QQ/resources
            install_liteloaderqqnt "$qq_path"

            local ll_path
            ll_path=$(get_liteloaderqqnt_path "$qq_path") || {
                echo "获取 LiteLoaderQQNT 本体路径失败" >&1
                return 1
            }

            # 授予 Flatpak 访问 LiteLoaderQQNT 数据目录的权限
            echo "授予 Flatpak 版 QQ 对数据目录 $liteloaderqqnt_config 和本体目录 $ll_path 的访问权限"
            sudo flatpak override --user com.qq.QQ --filesystem="$liteloaderqqnt_config"
            sudo flatpak override --user com.qq.QQ --filesystem="$ll_path"

            # 将 LITELOADERQQNT_PROFILE 作为环境变量传递给 Flatpak 版 QQ
            sudo flatpak override --user com.qq.QQ --env=LITELOADERQQNT_PROFILE="$liteloaderqqnt_config"

            echo "设置完成！LiteLoaderQQNT 数据目录：$liteloaderqqnt_config"
        fi
    fi
}

# 检查平台
case "${PLATFORM:-$(uname)}" in
    "Linux") PLATFORM="linux";;
    "Darwin") PLATFORM="macos";;
    *) echo "不支持的系统？请反馈，退出..."; exit 1 ;;
esac

readonly LITELOADERQQNT_NAME="LiteLoaderQQNT"
if [ "$PLATFORM" = "linux" ]; then
    sudo_cmd="sudo"
    readonly DEFAULT_LITELOADERQQNT_DIR="$HOME/.local/share/$LITELOADERQQNT_NAME"
    readonly DEFAULT_LITELOADERQQNT_CONFIG="$HOME/.config/$LITELOADERQQNT_NAME"
elif [ "$PLATFORM" = "macos" ]; then
    sudo_cmd=""
    readonly DEFAULT_LITELOADERQQNT_DIR="$HOME/Library/Containers/com.tencent.qq/Data/Documents/$LITELOADERQQNT_NAME"
    readonly DEFAULT_LITELOADERQQNT_CONFIG="$HOME/Library/Containers/com.tencent.qq/Data/Documents/$LITELOADERQQNT_NAME"
fi

# 解析参数
OPTIONS=$(getopt -o h --long appimage::,ll-dir:,ll-profile:,help -n "$0" -- "$@") || \
    { echo "Error: 参数处理失败."; exit 1; }
eval set -- "$OPTIONS"
unset OPTIONS

echo "$@" | grep -q -wE '(-h|--help)' && { show_help; exit 0; } # 优先显示帮助信息

# 创建并切换至临时目录
temp_dir=$(mktemp -d)
echo "临时目录创建成功: $temp_dir"
cd "$temp_dir" || exit 1

# 处理每个参数
while true; do
    case "$1" in
        --appimage)
            { [ -n "$2" ] && [ -f "$2" ] && APPIMAGE_PATH="$2"; } || APPIMAGE_PATH=""
            echo "TODO"; exit 0 #TODO
            shift 2 ;;
        --ll-dir)       LITELOADERQQNT_DIR="${2%/}"; shift 2 ;;
        --ll-profile)   LITELOADERQQNT_PROFILE="${2%/}"; shift 2 ;;
        -u|--update)    echo "TODO"; exit 0 ;; #TODO
        --) shift; break ;;
        *)  echo "Error: 未知选项 '$1'."; show_help; exit 1 ;;
    esac
done

# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：禁止以 root 用户执行此脚本。"
    echo "请使用普通用户执行"
    exit 1
fi

dependencies=("wget" "curl" "unzip" "sudo" "rsync")
check_dependencies || exit 1

# 统一不同平台/安装方式的 QQ 对 LiteLoaderQQNT 本体及数据的处理
# liteloaderqqnt_dir="${LITELOADERQQNT_DIR:-$DEFAULT_LITELOADERQQNT_DIR}"
liteloaderqqnt_config="${LITELOADERQQNT_PROFILE:-$DEFAULT_LITELOADERQQNT_CONFIG}"

if mkdir -p "$liteloaderqqnt_config"; then
    echo "目录创建成功：$liteloaderqqnt_config"
else
    echo "目录创建失败：$liteloaderqqnt_config"
    exit 1
fi

if [ "$PLATFORM" = "linux" ]; then
    install_liteloaderqqnt_with_aur || exit 1
    install_for_flatpak_qq || exit 1
fi

elevate_permissions

if [[ "$PLATFORM" == "linux" && "$GITHUB_ACTIONS" != "true" ]]; then
    set_liteloaderqqnt_profile
fi

install_liteloaderqqnt || exit 1

install_plugin_store || { echo "发生错误，安装失败"; exit 1; }

export LITELOADERQQNT_PROFILE="$LITELOADERQQNT_PROFILE"

echo "如果安装过程中没有提示发生错误"
echo "但 QQ 设置界面没有 LiteLoaderQQNT"
echo "请检查已安装过的插件"
echo "插件错误会导致 LiteLoaderQQNT 无法正常启动"

echo "打开QQ后会弹出初始化失败，此为正常现象，请按照说明完成后续操作"

echo "脚本将在 3 秒后退出..."
sleep 3
