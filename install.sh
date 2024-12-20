#!/bin/bash

readonly LITELOADERQQNT_URL="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/releases/latest/download/LiteLoaderQQNT.zip"
readonly PLUGIN_LIST_VIEWER_URL="https://github.com/ltxhhz/LL-plugin-list-viewer/releases/latest/download/list-viewer.zip"

readonly WORKDIR="$PWD"

cleanup() {
    [ -d "$temp_dir" ] && {
        log_info "清理临时目录: $temp_dir"
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

log_info() {
    printf "\e[32m[INFO]\e[0m : %s\n" "$1"
}

log_error() {
    printf "\e[31m[ERROR]\e[0m: %s\n" "$1" >&2
}

# 依赖检查
function check_dependencies() {
    _count=0
    for dep in "wget" "curl"; do
        ! command -v "$dep" >/dev/null 2>&1 && { _count=$((_count+1)); continue; }
        readonly REQUEST_CMD=$dep
        break
    done
    [ "$_count" -eq 2 ] && { log_error "请安装 wget 或 curl 后重试."; return 1; }

    command -v unzip >/dev/null 2>&1 || { log_error "未检测到 unzip，请安装后重试"; return 1; }
    command -v rsync >/dev/null 2>&1 || log_error "未检测到 rsync，将使用 cp 命令替代"
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
            log_error "无可用代理"
            return 1
        fi
        echo "${proxy}/${url}"
        return 0
    fi

    log_error "无效的下载链接：$url"
    return 1
}

function download_url() {
    local url
    url=$(get_github_download_url "$1") || return 1
    local output=${2:-$(basename "$url")}

    local cmd=(wget -t3 -T3 -q -O "$output" "$url")
    [ "$REQUEST_CMD" = "curl" ] && cmd=(curl -L --retry 3 -m3 -s -o "$output" "$url")

    [ "$output" = "-" ] && { "${cmd[@]}"; return; }

    [ -f "$output" ] && { log_info "文件已下载，跳过: '$output'" && return 0; }

    log_info "开始下载 $output: $url"
    "${cmd[@]}" || { log_error "下载失败"; rm -rf "$output"; return 1; }
    log_info "下载成功"
}

# 获取最新版本号(release tag)
get_github_latest_release() {
    local url="$1"
    if ! [[ "$url" =~ ^(https?:\/\/)?github\.com/ ]]; then
        log_error "非 GitHub 仓库 URL：'$url'"
        return 1
    fi
    # 提取 GitHub 用户名和仓库名
    repo=$(echo "$url" | awk -F/ '{print $4 "/" $5}')
    # 请求 API
    local _tmp="https://api.github.com/repos/$repo/releases/latest"
    _tmp=$(download_url "$_tmp" -| awk -F'"' '/"tag_name":/ {print $4}')
    [ -n "$_tmp" ] && { echo "$_tmp"; return 0; }
    # 解析 html
    _tmp="$(download_url "https://github.com/$repo/releases/latest" -| grep -m1 -o "$repo/releases/tag/[^\"/]*")"
    [ -z "$_tmp" ] && { log_error "最新版本获取失败"; return 1; }
    echo "${_tmp##*/}"
}

# 提升权限
function elevate_permissions() {
    [ "$SKIP_SUDO" = 0 ] && { log_info "跳过提权"; return 0; }
    command -v sudo >/dev/null 2>&1 || { log_info "未找到 sudo 命令"; return 0; }

    case "$PLATFORM" in
        linux)
            log_info "请输入您的密码以提升权限："
            sudo -v || { log_error "提权失败，请重试或添加 '-k' 参数以跳过提权，退出"; return 1; }
            sudo_cmd="sudo" ;;
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
    mkdir -p "$_dir" || { log_error "创建 LiteLoaderQQNT 安装路径失败：'$_dir'"; return 1; }
    echo "$_dir"
}

# 获取 QQ resources 路径，确保修改可用
function get_qq_resources_path() {
    local qq_path=${1:-$QQ_PATH}
    # 读取 config.json 文件，增强兼容性
    version_file=$(find "$qq_path" -type f -name 'config.json' 2>/dev/null | grep 'versions/config.json$')

    if [ "$(echo "$version_file" | wc -l)" -gt 1 ]; then
        log_error "找到多个 config.json 文件，请检查是否为 QQ 安装根路径？：'$qq_path'"
        return 1
    fi

    if [ -n "$version_file" ]; then
        version=$(grep "$version_file" -e '"curVersion"' | cut -d\" -f4)
        [ -n "$version" ] && _tmp=$(find "$qq_path" -type d -name "$version" 2>/dev/null |grep "versions/${version}$")
        { [ -n "$_tmp" ] && qq_path="$_tmp"; } || \
            log_info "已找到 version 文件，但获取版本目录失败：'$version_file'"
    fi

    _tmp=$(find "$qq_path" -type d -iname 'app_launcher' 2>/dev/null | grep 'app_launcher$')
    [ -n "$_tmp" ] && { echo "${_tmp%/app/app_launcher}"; return 0; }
    log_error "未在 '$qq_path' 找到可用 resources 路径"; return 1;
}

# 拉取 LiteLoaderQQNT
function pull_liteloaderqqnt() {
    local url=$LITELOADERQQNT_URL

    log_info "正在获取最新版本 LiteLoaderQQNT"
    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -oq "$_name" -d "$LITELOADERQQNT_NAME" && return 0
    fi

    log_error "LiteLoaderQQNT 获取失败"
    return 1
}

# 安装 LiteLoaderQQNT 的函数
function install_liteloaderqqnt() {
    local ll_path="$liteloaderqqnt_path"

    # 检测更新
    _tmp="$ll_path/package.json"
    if [ -f "$_tmp" ]; then
        _tmp=$(awk -F\" '/"version"/ {print $4}' "$_tmp")
        [ "$_tmp" = "$LITELOADERQQNT_LASTEST_VERSION" ] && \
            { log_info "LiteLoaderQQNT 已安装，跳过：$_tmp"; return 0; }
        log_info "LiteLoaderQQNT 需更新：$_tmp -> $LITELOADERQQNT_LASTEST_VERSION"
    fi

    pull_liteloaderqqnt || return 1
    log_info "拉取完成，正在安装 LiteLoaderQQNT..."

    # TODO 更好的更新逻辑
    local backup_data_dir="${LITELOADERQQNT_NAME}_bak"
    mkdir -p "$backup_data_dir"
    for _dir in "data" "plugins"; do
        if [ -n "$(ls -A "$ll_path/$_dir" 2>/dev/null)" ]; then
            log_info "正在备份 LiteLoaderQQNT 数据目录：$_dir"
            if ! sync_files "$ll_path/$_dir" "$backup_data_dir/"; then
                log_error "备份失败：$_dir"; return 1
            fi
            log_info "已备份至 '$backup_data_dir/$_dir'"
        fi
    done
    [ -z "$(ls -A "$backup_data_dir" 2>/dev/null)" ] && rm -rf "$backup_data_dir"

    mv "$ll_path" "${ll_path}_bak"
    if ! sync_files "$LITELOADERQQNT_NAME/" "$ll_path"; then
        log_error "移动 LiteLoaderQQNT 到目标目录失败"
        rm -rf "$ll_path"
        mv "${ll_path}_bak" "$ll_path" && log_info "更新失败，已恢复，退出..."
        return 1
    fi

    # 恢复插件和数据
    if [ -d "$backup_data_dir" ]; then
        # 设置数据存储模式
        local restore_dir="$liteloaderqqnt_config"
        [ "$SEPARATE_DATA_MODE" -eq 0 ] || restore_dir="$ll_path"

        if ! sync_files "$backup_data_dir/" "$restore_dir"; then
            log_error "恢复插件数据失败，退出..."
            return 1
        fi
        log_info "已恢复 LiteLoaderQQNT 数据"
    fi
    rm -rf "${ll_path}_bak"
    log_info "LiteLoaderQQNT 安装/更新成功"

    # 修补 resources
    patch_resources || return 1

    local qq_update_dir=(
        "$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/versions"
        "$HOME/Library/Application Support/QQ/versions")

    if [ "$PLATFORM" = "macos" ]; then
        log_info "尝试处理 QQ 热更新"
        for _tmp in "${qq_update_dir[@]}"; do
            qq_res_path=$(get_qq_resources_path "$_tmp") || { log_info "无热更新."; continue; }
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

    log_info "开始处理 $qq_res_path"

    [[ "$LITELOADERQQNT_DIR" =~ ^(qq|appimage)$ ]] && ll_path="./LiteLoaderQQNT"

    # 写入 require(String.raw`*`) 到 *.js 文件
    log_info "正在创建/覆写文件：'$jsfile_path'"
    echo "require(\"${ll_path%/}\");" | $sudo_cmd tee "$jsfile_path" > /dev/null
    log_info "写入成功：'require(\"${ll_path%/}\");'"

    # 检查 package.json 文件是否存在
    local package_json="$qq_res_path/app/package.json"
    [ ! -f "$package_json" ] && { log_error "未找到 package.json ，跳过修改"; return 1; }

    # 修改 package.json 中的 main 字段为 ./app_launcher/launcher.js
    log_info "正在修改文件：$package_json"
    _tmp="$(cat "$package_json")"
    if ! echo "$_tmp" | sed '/"main"/ s#"[^"]*",$#"./app_launcher/'"$jsfile_name"'",#' | $sudo_cmd tee "$package_json" >/dev/null; then
        log_error "修改失败：$package_json"; return 1
    fi
    log_info "修改文件 main 字段成功：'./app_launcher/$jsfile_name'"
}

function install_plugin_store() {
    local url=$PLUGIN_LIST_VIEWER_URL
    local plugins_dir="$liteloaderqqnt_config/plugins"
    local plugin_store_dir="$plugins_dir/list-viewer"
    local plugin_name="插件列表查看"

    log_info "修改 LiteLoaderQQNT 文件夹权限(可能解决部分错误)"
    $sudo_cmd chmod -R 0755 "$liteloaderqqnt_config"

    mkdir -p "$plugins_dir" || return 1

    # 检测更新
    _tmp="$plugin_store_dir/manifest.json"
    if [ -f "$_tmp" ]; then
        _tmp=$(awk -F\" '/"version"/ {print $4}' "$_tmp")
        [ "${_tmp#v}" = "${PLUGIN_LIST_VIEWER_LASTEST_VERSION#v}" ] && \
            { log_info "插件已安装，跳过：$plugin_name ($_tmp)"; return 0; }
        log_info "插件 $plugin_name 需更新：$_tmp -> $PLUGIN_LIST_VIEWER_LASTEST_VERSION"
    fi

    log_info "正在安装最新版本插件：$plugin_name"
    _name=$(basename "$url")
    if download_url "$url" "$_name"; then
        unzip -q "$_name" -d "$plugin_store_dir" && { log_info "插件安装成功：$plugin_name"; return 0; }
    fi

    log_error "插件安装失败，请手动安装：$plugin_name"
    return 1
}

function get_liteloaderqqnt_profile_from_shell_rc() {
    local var_name="LITELOADERQQNT_PROFILE"

    # 获取 shell 配置文件
    shell_rc_file="$HOME/.profile"
    ll_profile_line_perfix="export $var_name="
    case "${SHELL##*/}" in
        zsh)    shell_rc_file="$HOME/.zshrc" ;;
        bash)   shell_rc_file="$HOME/.bashrc" ;;
        fish)   ll_profile_line_perfix="set -gx LITELOADERQQNT_PROFILE "
                shell_rc_file="$(fish -c 'printf $__fish_config_dir')/config.fish" ;;
        *)  log_info "非bash、zsh、fish，将尝试修改 ~/.profile"
            log_info "若不生效，请自行根据 ~/.profile 内新增内容修改 shell 配置" ;;
    esac

    log_info "尝试从 shell(${SHELL##*/}: $shell_rc_file) 获取环境变量: LITELOADERQQNT_PROFILE"
    _tmp=$(sed -n "s/^$ll_profile_line_perfix//gp" "$shell_rc_file" | awk 'END { print }')
    if [ -n "$_tmp" ]; then
        _tmp=$(echo "${_tmp}" | sed 's/^\"//;s/\"$//;s/^'\''//;s/'\''$//')
        existing_ll_profile_value=$(echo "$_tmp"| sed "s#$HOME/#\${HOME}/#;s#^\$HOME/#\${HOME}/#")
        log_info "获取 ${SHELL##*/} 配置中变量 $var_name 成功：\"$existing_ll_profile_value\""
    fi
}

function set_liteloaderqqnt_profile_to_shell_rc() {
    local var_value
    var_value=$(echo "$liteloaderqqnt_config"| sed "s#$HOME/#\${HOME}/#;s#^\$HOME/#\${HOME}/#")
    local var_name="LITELOADERQQNT_PROFILE"
    local MARKER_START="# BEGIN LITELOADERQQNT"
    local MARKER_END="# END LITELOADERQQNT"

    local context="$ll_profile_line_perfix\"$var_value\""
    if grep -q "^$MARKER_START$" "$shell_rc_file" && grep -q "^$MARKER_END$" "$shell_rc_file"; then
        [ "$existing_ll_profile_value" = "$var_value" ] && \
            { log_info "shell ${SHELL##*/} 配置中变量 $var_name 值与当前值一致，跳过更新"; return 0; }

        sed -i "/$MARKER_START/,/$MARKER_END/ {
            /$ll_profile_line_perfix/ s|.*|$context|;
        }" "$shell_rc_file" && \
        log_info "使用运行值更新 $var_name: \"$var_value\""
    else
        context="$MARKER_START\n# 请勿在行内填写任何其他配置\n$context\n$MARKER_END"
        sed -i "/^$ll_profile_line_perfix/d" "$shell_rc_file"
        echo -e "\n$context" >> "$shell_rc_file" || { log_error "变量 $var_name 写出失败"; return 1; }
        log_info "已更新变量 $var_name 至 $shell_rc_file：\"$var_value\""
    fi
}

