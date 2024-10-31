# coding=utf-8
import os
import sys
import time
import json
import ctypes
import winreg
import shutil
import urllib
import struct
import msvcrt
import psutil
import requests
import tempfile
import traceback
import subprocess
import tkinter as tk
from tkinter import filedialog
from concurrent.futures import ThreadPoolExecutor, as_completed

# 当前版本号
current_version = "1.18.1"


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
        "https://gh.xiu2.us.kg",
        "https://dl.ghpig.top",
        "https://gh-proxy.com",
        "https://cors.isteed.cc",
        "https://sciproxy.com",
        "https://github.site",
        "https://github.store",
        "https://github.tmby.shop",
        "https://hub.whtrys.space",
        "https://gh-proxy.ygxz.in",
        "https://gitdl.cn",
        "https://ghp.ci",
        "https://githubfast.com",
        "https://ghproxy.net"
    ]


# 设置标准输出编码为UTF-8
sys.stdout.reconfigure(encoding="utf-8")
subprocess.run("chcp 65001", shell=True)

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
        # 创建备份文件的路径
        backup_path = file_path + ".bak"
        
        # 如果备份文件已存在，覆盖它
        if os.path.exists(backup_path):
            os.remove(backup_path)
#           print(f"已删除旧的备份文件: {backup_path}")
            
        # 创建新的备份
        os.rename(file_path, backup_path)
        print(f"已将原版备份在: {backup_path}")
        
        with open(backup_path, "rb") as file:
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
        latest_url = "https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest"
        response = requests.get(latest_url, timeout=2)
        latest_release = response.url.split('/')[-1]  # 获取重定向后的 URL 中的版本号

        if compare_versions(latest_release, current_version):
            print(f"发现新版本 {latest_release}！")

            # 提示用户是否下载更新
            print("是否要下载更新？输入 'y' 确认，5 秒内未输入则跳过更新。")
            start_time = time.time()
            user_input = None
            while (time.time() - start_time) < 5:
                if msvcrt.kbhit():
                    user_input = msvcrt.getch().decode("utf-8").strip().lower()
                    break

            if user_input == 'y':
                download_url = f"https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/download/{latest_release}/install_windows.exe"
                download_file(download_url, f"install_windows-{latest_release}.exe")
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


def can_connect(url, timeout=2):
    try:
        response = requests.head(url, timeout=timeout)
        return response.status_code >= 200 and response.status_code < 400
    except requests.exceptions.RequestException:
        return False


def install_liteloader(file_path):
    try:
        temp_dir = tempfile.gettempdir()
        download_and_extract_form_release("LiteLoaderQQNT/LiteLoaderQQNT")
#       download_and_extract_from_git("LiteLoaderQQNT/LiteLoaderQQNT")
        print("下载完成，开始安装 LiteLoaderQQNT")

        source_dir = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT")
        destination_dir = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak")

        if os.path.exists(source_dir):
            try:
                os.rename(source_dir, destination_dir)
                print(f"已将旧版备份为: {destination_dir}")
            except Exception as e1:
                print(f"重命名失败，尝试使用 shutil.move() 重命名: {e1}")
                try:
                    time.sleep(1)  # 等待一秒，防止文件被锁定
                    shutil.move(source_dir, destination_dir)
                    print(f"已将旧版备份为: {destination_dir}")
                except Exception as e2:
                    print(f"使用 shutil.move() 重命名失败: {e2}")

#       print(f"移动自: {os.path.join(temp_dir, 'LiteLoaderQQNT')}")
#       print(f"移动到: {source_dir}")

        try:
            shutil.move(os.path.join(temp_dir, "LiteLoaderQQNT"), source_dir)
        except Exception as e1:
            print(f"移动 LiteLoaderQQNT 失败, 尝试再次移动: {e1}")
            time.sleep(1)  # 等待一秒，防止文件被锁定
            try:
                shutil.move(os.path.join(temp_dir, "LiteLoaderQQNT"), source_dir)
            except Exception as e2:
                print(f"再次尝试移动失败: {e2}")

    except Exception as e:
        print(f"安装LL过程发生错误: {e}")


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
            modify_change = countdown_input(f"检测到数据目录为 {lite_loader_profile}，是否修改(y/N): ", 'n')
        else:
            modify_change = countdown_input("检测到未设置 LITELOADERQQNT_PROFILE 环境变量，是否设置环境变量？(Y/n): ")

        if modify_change == 'y':
            print("默认将为你修改为用户目录下 Documents 文件夹内")
            custom_path_choice = countdown_input("是否使用自定义路径？(y/N): ", 'n')
            if custom_path_choice == 'y':
                root = tk.Tk()
                root.withdraw()
                custom_path = filedialog.askdirectory(title="请选择你要设定的 LiteLoaderQQNT 数据文件")
                custom_path = os.path.normpath(custom_path)  # 路径转换
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
            os.environ['ML_LITELOADERQQNT_TEMP'] = lite_loader_profile

            source_dir = os.path.join(os.path.dirname(qq_exe_path), "resources", "app", "LiteLoaderQQNT")
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
            os.path.join(file_path, "resources", "app", "LiteLoaderQQNT")
        ]

        for path in lite_loader_qqnt_paths:
            change_folder_permissions(path, "everyone", "(oi)(ci)(F)")

        # 删除备份文件
        bak_file_path = qq_exe_path + ".bak"
        if os.path.exists(bak_file_path):
            os.remove(bak_file_path)
            print(f"已删除备份文件: {bak_file_path}")
