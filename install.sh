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
  -k, --skip-sudo         强制跳过 sudo 提权
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

# 依赖检查
function check_dependencies() {
    _count=0
    for dep in "wget" "curl"; do
        ! command -v "$dep" >/dev/null 2>&1 && { _count=$((_count+1)); continue; }
        readonly REQUEST_CMD=$dep
        break
    done
    [ "$_count" -eq 2 ] && { echo "请安装 wget 或 curl 后重试." >&2; return 1; }

    command -v unzip >/dev/null 2>&1 || { echo "未检测到 unzip，请安装后重试" >&2; return 1; }
    command -v rsync >/dev/null 2>&1 || echo "未检测到 rsync，将使用 cp 命令替代" >&2
}

function sync_files() {
    [ -e "$1" ] || return 1
    command -v rsync >/dev/null 2>&1 && { $sudo_cmd rsync -a "$1" "$2"; return; }
    $sudo_cmd cp -aR "$1" "$2"
}

function check_url_connectivity() {
    local cmd=(wget -q --spider -t1 -T5 "$1")
    [ "$REQUEST_CMD" = "curl" ] && cmd=(curl -Isf -m5 -o /dev/null "$1")
    "${cmd[@]}"
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
        if check_url_connectivity "${proxy%/}/https://github.com"; then
            echo "${proxy%/}"
            return 0
        fi
    done
    return 1
}

# 获取下载 URL
function get_github_download_url() {
    local url=$1
    if check_url_connectivity "$url"; then
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

function download_url() {
    local url
    url=$(get_github_download_url "$1") || return 1
    local output=${2:-$(basename "$url")}

    local cmd=(wget -t3 -T3 -q -O "$output" "$url")
    [ "$REQUEST_CMD" = "curl" ] && cmd=(curl -L --retry 3 -m3 -s -o "$output" "$url")

    [ "$output" = "-" ] && { "${cmd[@]}"; return; }

    [ -f "$output" ] && { echo "文件已下载，跳过: '$output'" && return 0; }

    echo "开始下载 $output: $url"
    "${cmd[@]}" || { echo "下载失败" >&2; rm -rf "$output"; return 1; }
    echo "下载成功"
}

# 提升权限
function elevate_permissions() {
    [ "$SKIP_SUDO" = 0 ] && { echo "跳过提权"; return 0; }
    command -v sudo >/dev/null 2>&1 || { echo "未找到 sudo 命令"; return 0; }

    case "$PLATFORM" in
        linux)  echo "请输入您的密码以提升权限："; sudo_cmd="sudo"; sudo -v ;;
        macos)  sudo_cmd="" ;;
    esac
}

# 获取 LiteLoaderQQNT 本体安装位置
function get_liteloaderqqnt_path() {
    local _dir="${LITELOADERQQNT_DIR:-$DEFAULT_LITELOADERQQNT_DIR}"
    case "$_dir" in
        "xdg")  _dir="$HOME/.local/share/$LITELOADERQQNT_NAME" ;;
        "qq"|"appimage")
            local _tmp=${1:-$qq_res_path}
            _tmp=${_tmp:-$(get_qq_resources_path "$QQ_PATH")} || return 1
            _dir="$_tmp/app/app_launcher/$LITELOADERQQNT_NAME" ;;
        "opt")  _dir="/opt/$LITELOADERQQNT_NAME" ;;
        *)      _dir="$(cd "$WORKDIR" && realpath "$_dir")"
    esac
    mkdir -p "$_dir" || { echo "创建失败：'$_dir'" >&2; return 1; }
    echo "$_dir"
}