function install_liteloaderqqnt_with_aur() {
    if [ -f /usr/bin/pacman ]; then
        # AUR 中的代码本身就需要对 GitHub 进行访问，故不添加网络判断了
        if grep -Eq "Arch Linux|ID_LIKE=\"arch\"" /etc/os-release; then
            log_info "检测到系统是 Arch Linux"
            log_info "3 秒后将使用 aur 中的 liteloader-qqnt-bin 进行安装"
            log_info "或按任意键切换传统安装方式"
            read -r -t 3 -n 1 response
            # 检查用户输入是否为空（3 秒内无输入）
            if [[ -z "$response" ]]; then
                log_info "开始使用 aur 安装..."
                if git clone https://aur.archlinux.org/liteloader-qqnt-bin.git; then
                    { cd liteloader-qqnt-bin && makepkg -si; } || { log_error "安装失败"; return 1; }
                fi
            else
                log_info "切换使用传统方式安装"
            fi
        fi
    fi
}

function install_for_flatpak_qq() {
    # 检查 Flatpak 是否安装
    if command -v flatpak &> /dev/null; then
        # 检查是否安装了 Flatpak 版的 QQ
        if flatpak list --app --columns=application | grep -xq "com.qq.QQ"; then
            log_info "检测到 Flatpak 版 QQ 已安装"

            qq_res_path=$(flatpak info --show-location com.qq.QQ)/files/extra/QQ/resources
            liteloaderqqnt_path=$(get_liteloaderqqnt_path "$qq_res_path") || {
                log_error "获取 LiteLoaderQQNT 本体路径失败"
                return 1
            }
            install_liteloaderqqnt || return 1


            # 授予 Flatpak 访问 LiteLoaderQQNT 数据目录的权限
            log_info "授予 Flatpak 版 QQ 对数据目录 $liteloaderqqnt_config 和本体目录 $liteloaderqqnt_path 的访问权限"
            $sudo_cmd flatpak override --user com.qq.QQ --filesystem="$liteloaderqqnt_config"
            $sudo_cmd flatpak override --user com.qq.QQ --filesystem="$liteloaderqqnt_path"

            # 将 LITELOADERQQNT_PROFILE 作为环境变量传递给 Flatpak 版 QQ
            $sudo_cmd flatpak override --user com.qq.QQ --env=LITELOADERQQNT_PROFILE="$liteloaderqqnt_config"

            log_info "设置完成！LiteLoaderQQNT 数据目录：$liteloaderqqnt_config"
        fi
    fi
}