#       else:
#           print("备份文件不存在，无需删除。")

        # 移除旧版备份文件夹
        try:
            shutil.rmtree(os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak"), ignore_errors=True)
        except Exception as e:
            print(f"移除旧版备份失败，尝试再次移除: {e}")
            os.system(f'del "{os.path.join(file_path, "resources", "app", "LiteLoaderQQNT_bak")}" /F')

    except Exception as e:
        print(f"移除旧版备份时发生错误: {e}")


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
            f.write(f"require('{os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT').replace(os.sep, '/')}');\n")
            f.write("require('./launcher.node').load('external_index', module);")
    except Exception as e:
        print(f"修补 index.js 时发生错误: {e}")

        
def create_launcher_js(file_path, version_path, launcher_name="ml_install.js"):
    try:
        # 设置 app_launcher 目录路径
        app_launcher_path = os.path.join(version_path, 'resources', 'app', 'app_launcher')
        os.makedirs(app_launcher_path, exist_ok=True)  # 确保目录存在
        
        # 新建 launcher 文件
        launcher_js_path = os.path.join(app_launcher_path, launcher_name)
        print(f"开始创建 {launcher_js_path}...")
        
        with open(launcher_js_path, "w", encoding="utf-8") as f:
            f.write(f"require(String.raw`{os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT').replace(os.sep, '/')}`);\n")
            
        print(f"已创建 {launcher_name} 文件")
        return launcher_js_path
    
    except Exception as e:
        print(f"创建 launcher 文件时发生错误: {e}")
        return None
    
def patch_package_json(version_path, launcher_name="ml_install.js"):
    try:
        app_launcher_path = os.path.join(version_path, 'resources', 'app')
        print("开始修补 package.json…")
        
        package_path = os.path.join(app_launcher_path, "package.json")
        # 备份原文件
        print("已将旧版文件备份为 package.json.bak ")
        bak_package_path = package_path + ".bak"
        shutil.copyfile(package_path, bak_package_path)
        
        # 读取并修改 package.json
        with open(package_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
            
        # 修改 main 字段的值为新创建的 launcher 文件路径
        data["main"] = f"./app_launcher/{launcher_name}"
        
        # 将修改后的内容写回 package.json 文件
        with open(package_path, 'w', encoding='utf-8') as file:
            json.dump(data, file, indent=4, ensure_ascii=False)
            
        print(f'"main" 字段已修改为: {data["main"]}')
        
    except Exception as e:
        print(f"修补 package.json 时发生错误: {e}")


def patch(file_path):
    try:
        # 获取LITELOADERQQNT_PROFILE和ML_LITELOADERQQNT_TEMP环境变量的值
        lite_loader_profile = os.getenv("LITELOADERQQNT_PROFILE")
        lite_loader_temp = os.getenv("ML_LITELOADERQQNT_TEMP")

        # 如果环境变量不存在，则使用默认路径
        default_path = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT", "plugins")
        if lite_loader_profile:
            plugin_path = os.path.join(lite_loader_profile, "plugins")
        elif lite_loader_temp:
            print(
                "未能检测到LITELOADERQQNT_PROFILE，但检测到安装器临时环境变量，猜测你已设置环境变量，使用安装器临时环境变量")
            plugin_path = os.path.join(lite_loader_temp, "plugins")
        else:
            print("未能检测到LITELOADERQQNT_PROFILE，使用默认路径")
            plugin_path = default_path

        # 检查并创建插件目录
        if not os.path.exists(plugin_path):
            os.makedirs(plugin_path)
            print(f"插件目录 {plugin_path} 不存在，已创建。")

        # 打印或使用 plugin_path 变量
        print(f"你的插件路径是 {plugin_path}")
        print("赋予插件目录和插件数据目录完全控制权(解决部分插件权限问题)")
        change_folder_permissions(plugin_path, "everyone", "(oi)(ci)(F)")
        plugin_data_dir = os.path.join(os.path.dirname(plugin_path), "data")
        change_folder_permissions(plugin_data_dir, "everyone", "(oi)(ci)(F)")

    except Exception as e:
        print(f"发生错误: {e}")
        print(f"大概率不影响安装，安装继续")


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
#       print(f"成功修改文件夹 {folder_path} 的权限。")
    except subprocess.CalledProcessError as e:
        print(f"修改文件夹权限时出错: {e}")


def install_plugin_store(file_path):
    try:
        # 获取LITELOADERQQNT_PROFILE环境变量的值
        lite_loader_profile = os.getenv('LITELOADERQQNT_PROFILE')
        lite_loader_temp = os.getenv("ML_LITELOADERQQNT_TEMP")
        
        if not lite_loader_profile:
            if lite_loader_temp:
                print("未检测到环境变量 LITELOADERQQNT_PROFILE，但检测到安装器临时环境变量，猜测你已设置环境变量，使用安装器临时环境变量")
                plugin_path = os.path.join(lite_loader_temp, 'plugins')
            else:
                print("环境变量 LITELOADERQQNT_PROFILE 未设置，使用默认路径")
                plugin_path = os.path.join(file_path, "resources", "app", "LiteLoaderQQNT", "plugins")
        else:
            plugin_path = os.path.join(lite_loader_profile, 'plugins')
            
        existing_destination_path = os.path.join(plugin_path, 'list-viewer')
        
        temp_dir = tempfile.gettempdir()
        
        if not os.path.exists(existing_destination_path) or not os.path.exists(os.path.join(existing_destination_path, 'main', 'index.js')):
            if not os.path.exists(existing_destination_path):
                os.makedirs(plugin_path, exist_ok=True)
            else:
                print("检测到已安装插件商店可能存在问题，即将重装")
                shutil.rmtree(existing_destination_path)                
            print("更新和安装插件请使用 release 版本")
            print("非 release 版本可能导致 QQ 无法正常启动")
            
            # 下载并解压插件
            download_and_extract_form_release("ltxhhz/LL-plugin-list-viewer")
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


def download_file(url_or_path: str, filepath: str, timeout: int = 10):
    try:
        # 检查是否为本地文件路径
        if os.path.exists(url_or_path):
            print(f"使用本地文件路径: {url_or_path}")
            shutil.copy(url_or_path, filepath)
            return
        elif url_or_path.startswith(('http://', 'https://')):
            download_url = url_or_path if can_connect(url_or_path) else f"{get_working_proxy()}/{url_or_path}"
            print(f"当前使用的下载链接: {download_url}")
            
            # 尝试下载文件
            try:
                # 使用 urlopen 方法来设置超时
                with urllib.request.urlopen(download_url, timeout=timeout) as response:
                    with open(filepath, 'wb') as out_file:
                        out_file.write(response.read())
                return
            except urllib.error.URLError as e:
                print(f"下载失败，错误信息: {e}\n尝试使用代理进行下载")
                proxy = get_working_proxy()
                if proxy:
                    download_url = f"{proxy}/{url_or_path}"
                    print(f"当前使用的下载链接: {download_url}")
                else:
                    raise ValueError("无可用代理")
                    
        else:
            raise ValueError(f"无效的路径或 URL: {url_or_path}")
            
        # 再次尝试下载文件
        with urllib.request.urlopen(download_url, timeout=timeout) as response:
            with open(filepath, 'wb') as out_file:
                out_file.write(response.read())
                
    except Exception as e:
        print(f"下载过程中发生错误: {e}")
        external_data_path = get_external_data_path()
        if external_data_path:
#           print(f"使用内嵌版本，路径{external_data_path}")
            print(f"使用内嵌版本")
            filename = os.path.basename(filepath)
            fallback_path = os.path.join(external_data_path, filename)
            if os.path.exists(fallback_path):
                shutil.copy(fallback_path, filepath)
            else:
                raise ValueError(f"内嵌文件未找到: {fallback_path}")
        else:
            download_url = input("无法访问 GitHub 且无可用代理，请手动输入下载地址或本地文件路径（如 "
                            "https://mirror.ghproxy.com/https://github.com/Mzdyl/LiteLoaderQQNT_Install"
                            "/archive/master.zip 或 C:\\path\\to\\file.zip ）：")
            if not download_url:
                raise ValueError("未提供有效的下载地址或本地文件路径")
            download_file(download_url, filepath)


def get_latest_version(file_path):
    """
    获取最新的版本目录。

    :param file_path: QQ.exe 的安装目录路径
    :return: 最新版本目录名称
    :raises FileNotFoundError: 如果无法找到 versions 目录或版本文件夹
    """
    versions_dir = os.path.join(file_path, 'versions')
    if not os.path.isdir(versions_dir):
        raise FileNotFoundError(f"无法找到 versions 目录: {versions_dir}")
        
    # 获取所有版本目录名称
    version_names = [d for d in os.listdir(versions_dir) if os.path.isdir(os.path.join(versions_dir, d))]
    if not version_names:
        raise FileNotFoundError("在 versions 目录下未找到任何版本文件夹")
        
    # 假设版本号格式为 'x.x.x-xxxxx'，通过排序选择最新版本
    latest_version = sorted(version_names, reverse=True)[0]
    print(f"检测到最新版本目录: {latest_version}")
    
    return latest_version

def download_and_extract_form_release(repos: str):
    temp_dir = tempfile.gettempdir()
#   print(f"临时目录：{temp_dir}")

    cached_names = {
        "ltxhhz/LL-plugin-list-viewer": "list-viewer.zip",
        "LiteLoaderQQNT/LiteLoaderQQNT": "LiteLoaderQQNT.zip"
    }

    if repos not in cached_names:
        print("仓库名称无效")
        return

    filename = cached_names[repos]
    download_url = f"https://github.com/{repos}/releases/latest/download/{filename}"
    zip_path = os.path.join(temp_dir, filename)

    try:
        download_file(download_url, zip_path)
        extract_dir = os.path.join(temp_dir, filename.split(".")[0])
        shutil.unpack_archive(zip_path, extract_dir)
    except Exception as e:
        print(f"下载并解压 {repos} 时发生错误: {e}")

        
        
def download_and_extract_from_git(repos: str):
    temp_dir = tempfile.gettempdir()
    print(f"临时目录：{temp_dir}")
    
    cached_names = {
        "ltxhhz/LL-plugin-list-viewer": "list-viewer.zip",
        "LiteLoaderQQNT/LiteLoaderQQNT": "LiteLoaderQQNT.zip"
    }
    
    if repos not in cached_names:
        print("仓库名称无效")
        return
    
    filename = cached_names[repos]
    git_url = f"https://github.com/{repos}/archive/refs/heads/main.zip"
    zip_path = os.path.join(temp_dir, filename)
    
    try:
        print(f"下载最新 Git 版本的 {repos}")
        download_file(git_url, zip_path)
        extract_dir = os.path.join(temp_dir, filename.split(".")[0])
        shutil.unpack_archive(zip_path, extract_dir)
        for item in os.listdir(extract_dir):
            item_path = os.path.join(extract_dir, item)
            if os.path.isdir(item_path):
                for sub_item in os.listdir(item_path):
                    shutil.move(os.path.join(item_path, sub_item), extract_dir)
                os.rmdir(item_path)
    except Exception as e:
        print(f"Git 版下载并解压 {repos} 时发生错误: {e}")
        raise

    
def get_external_data_path():
    # 兼容 PyInstaller
    if hasattr(sys, '_MEIPASS'):
        return sys._MEIPASS  # PyInstaller 打包后的临时文件路径
    # 兼容 Nuitka，假设资源文件与可执行文件在同一目录
    if getattr(sys, 'frozen', False) and hasattr(sys, 'executable'):
        return os.path.dirname(sys.executable)
    return None


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
            cleanup_old_bak(qq_exe_path)
            setup_environment_and_move_files(qq_exe_path)
        else:
            cleanup_old_bak(qq_exe_path)

        qq_file_size_bytes = os.path.getsize(qq_exe_path)
        qq_file_size_mb = qq_file_size_bytes / (1024 * 1024)
        if qq_file_size_mb < 10:
            print("QQ大小小于 10MB，判断为新版")
            latest_version = get_latest_version(file_path)
            version_path = os.path.join(file_path, "versions", latest_version)
            qq_dll_path = os.path.join(version_path, 'QQNT.dll') 
            create_launcher_js(file_path, version_path)
            patch_package_json(version_path)
        else:
            print("QQ大小大于 10MB，判断为旧版")
            patch_index_js(file_path)
            
        if os.path.exists(os.path.join(file_path, "dbghelp.dll")):
            print("检测到dbghelp.dll，推测你已修补QQ，跳过修补")
        else:
            if qq_file_size_mb < 10:
                patch_pe_file(qq_dll_path) 
            else:
                patch_pe_file(qq_exe_path)
        
        install_liteloader(file_path)
        patch(file_path)

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
    