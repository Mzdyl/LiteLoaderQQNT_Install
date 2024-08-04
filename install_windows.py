# coding=utf-8
import os
import sys
import ctypes
import time
import winreg
import shutil
import struct
import msvcrt
import psutil
import requests
import tempfile
import traceback
import subprocess
import tkinter as tk
from tkinter import filedialog
from rich.console import Console
from rich.markdown import Markdown
from concurrent.futures import ThreadPoolExecutor, as_completed

# 当前版本号
current_version = "1.14"

# 网络错误或者 api 超限度时使用指定版本号
# 后期使用 github runner 实现每周自动更新固定版本号
liteloader_version = "1.1.2"
list_view_version = "v1.3.5"


# 存储反代服务器的URL
def get_github_proxy_urls():
    return [
        "https://gh.h233.eu.org",
        "https://gh.ddlc.top",
        "https://slink.ltd",
        "https://gh.con.sh",
        "https://cors.isteed.cc",
        "https://hub.gitmirror.com",
        "https://sciproxy.com",
        "https://ghproxy.cc",
        "https://cf.ghproxy.cc",
        "https://www.ghproxy.cc",
        "https://ghproxy.cn",
        "https://www.ghproxy.cn",
        "https://gh.jiasu.in",
        "https://dgithub.xyz",
        "https://download.ixnic.net",
        "https://download.nuaa.cf",
        "https://download.scholar.rr.nu",
        "https://download.yzuu.cf",
        "https://mirror.ghproxy.com",
        "https://ghproxy.net",
        "https://kkgithub.com",
        "https://gitclone.com",
        "https://hub.incept.pw",
        "https://github.moeyy.xyz",
        "https://mirror.ghproxy.com"
    ]


# 设置标准输出编码为UTF-8
sys.stdout.reconfigure(encoding="utf-8")
subprocess.run("chcp 65001")

# x64 or x86 signatures and replacements
SIG_ARM64 = bytes([0x98, 0x01, 0x00, 0x35, 0xB2, 0xED, 0xFF, 0x97])
FIX_ARM64 = bytes([0x98, 0x01, 0x00, 0x35, 0x20, 0x00, 0x80, 0xD2])
SIG_X64 = bytes([0x48, 0x89, 0xCE, 0x48, 0x8B, 0x11, 0x4C, 0x8B, 0x41, 0x08, 0x49, 0x29, 0xD0, 0x48, 0x8B, 0x49, 0x18, 0xE8])
FIX_X64 = bytes([0x48, 0x89, 0xCE, 0x48, 0x8B, 0x11, 0x4C, 0x8B, 0x41, 0x08, 0x49, 0x29, 0xD0, 0x48, 0x8B, 0x49, 0x18, 0xB8, 0x01, 0x00, 0x00, 0x00])
SIG_X86 = bytes([0x89, 0xCE, 0x8B, 0x01, 0x8B, 0x49, 0x04, 0x29, 0xC1, 0x51, 0x50, 0xFF, 0x76, 0x0C, 0xE8])
FIX_X86 = bytes([0x89, 0xCE, 0x8B, 0x01, 0x8B, 0x49, 0x04, 0x29, 0xC1, 0x51, 0x50, 0xFF, 0x76, 0x0C, 0xB8, 0x01, 0x00, 0x00, 0x00])


def scan_and_replace(buffer, pattern, replacement):
    index = 0
    while index < len(buffer):
        index = buffer.find(pattern, index)
        if index == -1:
            break
        buffer[index: index + len(replacement)] = replacement
        print(f"Found at 0x{index:08X}")
        index += len(replacement)

def get_pe_arch(pe_file):
    e_lfanew_offset = 0x3C
    pe_header_offset = struct.unpack("<I", pe_file[e_lfanew_offset:e_lfanew_offset + 4])[0]
    machine_offset = pe_header_offset + 4
    machine = struct.unpack("<H", pe_file[machine_offset:machine_offset + 2])[0]
    return machine