# 获取 QQ resources 路径，确保修改可用
function get_qq_resources_path() {
    local qq_path=${1:-$QQ_PATH}
    # 读取 config.json 文件，增强兼容性
    version_file=$(find "$qq_path" -type f -name 'config.json' 2>/dev/null | grep 'versions/config.json$')

    if [ "$(echo "$version_file" | wc -l)" -gt 1 ]; then
        echo "Error：找到多个 config.json 文件，请检查 '$qq_path' 是否为 QQ 安装根路径？" >&2
        return 1
    fi

    if [ -n "$version_file" ]; then
        version=$(grep "$version_file" -e '"curVersion"' | cut -d\" -f4)
        [ -n "$version" ] && _tmp=$(find "$qq_path" -type d -name "$version" 2>/dev/null |grep "versions/${version}$")
        [ -n "$_tmp" ] && qq_path="$_tmp" || \
            echo "Error：已找到 version 文件 '$version_file'，但获取版本目录失败" >&2
    fi

    _tmp=$(find "$qq_path" -type d -iname 'app_launcher' 2>/dev/null | grep 'app_launcher$')
    [ -n "$_tmp" ] && { echo "${_tmp%/app/app_launcher}"; return 0; }
    echo "Error：未在 '$qq_path' 找到可用 resources 路径" >&2; return 1;
}

# 拉取 LiteLoaderQQNT
function pull_liteloaderqqnt() {
    local url=$LITELOADERQQNT_URL

    echo "正在拉取最新Release版本的仓库"
    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -oq "$_name" -d "$LITELOADERQQNT_NAME" && return 0
    fi

    echo "LiteLoaderQQNT 获取失败"
    return 1
}

# 安装 LiteLoaderQQNT 的函数
function install_liteloaderqqnt() {
    local ll_path="$liteloaderqqnt_path"

    pull_liteloaderqqnt || return 1
    echo "拉取完成，正在安装 LiteLoaderQQNT..."

    # TODO 更好的更新逻辑
    local backup_data_dir="${LITELOADERQQNT_NAME}_bak"
    mkdir -p "$backup_data_dir"
    for _dir in "data" "plugins"; do
        if [ -n "$(ls -A "$ll_path/$_dir" 2>/dev/null)" ]; then
            echo "正在备份 LiteLoaderQQNT 数据目录 $_dir ..."
            if sync_files "$ll_path/$_dir" "$backup_data_dir/"; then
                echo "已备份至 '$backup_data_dir/$_dir'"
            else
                echo "备份失败：$_dir"
                return 1
            fi
        fi
    done
    [ -z "$(ls -A "$backup_data_dir" 2>/dev/null)" ] && rm -rf "$backup_data_dir"

    mv "$ll_path" "${ll_path}_bak"
    if sync_files "$LITELOADERQQNT_NAME/" "$ll_path"; then
        # 恢复插件和数据
        if [ -d "$backup_data_dir" ]; then
            # 设置数据存储模式
            local restore_dir="$liteloaderqqnt_config"
            [ "$SEPARATE_DATA_MODE" -eq 0 ] || restore_dir="$ll_path"

            if ! sync_files "$backup_data_dir/" "$restore_dir"; then
                echo "恢复插件数据失败，退出..."
                return 1
            fi
            echo "已恢复 LiteLoaderQQNT 数据"
        fi
        rm -rf "${ll_path}_bak"
        echo "LiteLoaderQQNT 安装/更新成功"
    else
        echo "移动 LiteLoaderQQNT 到目标目录失败"
        rm -rf "$ll_path"
        mv "${ll_path}_bak" "$ll_path" && echo "更新失败，已恢复，退出..."
        return 1
    fi

    # 修补 resources
    patch_resources || return 1

    local qq_update_dir=(
        "$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/versions"
        "$HOME/Library/Application Support/QQ/versions")

    if [ "$PLATFORM" = "macos" ]; then
        echo "尝试处理 QQ 热更新"
        for _tmp in "${qq_update_dir[@]}"; do
            qq_res_path=$(get_qq_resources_path "$_tmp") || { echo "无热更新."; continue; }
            patch_resources
        done
        return 0 # TODO 无论是否成功都返回 true，待优化？
    fi
}

# 修补 resources，创建 *.js 文件，并修改 package.json
function patch_resources() {
    local ll_path=$liteloaderqqnt_path  # LiteLoaderQQNT 路径，默认相对 $qq_res_path/app/app_launcher
    local jsfile_name="ml_install.js"   # 这里的文件名可以随意设置
    local jsfile_path="$qq_res_path/app/app_launcher/$jsfile_name"

    echo "开始处理 $qq_res_path"

    [[ "$LITELOADERQQNT_DIR" =~ ^(qq|appimage)$ ]] && ll_path="./LiteLoaderQQNT"

    # 写入 require(String.raw`*`) 到 *.js 文件
    echo "正在将 'require(\"${ll_path%/}\");' 写入 app_launcher/$jsfile_name"
    echo "require(\"${ll_path%/}\");" | $sudo_cmd tee "$jsfile_path" > /dev/null
    echo "写入成功"

    # 检查 package.json 文件是否存在
    local package_json="$qq_res_path/app/package.json"
    if [ -f "$package_json" ]; then
        # 修改 package.json 中的 main 字段为 ./app_launcher/launcher.js
        echo "正在修改 package.json 的 main 字段为 './app_launcher/$jsfile_name'"

        case "$PLATFORM" in
            linux) sed_command=($sudo_cmd sed -i) ;;
            macos) sed_command=($sudo_cmd sed -i "") ;;
            *) echo "Unsupported platform: $PLATFORM"; return 1 ;;
        esac

        if "${sed_command[@]}" 's|"main":.*|"main": "./app_launcher/'"$jsfile_name"'",|' "$package_json"; then
            echo "修改成功: $qq_res_path"
            return 0
        fi
        echo "修改失败：$qq_res_path" && return 1
    else
        echo "未找到 package.json ，跳过修改" && return 1
    fi
}