# 获取qq appimage 最新链接
function get_qqnt_appimage_url() {
    [ "${ARCH:-$(uname -m)}" = "x86_64" ] && _arch="x86_64" || _arch="arm64"
    check_url="$(download_url https://im.qq.com/linuxqq/index.shtml -| grep -o 'https://.*linuxQQDownload.js?[^"]*')"
    [ "$check_url" ] && appimage_url=$(download_url "$check_url" -| grep -o 'https://[^,]*AppImage' | grep "$_arch")

    [ -z "$appimage_url" ] && { log_error "获取qq下载链接失败"; return 1; }
    echo "$appimage_url"
}

# 计算 squashfs 偏移值
function calc_appimage_offset() {
    local appimage_file="$1"
    local magic_number="68 73 71 73" #hsqs

    [ ! -f "$appimage_file" ] && { log_error "'$appimage_file' not found!"; return 1; }

    # 查找魔数并计算偏移值
    lineno=$(od -A n -t x1 -v -w4 "$appimage_file" | awk "/^ $magic_number/ {print NR; exit}")
    [ -z "$lineno" ] && { log_error "未找到 squashfs"; return 1; }

    echo "$(( (lineno-1)*4 ))"
}

# 提取 appimage 内容
function extract_appimage() {
    local appimage_file="$1"
    offset=$(calc_appimage_offset "$appimage_file") || return 1
    log_info "squashfs偏移值：$offset"
    output="out.squashfs"
    rm -rf squashfs-root runtime

    log_info "正在写出 runtime 文件：runtime"
    head -c "$offset" "$appimage_file" > runtime || return 1
    log_info "写出成功：runtime"

    log_info "正在写出 squashfs 文件：$output"
    tail -c +"$((offset+1))" "$appimage_file" > "$output" || return 1
    log_info "写出成功：$output"

    log_info "开始提取 squashfs 内容"
    unsquashfs "$output" >/dev/null
    [ ! -d "squashfs-root" ] && { log_error "文件提取失败: $output"; return 1; }
    log_info "文件提取成功：squashfs-root"
    rm "$output" && log_info "临时文件 $output 已移除"
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
        log_info "已添加 LITELOADERQQNT_PROFILE: \"$profile_dir\""
    fi
}