def patch_pe_file(file_path):
    # 存在 64 位系统安装 32 位 QQ 的可能，需考虑
    try:
        save_path = file_path + ".bak"
        os.rename(file_path, save_path)
        print(f"已将原版备份在 : {save_path}")

        with open(save_path, "rb") as file:
            pe_file = bytearray(file.read())

        machine = get_pe_arch(pe_file)
        if machine == 0x8664:  # x64
            scan_and_replace(pe_file, SIG_X64, FIX_X64)
        elif machine == 0x014C:  # x86
            scan_and_replace(pe_file, SIG_X86, FIX_X86)
        elif machine == 0xAA64:  # ARM64
            scan_and_replace(pe_file, SIG_ARM64, FIX_ARM64)

        with open(file_path, "wb") as output_file:
            output_file.write(pe_file)

        print("修补成功!")
    except Exception as e:
        print(f"发生错误: {e}")
        input("按 回车键 退出。")


def get_qq_exe_path():
    root = tk.Tk()
    root.withdraw()
    file_path = filedialog.askopenfilename(
        title="选择 QQ.exe 文件", filetypes=[("Executable files", "*.exe")]
    )
    return file_path


def read_registry_key(hive, subkey, value_name):
    try:
        # 打开指定的注册表项
        key = winreg.OpenKey(hive, subkey)
        # 读取注册表项中指定名称的值
        value, _ = winreg.QueryValueEx(key, value_name)
        # 关闭注册表项
        winreg.CloseKey(key)
        return value
    except Exception as e:
        print(f"注册表读取失败: {e}")
        return None


def compare_versions(version1, version2):
    v1_parts = [int(part) for part in version1.split(".")]
    v2_parts = [int(part) for part in version2.split(".")]

    # 对比版本号的每个部分
    for i in range(max(len(v1_parts), len(v2_parts))):
        v1_part = v1_parts[i] if i < len(v1_parts) else 0
        v2_part = v2_parts[i] if i < len(v2_parts) else 0

        if v1_part < v2_part:
            return False
        elif v1_part > v2_part:
            return True

    return False  # 两个版本号相等


def check_for_updates():
    try:
        # 获取最新版本号
        response = requests.get("https://api.github.com/repos/Mzdyl/LiteLoaderQQNT_Install/releases/latest", timeout=2)
        latest_release = response.json()
        tag_name, body = latest_release["tag_name"], latest_release["body"]

        if compare_versions(tag_name, current_version):
            print(f"发现新版本 {tag_name}！更新日志：\n")
            Console().print(Markdown(body))

            # 提示用户是否下载更新
            print("是否要下载更新？输入 'y' 确认，5 秒内未输入则跳过更新。")
            start_time = time.time()
            user_input = None
            while (time.time() - start_time) < 5:
                if msvcrt.kbhit():
                    user_input = msvcrt.getch().decode("utf-8").strip().lower()
                    break

            if user_input == 'y':
                download_url = f"https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/download/{tag_name}/install_windows.exe"
                download_file(download_url, f"install_windows-{tag_name}.exe")
                print("版本已更新，请重新运行最新脚本。")
                input("按 回车键 退出")
                sys.exit(0)
            else:
                print("跳过更新，继续安装。")
        else:
            print("当前已是最新版本，开始安装。")
    except Exception as e:
        print(f"检查更新阶段发生错误: {e}")
        print("将跳过检查更新，继续安装")


def get_qq_path():
    try:
        hive, subkey, value = winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ", "UninstallString"
        uninstall_string = read_registry_key(hive, subkey, value)

        if not uninstall_string or not os.path.exists(uninstall_string):
            raise FileNotFoundError("无法通过注册表读取 QQNT 的安装目录或路径不存在")

        qq_exe_path = uninstall_string.replace("Uninstall.exe", "QQ.exe")
        print(f"QQNT 的安装目录为: {qq_exe_path}")
    # except FileNotFoundError as e:
    except Exception as e:
        print(e)
        print("请手动选择 QQ.exe 文件 ")
        qq_exe_path = get_qq_exe_path()

    return qq_exe_path


def get_document_path() -> str:
    try:
        # 部分用户是OneDrive 路径，是否有影响
        registry_hive = winreg.HKEY_CURRENT_USER
        registry_subkey = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        registry_value_name = "Personal"

        path = read_registry_key(registry_hive, registry_subkey, registry_value_name)

        if path is None:
            path = os.path.expanduser("~/Documents")

        if path.startswith("%USERPROFILE%"):
            path = path.replace("%USERPROFILE%", os.path.expanduser("~"))

    except Exception as e:
        print(f"获取文档路径失败: {e}")
        path = os.path.expanduser("~/Documents")

    return path