function install_plugin_store() {
    local url=$PLUGIN_LIST_VIEWER_URL
    local plugins_dir="$liteloaderqqnt_config/plugins"
    local plugin_store_dir="$plugins_dir/list-viewer"

    echo "修改 LiteLoaderQQNT 文件夹权限(可能解决部分错误)"
    $sudo_cmd chmod -R 0755 "$liteloaderqqnt_config"

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

    echo "插件商店安装失败，请手动安装"
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
        # TODO 不一致时更新
        sed -i "/$start_marker/,/$end_marker/c $context" "$config_file" || \
            { echo "变量 $var_name 更新失败" >&2; return 1; }
        echo "使用已设置值更新 $var_name，值为 '$var_value'"
    else
        sed -i "/^$_perfix/d" "$config_file"
        echo -e "\n$context" >> "$config_file" || \
            { echo "变量 $var_name 写出失败" >&2; return 1; }
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
                    { cd liteloader-qqnt-bin && makepkg -si; } || { echo "安装失败" >&2; return 1; }
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

            liteloaderqqnt_path=$(get_liteloaderqqnt_path "$qq_res_path") || {
                echo "获取 LiteLoaderQQNT 本体路径失败" >&1
                return 1
            }

            qq_res_path=$(flatpak info --show-location com.qq.QQ)/files/extra/QQ/resources
            install_liteloaderqqnt || return 1

            # 授予 Flatpak 访问 LiteLoaderQQNT 数据目录的权限
            echo "授予 Flatpak 版 QQ 对数据目录 $liteloaderqqnt_config 和本体目录 $liteloaderqqnt_path 的访问权限"
            $sudo_cmd flatpak override --user com.qq.QQ --filesystem="$liteloaderqqnt_config"
            $sudo_cmd flatpak override --user com.qq.QQ --filesystem="$liteloaderqqnt_path"

            # 将 LITELOADERQQNT_PROFILE 作为环境变量传递给 Flatpak 版 QQ
            $sudo_cmd flatpak override --user com.qq.QQ --env=LITELOADERQQNT_PROFILE="$liteloaderqqnt_config"

            echo "设置完成！LiteLoaderQQNT 数据目录：$liteloaderqqnt_config"
        fi
    fi
}

# 获取qq appimage 最新链接
function get_qqnt_appimage_url() {
    [ "${ARCH:-$(uname -m)}" = "x86_64" ] && _arch="x86_64" || _arch="arm64"
    check_url="$(download_url https://im.qq.com/linuxqq/index.shtml -| grep -o 'https://.*linuxQQDownload.js?[^"]*')"
    [ "$check_url" ] && appimage_url=$(download_url "$check_url" -| grep -o 'https://[^,]*AppImage' | grep "$_arch")

    [ -z "$appimage_url" ] && { echo "获取qq下载链接失败"; return 1; }
    echo "$appimage_url"
}

# 计算 squashfs 偏移值
function calc_appimage_offset() {
    local appimage_file="$1"
    local magic_number="68 73 71 73" #hsqs

    [ ! -f "$appimage_file" ] && { echo "Error: '$appimage_file' not found!" >&2; return 1; }

    # 查找魔数并计算偏移值
    lineno=$(od -A n -t x1 -v -w4 "$appimage_file" | awk "/^ $magic_number/ {print NR; exit}")
    [ -z "$lineno" ] && { echo "Error: 未找到 squashfs"; return 1; }

    echo "$(( (lineno-1)*4 ))"
}