# 重新打包 appimage 文件
function repack_appimage() {
    local appdir="$1"
    local output="$2"
    log_info "正在重新打包"
    mksquashfs "$appdir" tmp.squashfs -root-owned -noappend >/dev/null
    cat "runtime" >> "$output"
    cat "tmp.squashfs" >> "$output"
    rm -rf "tmp.squashfs"
    rm -f "runtime"
    chmod a+x "$output"
    log_info "打包完成：$output"
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

    if [ -z "$APPIMAGE_PATH" ]; then
        download_qq_appimage || return 1
        APPIMAGE_PATH="$appimage_path"
    fi

    _tmp=${APPIMAGE_PATH##*/}
    new_qq_filename="$WORKDIR/${_tmp%%AppImage}_patch-${LITELOADERQQNT_LASTEST_VERSION}.AppImage"

    log_info "正在对 AppImage 文件进行补丁操作: $APPIMAGE_PATH"
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
    *) log_error "不支持的系统？请反馈，退出..."; exit 1 ;;
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
    { log_error "参数处理失败."; exit 1; }
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
        *)  log_error "未知选项 '$1'."; show_help; exit 1 ;;
    esac
done

_tmp="${LITELOADERQQNT_PROFILE:-$DEFAULT_LITELOADERQQNT_CONFIG}"
mkdir -p "$_tmp" || { log_error "LiteLoaderQQNT 数据目录创建失败：$_tmp"; exit 1; }
log_info "LiteLoaderQQNT 数据目录创建成功：$_tmp"
liteloaderqqnt_config=$(realpath "$_tmp")