def can_connect_to_github():
    try:
        response = requests.head("https://github.com", timeout=5)
        return response.status_code == 200
    except requests.exceptions.RequestException:
        return False


def install_liteloader(file_path):
    try:
        temp_dir = tempfile.gettempdir()
        download_and_extract_form_release("LiteLoaderQQNT/LiteLoaderQQNT")
        print("下载完成，开始安装 LiteLoaderQQNT")

        source_dir = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT-main")
        destination_dir = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak")

        if os.path.exists(source_dir):
            try:
                os.rename(source_dir, destination_dir)
                print(f"已将旧版重命名为: {destination_dir}")
            except Exception as e1:
                print(f"重命名失败，尝试使用 shutil.move() 重命名: {e1}")
                try:
                    time.sleep(1)  # 等待一秒，防止文件被锁定
                    shutil.move(source_dir, destination_dir)
                    print(f"已将旧版重命名为: {destination_dir}")
                except Exception as e2:
                    print(f"使用 shutil.move() 重命名失败: {e2}")

        print(f"移动自: {os.path.join(temp_dir, 'LiteLoader')}")
        # 历史遗留问题，以前是直接拉取仓库代码，使用了 -main 后缀
        print(f"移动到: {source_dir}")

        try:
            shutil.move(os.path.join(temp_dir, "LiteLoader"), source_dir)
        except Exception as e1:
            print(f"移动 LiteLoaderQQNT 失败, 尝试再次移动: {e1}")
            time.sleep(1)  # 等待一秒，防止文件被锁定
            try:
                shutil.move(os.path.join(temp_dir, "LiteLoader"), source_dir)
            except Exception as e2:
                print(f"再次尝试移动失败: {e2}")

    except Exception as e:
        print(f"安装LL过程发生错误: {e}")


def check_old_version(qq_exe_path):
    # 检测是否安装过旧版 Liteloader
    try:
        file_path = os.path.dirname(qq_exe_path)
        package_file_path = os.path.join(file_path, "resources", "app", "package.json")
        replacement_line = '"main": "./app_launcher/index.js"'
        target_line = '"main": "./LiteLoader"'
        with open(package_file_path, "r") as file:
            content = file.read()

        if target_line in content:
            print("检测到安装过旧版，执行复原 package.json")
            content = content.replace(target_line, replacement_line)
            with open(package_file_path, "w") as file:
                file.write(content)
            print(f"成功替换目标行: {target_line} -> {replacement_line}")
            print("请根据需求自行删除 LiteloaderQQNT 0.x 版本本体以及 LITELOADERQQNT_PROFILE 环境变量以及对应目录")
    except Exception as e:
        print(f"检测是否安装过0.x版本时发生错误: {e}")

def countdown_input(prompt, default='y', timeout=5):
    print(prompt)
    start_time = time.time()
    user_input = None
    while (time.time() - start_time) < timeout:
        if msvcrt.kbhit():
            user_input = msvcrt.getch().decode("utf-8").strip().lower()
            break
    return user_input if user_input else default


def setup_environment_and_move_files(qq_exe_path):
    try:
        lite_loader_profile = os.getenv("LITELOADERQQNT_PROFILE")
        if lite_loader_profile:
            modify_change = countdown_input(f"检测到数据目录为 {lite_loader_profile}，是否修改(y/n): ")
        else:
            modify_change = countdown_input("检测到未设置 LITELOADERQQNT_PROFILE 环境变量，是否设置环境变量？(y/n): ")

        if modify_change == 'y':
            print("默认将为你修改为用户目录下 Documents 文件夹内")
            custom_path_choice = countdown_input("是否使用自定义路径？(y/n): ", 'n')
            if custom_path_choice == 'y':
                root = tk.Tk()
                root.withdraw()
                custom_path = filedialog.askdirectory(title="请选择你要设定的 LiteLoaderQQNT 数据文件")
                custom_path = os.path.normpath(custom_path) # 路径转换
                command = ('setx LITELOADERQQNT_PROFILE "' + custom_path + '"')
            else:
                default_path = get_document_path() + '\\LiteloaderQQNT'
                command = ('setx LITELOADERQQNT_PROFILE "' + default_path + '"')
            os.system(command)
            print("注意，目前版本修改环境变量后需重启电脑 Python 才能检测到")
            print("但不影响 LiteloaderQQNT 正常使用")
            print("接下来尝试检查是否存在旧数据并尝试移动")
            if custom_path_choice == 'y':
                lite_loader_profile = custom_path
            else:
                lite_loader_profile = default_path

            source_dir = os.path.join(os.path.dirname(qq_exe_path), "resources", "app", "LiteLoaderQQNT-main")
            folders = ["plugins", "data"]
            if all(os.path.exists(os.path.join(source_dir, folder)) for folder in folders):
                for folder in folders:
                    source_folder = os.path.join(source_dir, folder)
                    target_folder = os.path.join(lite_loader_profile, folder)
                    if os.path.exists(target_folder):
                        print(f"目标文件夹 {target_folder} 已存在，跳过移动操作。")
                    else:
                        shutil.move(source_folder, target_folder)
                        print(f"成功移动 {folder} 文件夹至 {lite_loader_profile}")
            print(f"你的 LiteloaderQQNT 插件数据目录在 {lite_loader_profile}")
        else:
            print("已取消修改环境变量操作。")
    except Exception as e:
        print(f"检测并修改数据目录时发生错误: {e}")