# 提取 appimage 内容
function extract_appimage() {
    local appimage_file="$1"
    offset=$(calc_appimage_offset "$appimage_file") || return 1
    echo "squashfs偏移值：$offset"
    output="out.squashfs"
    rm -rf squashfs-root runtime

    echo "正在写出 runtime 文件：runtime"
    head -c "$offset" "$appimage_file" > runtime || return 1
    echo "写出成功：runtime"

    echo "正在写出 squashfs 文件：$output"
    tail -c +"$((offset+1))" "$appimage_file" > "$output" || return 1
    echo "写出成功：$output"

    echo "开始提取 squashfs 内容"
    unsquashfs "$output" >/dev/null
    [ ! -d "squashfs-root" ] && { echo "文件提取失败: $output" >&2; return 1; }
    echo "文件提取成功：squashfs-root"
    rm "$output" && echo "临时文件 $output 已移除"
}

# 修改 AppRun 文件以支持变量 LITELOADERQQNT_PROFILE
function patch_appimage_apprun() {
    local apprun_file="$1/AppRun"
    local profile_dir="\$HOME/.config/$LITELOADERQQNT_NAME"

    # 检查是否已存在 LITELOADERQQNT_PROFILE
    if grep -q "export LITELOADERQQNT_PROFILE=" "$apprun_file"; then
        sed -i "s|export LITELOADERQQNT_PROFILE=.*|export LITELOADERQQNT_PROFILE=\${LITELOADERQQNT_PROFILE:=$profile_dir}|" "$apprun_file"
    else
        # 如果不存在，则添加新的行
        echo "export LITELOADERQQNT_PROFILE=\${LITELOADERQQNT_PROFILE:=$profile_dir}" >> "$apprun_file"
        echo "已添加 LITELOADERQQNT_PROFILE: \"$profile_dir\""
    fi
}

# 重新打包 appimage 文件
function repack_appimage() {
    local appdir="$1"
    local output="$2"
    echo "正在重新打包"
    mksquashfs "$appdir" tmp.squashfs -root-owned -noappend >/dev/null
    cat "runtime" >> "$output"
    cat "tmp.squashfs" >> "$output"
    rm -rf "tmp.squashfs"
    rm -f "runtime"
    chmod a+x "$output"
    echo "打包完成：$output"
}

function download_qq_appimage() {
    qq_url=$(get_qqnt_appimage_url)
    qq_filename=$(basename "$qq_url")
    appimage_path=$(realpath "$qq_filename")
    download_url "$qq_url" "$qq_filename"
}

# 修改 appimage 文件
function patch_appimage() {
    # APPIMAGE_MODE=0
    LITELOADERQQNT_DIR="${LITELOADERQQNT_DIR:-appimage}"
    echo "正在获取 LiteLoaderQQNT 版本..."
    liteloaderqqnt_check_url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest"
    liteloaderqqnt_version=$(basename "$(wget -t3 -T3 --spider "$liteloaderqqnt_check_url" 2>&1 | grep -m1 -o 'https://.*releases/tag[^ ]*')")
    echo "最新 LiteLoaderQQNT 版本：$liteloaderqqnt_version"

    if [ -z "$APPIMAGE_PATH" ]; then
        download_qq_appimage || return 1
        APPIMAGE_PATH="$appimage_path"
    fi

    _tmp=${APPIMAGE_PATH##*/}
    new_qq_filename="$WORKDIR/${_tmp%%AppImage}_patch-${liteloaderqqnt_version}.AppImage"

    echo "正在对 AppImage 文件进行补丁操作: $APPIMAGE_PATH"
    extract_appimage "$APPIMAGE_PATH" || return 1
    patch_appimage_apprun "squashfs-root" || return 1

    qq_res_path=$(get_qq_resources_path "squashfs-root") || return 1
    liteloaderqqnt_path=$(get_liteloaderqqnt_path) || return 1

    install_liteloaderqqnt || return 1
    repack_appimage "squashfs-root" "$new_qq_filename" || return 1
}

# unset liteloaderqqnt_path qq_res_path

# 检查平台
_tmp=$(echo "${PLATFORM:-$(uname)}" | tr '[:upper:]' '[:lower:]')
case "$_tmp" in
    "linux")            PLATFORM="linux";;
    "darwin"|"macos")   PLATFORM="macos";;
    *) echo "不支持的系统？请反馈，退出..."; exit 1 ;;
esac