# 检查是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    log_error "禁止以 root 用户执行此脚本，请使用普通用户执行"
    exit 1
fi

check_dependencies || exit 1

# 创建并切换至临时目录
temp_dir=$(mktemp -d)
cd "$temp_dir" || exit 1
log_info "进入临时目录: $temp_dir"

# 版本检测
_tmp="$(get_github_latest_release "$LITELOADERQQNT_URL")"
LITELOADERQQNT_LASTEST_VERSION=${_tmp:-latest}
_tmp="$(get_github_latest_release "$PLUGIN_LIST_VIEWER_URL")"
PLUGIN_LIST_VIEWER_LASTEST_VERSION=${_tmp:-latest}

log_info "最新 LiteLoaderQQNT: $LITELOADERQQNT_LASTEST_VERSION"
log_info "最新 list-viewer 插件: $PLUGIN_LIST_VIEWER_LASTEST_VERSION"

# patch appimage
[ "$APPIMAGE_MODE" = 0 ] && {
    patch_appimage "$APPIMAGE_PATH" || exit 1
    exit 0
}

elevate_permissions || exit

if [ "$PLATFORM" = "linux" ]; then
    install_liteloaderqqnt_with_aur || exit 1
    install_for_flatpak_qq || exit 1
fi

qq_res_path=$(get_qq_resources_path) && {
    liteloaderqqnt_path=$(get_liteloaderqqnt_path)
    install_liteloaderqqnt || exit 1
}

[ "$PLATFORM" = "linux" ] && {
    get_liteloaderqqnt_profile_from_shell_rc
    set_liteloaderqqnt_profile_to_shell_rc
}

install_plugin_store

log_info "如果安装过程中没有提示发生错误
         但 QQ 设置界面没有 LiteLoaderQQNT
         请检查已安装过的插件
         插件错误会导致 LiteLoaderQQNT 无法正常启动

         打开QQ后会弹出初始化失败，此为正常现象，请按照说明完成后续操作"

log_info "脚本将在 3 秒后退出..."
sleep 3