def cleanup_old_bak(qq_exe_path):
    try:
        file_path = os.path.dirname(qq_exe_path)

        # 访问LiteLoaderQQNT目录并更改目录和文件权限
        lite_loader_qqnt_paths = [
            os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak"),
            os.path.join(file_path, "resources", "app", "LiteLoaderQQNT-main")
        ]

        for path in lite_loader_qqnt_paths:
            change_folder_permissions(path, "everyone", "(oi)(ci)(F)")

        # 删除备份文件
        bak_file_path = qq_exe_path + ".bak"
        if os.path.exists(bak_file_path):
            os.remove(bak_file_path)
            print(f"已删除备份文件: {bak_file_path}")
        else:
            print("备份文件不存在，无需删除。")

        # 移除旧版备份文件夹
        try:
            shutil.rmtree(os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak"), ignore_errors=True)
        except Exception as e:
            print(f"移除旧版备份失败，尝试再次移除: {e}")
            os.system(f'del "{os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak")}" /F')

    except Exception as e:
        print(f"移除旧版备份时发生错误: {e}")


def prepare_for_installation(qq_exe_path):
    check_old_version(qq_exe_path)
    cleanup_old_bak(qq_exe_path)
    setup_environment_and_move_files(qq_exe_path)


def copy_old_files(file_path):
    old_plugins_path = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak", "plugins")
    new_liteloader_path = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT-main")
    # 复制 LiteLoader_bak 中的插件到新的 LiteLoader 目录
    if os.path.exists(old_plugins_path):
        shutil.copytree(
            old_plugins_path,
            os.path.join(new_liteloader_path, "plugins"),
            dirs_exist_ok=True,
        )
        print("已将 LiteLoader_bak 中旧插件 Plugins 复制到新的 LiteLoader 目录")
    # 复制 LiteLoader_bak 中的数据文件到新的 LiteLoader 目录
    old_data_path = os.path.join(
        file_path, "resources", "app", "LiteLoaderQQNT_bak", "data"
    )
    if os.path.exists(old_data_path):
        shutil.copytree(
            old_data_path, os.path.join(new_liteloader_path, "data"), dirs_exist_ok=True
        )
        print("已将 LiteLoader_bak 中旧数据文件 data 复制到新的 LiteLoader 目录")


def patch_index_js(file_path):
    try:
        app_launcher_path = os.path.join(file_path, "resources", "app", "app_launcher")
        os.chdir(app_launcher_path)
        print("开始修补 index.js…")
        index_path = os.path.join(app_launcher_path, "index.js")
        # 备份原文件
        print("已将旧版文件备份为 index.js.bak ")
        bak_index_path = index_path + ".bak"
        shutil.copyfile(index_path, bak_index_path)
        with open(index_path, "w", encoding="utf-8") as f:
            f.write(f"require('{os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main').replace(os.sep, '/')}');\n")
            f.write("require('./launcher.node').load('external_index', module);")
    except Exception as e:
        print(f"修补 index.js 时发生错误: {e}")


def patch(file_path):
    try:
        # 获取LITELOADERQQNT_PROFILE环境变量的值
        lite_loader_profile = os.getenv("LITELOADERQQNT_PROFILE")

        # 如果环境变量不存在，则使用默认路径
        default_path = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT-main", "plugins")
        plugin_path = (
            os.path.join(lite_loader_profile, "plugins")
            if lite_loader_profile
            else default_path
        )

        # 打印或使用 plugin_path 变量
        print(f"你的插件路径是 {plugin_path}")
        print("赋予插件目录和插件数据目录完全控制权(解决部分插件权限问题)")
        change_folder_permissions(plugin_path, "everyone", "(oi)(ci)(F)")
        plugin_data_dir = os.path.join(os.path.dirname(plugin_path), "data")
        change_folder_permissions(plugin_data_dir, "everyone", "(oi)(ci)(F)")
    except Exception as e:
        print(f"发生错误: {e}")


def check_and_kill_qq(process_name):
    try:
        for proc in psutil.process_iter():
            # 检查进程是否与指定的名称匹配
            if proc.name() == process_name:
                print(f"找到进程 {process_name}，将于3秒后尝试关闭...")
                time.sleep(3)
                proc.kill()
                print(f"进程 {process_name} 已关闭。")
    except Exception as e:
        print(f"关闭进程 {process_name} 时发生: {e}，无影响，继续执行")


def change_folder_permissions(folder_path, user, permissions):
    try:
        cmd = ["icacls", folder_path, "/grant", f"{user}:{permissions}", "/t"]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
        print(f"成功修改文件夹 {folder_path} 的权限。")
    except subprocess.CalledProcessError as e:
        print(f"修改文件夹权限时出错: {e}")


def install_plugin_store(file_path):
    try:
        temp_dir = tempfile.gettempdir()
        download_and_extract_form_release("ltxhhz/LL-plugin-list-viewer")
        # 获取LITELOADERQQNT_PROFILE环境变量的值
        lite_loader_profile = os.getenv('LITELOADERQQNT_PROFILE')
        if not lite_loader_profile:
            print("环境变量 LITELOADERQQNT_PROFILE 未设置")
            plugin_path = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT-main", "plugins")
        else:
            plugin_path = os.path.join(lite_loader_profile, 'plugins')
        existing_destination_path = os.path.join(plugin_path, 'list-viewer')

        if not os.path.exists(existing_destination_path):
            # 创建目标文件夹
            os.makedirs(plugin_path, exist_ok=True)
            print(f"移动自: {os.path.join(temp_dir, 'list-viewer')}")
            print(f"移动到: {existing_destination_path}")
            shutil.move(os.path.join(temp_dir, "list-viewer"), plugin_path)
        else:
            print("检测到已安装插件商店，不再重新安装")
    except Exception as e:
        print(f"安装插件商店发生错误: {e}\n请尝试手动安装")


def check_proxy(proxy):
    try:
        proxy_url = f"{proxy}/https://github.com"
        response = requests.head(proxy_url, timeout=5)
        if response.ok:
            return proxy
    except requests.exceptions.RequestException:
        pass
    return None


def get_working_proxy():
    proxies = get_github_proxy_urls()
    with ThreadPoolExecutor(max_workers=len(proxies)) as executor:
        future_to_proxy = {executor.submit(check_proxy, proxy): proxy for proxy in proxies}
        for future in as_completed(future_to_proxy):
            result = future.result()
            if result is not None:
                return result
    return None


def download_file(url: str, filename: str):
    def download(url: str, filename: str):
        try:
            with open(filename, "wb") as file:
                response = requests.get(url, timeout=10, stream=True)
                for chunk in response.iter_content(chunk_size=4096):
                    file.write(chunk)
        except requests.RequestException as e:
            raise Exception(f"下载 {url} 失败: {e}")
    try:
        try:
            if os.path.exists(url):
                # 本地文件
                print(f"内嵌文件路径{url}")
                shutil.copy(url, filename)
                return
        except OSError as e:
            raise Exception(f"处理本地文件 {url} 失败: {e}")
        if can_connect_to_github():
            print("网络良好，直连下载")
            download_url = url
        else:
            proxy = get_working_proxy()
            if proxy:
                download_url = f"{proxy}/{url}"
                print(f"当前使用的下载链接 {download_url}")
            else:
                raise ValueError
        download(download_url, filename)
    except Exception:
        download_url = input("无法访问 GitHub 且无可用代理，请手动输入下载地址或本地文件路径（如 "
                            "https://mirror.ghproxy.com/https://github.com/Mzdyl/LiteLoaderQQNT_Install"
                            "/archive/master.zip 或 C:\\path\\to\\file.zip ）：")
        if not download_url:
            raise ValueError("没有输入有效的下载地址或本地文件路径")
        download(download_url, filename)


def download_and_extract_form_release(repos: str):
    temp_dir = tempfile.gettempdir()
    print(f"临时目录：{temp_dir}")

    try:
        response = requests.get(f"https://api.github.com/repos/{repos}/releases/latest", timeout=3)
        response.raise_for_status()
        latest_release = response.json()
        assets = latest_release.get("assets", [])
        download_url = assets[0].get("browser_download_url") if assets else None
        if not download_url:
            raise ValueError("未找到有效的下载链接")
    except (requests.RequestException, ValueError) as e:
        cached_names = {
            "ltxhhz/LL-plugin-list-viewer": "list-viewer.zip",
            "LiteLoaderQQNT/LiteLoaderQQNT": "LiteLoaderQQNT.zip"
            }
        if get_external_data_path():
            print("使用内嵌版本")
            filename = cached_names[repos]
            download_url= os.path.join(get_external_data_path(), filename)
        else:
            print(f"获取最新版本信息失败: {e}")
            print("使用缓存下载链接")

            versions = {
                "ltxhhz/LL-plugin-list-viewer": list_view_version,
                "LiteLoaderQQNT/LiteLoaderQQNT": liteloader_version
            }

            if repos not in cached_names:
                print("发生错误")
                return

            filename = cached_names[repos]
            version = versions[repos]
            download_url = f"https://github.com/{repos}/releases/download/{version}/{filename}"

    zip_name = "list-viewer.zip" if repos == "ltxhhz/LL-plugin-list-viewer" else "LiteLoader.zip"
    zip_path = os.path.join(temp_dir, zip_name)
    download_file(download_url, zip_path)

    try:
        extract_dir = os.path.join(temp_dir, zip_name.split(".")[0])
        shutil.unpack_archive(zip_path, extract_dir)
    except shutil.ReadError as e:
        print(f"解压文件失败: {e}")


def get_external_data_path():
    if hasattr(sys, '_MEIPASS'):
        # If running in a PyInstaller bundle
        base_path = sys._MEIPASS
        return os.path.join(base_path)


def main():
    try:
        # 检测是否在 GitHub Actions 中运行
        github_actions = os.getenv("GITHUB_ACTIONS", False)

        if not ctypes.windll.shell32.IsUserAnAdmin():
            print("推荐使用管理员运行")

        qq_exe_path = get_qq_path()
        file_path = os.path.dirname(qq_exe_path)

        skip_update_file = os.path.join(file_path, "SKIP_UPDATE")
        if os.path.exists(skip_update_file):
            print("检测到 SKIP_UPDATE 文件，跳过更新")
        else:
            check_for_updates()

        check_and_kill_qq("QQ.exe")
        if not github_actions:
            prepare_for_installation(qq_exe_path)
        else:
            cleanup_old_bak(qq_exe_path)

        if os.path.exists(os.path.join(file_path, "dbghelp.dll")):
            print("检测到dbghelp.dll，推测你已修补QQ，跳过修补")
        else:
            patch_pe_file(qq_exe_path)
        install_liteloader(file_path)
        # copy_old_files(file_path)
        patch_index_js(file_path)
        patch(file_path)

        # print("LiteLoaderQQNT 安装完成！插件商店作者不维护删库了，安装到此结束")
        print("LiteLoaderQQNT 安装完成！接下来进行插件列表安装")
        install_plugin_store(file_path)

        if not github_actions:
            print("如果安装过程中没有提示发生错误")
            print("但 QQ 设置界面没有 LiteLoaderQQNT")
            print("请检查已安装过的插件")
            print("插件错误会导致 LiteLoaderQQNT 无法正常启动")

            print("按 回车键 退出…")
            input("如有问题请截图安装界面反馈")

    except Exception as e:
        print(f"发生错误: {e}")
        print(traceback.format_exc())
        input("按 回车键 退出。")


if __name__ == "__main__":
    main()
    