readonly LITELOADERQQNT_NAME="LiteLoaderQQNT"
if [ "$PLATFORM" = "linux" ]; then
    QQ_PATH="$(realpath "${QQ_PATH:-/opt/QQ}")"
    readonly SEPARATE_DATA_MODE=0 # 分离本体与数据
    readonly DEFAULT_LITELOADERQQNT_DIR="$HOME/.local/share/$LITELOADERQQNT_NAME"
    readonly DEFAULT_LITELOADERQQNT_CONFIG="$HOME/.config/$LITELOADERQQNT_NAME"
elif [ "$PLATFORM" = "macos" ]; then
    QQ_PATH="${QQ_PATH:-/Applications/QQ.app}"
    readonly SEPARATE_DATA_MODE=1 # macOS 暂不支持
    readonly DEFAULT_LITELOADERQQNT_DIR="$HOME/Library/Containers/com.tencent.qq/Data/Documents/$LITELOADERQQNT_NAME"
    readonly DEFAULT_LITELOADERQQNT_CONFIG="$DEFAULT_LITELOADERQQNT_DIR"
fi

# [ "${QQ_PATH:0:1}" = "/" ] && QQ_PATH=$(realpath "$QQ_PATH")
# [ -d "$QQ_PATH" ] || { echo "指定的 QQ 路径不存在：'$QQ_PATH'" >&2; exit 1; }

# 解析参数
OPTIONS=$(getopt -o h,k --long appimage::,ll-dir:,ll-profile:,skip-sudo,help -n "$0" -- "$@") || \
    { echo "Error: 参数处理失败."; exit 1; }
eval set -- "$OPTIONS"
unset OPTIONS

echo "$@" | grep -q -wE '(-h|--help)' && { show_help; exit 0; } # 优先显示帮助信息

# 处理每个参数
while true; do
    case "$1" in
        --appimage)
            APPIMAGE_MODE=0
            _tmp=${2:-$APPIMAGE_PATH}
            [ -f "$_tmp" ] && APPIMAGE_PATH=$(realpath "$_tmp")
            [ -f "$_tmp" ] || unset APPIMAGE_PATH
            shift 2 ;;
        --ll-dir)       LITELOADERQQNT_DIR="${2:-LITELOADERQQNT_DIR}"; shift 2 ;;
        --ll-profile)   LITELOADERQQNT_PROFILE="${2:-$LITELOADERQQNT_PROFILE}"; shift 2 ;;
        -k|--skip-sudo) SKIP_SUDO=0; shift 1 ;;
        -u|--update)    echo "TODO"; exit 0 ;; #TODO
        --) shift; break ;;
        *)  echo "Error: 未知选项 '$1'."; show_help; exit 1 ;;
    esac
done

# TODO 兼容 macOS: realpath
_tmp="${LITELOADERQQNT_PROFILE:-$DEFAULT_LITELOADERQQNT_CONFIG}"
if mkdir -p "$_tmp"; then
    echo "目录创建成功：$_tmp"
else
    echo "目录创建失败：$_tmp"
    exit 1
fi
liteloaderqqnt_config=$(realpath "$_tmp")

# 创建并切换至临时目录
temp_dir=$(mktemp -d)
echo "临时目录创建成功: $temp_dir"
cd "$temp_dir" || exit 1

# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：禁止以 root 用户执行此脚本。"
    echo "请使用普通用户执行"
    exit 1
fi

check_dependencies || exit 1

# patch appimage
[ "$APPIMAGE_MODE" = 0 ] && {
    patch_appimage "$APPIMAGE_PATH" || exit 1
    exit 0
}

elevate_permissions

if [ "$PLATFORM" = "linux" ]; then
    install_liteloaderqqnt_with_aur || exit 1
    install_for_flatpak_qq || exit 1
fi

qq_res_path=$(get_qq_resources_path) && {
    liteloaderqqnt_path=$(get_liteloaderqqnt_path)
    install_liteloaderqqnt || exit 1
}

[ "$PLATFORM" = "linux" ] && set_liteloaderqqnt_profile && \
    export LITELOADERQQNT_PROFILE="$LITELOADERQQNT_PROFILE"

install_plugin_store

echo "如果安装过程中没有提示发生错误"
echo "但 QQ 设置界面没有 LiteLoaderQQNT"
echo "请检查已安装过的插件"
echo "插件错误会导致 LiteLoaderQQNT 无法正常启动"

echo "打开QQ后会弹出初始化失败，此为正常现象，请按照说明完成后续操作"

echo "脚本将在 3 秒后退出..."
sleep 3
