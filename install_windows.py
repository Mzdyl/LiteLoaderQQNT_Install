import os
import sys
import winreg
import shutil
import struct
import requests
import tempfile
import urllib.request
import tkinter as tk
from tkinter import filedialog
from rich.console import Console
from rich.markdown import Markdown

# 当前版本号
current_version = "1.7"

# 存储反代服务器的URL
PROXY_URL = 'https://mirror.ghproxy.com/'

# 设置标准输出编码为UTF-8
sys.stdout.reconfigure(encoding='utf-8')

# x64 or x86 signatures and replacements
SIG_X64 = bytes(
    [0x48, 0x89, 0xCE, 0x48, 0x8B, 0x11, 0x4C, 0x8B, 0x41, 0x08, 0x49, 0x29, 0xD0, 0x48, 0x8B, 0x49, 0x18, 0xE8])
FIX_X64 = bytes(
    [0x48, 0x89, 0xCE, 0x48, 0x8B, 0x11, 0x4C, 0x8B, 0x41, 0x08, 0x49, 0x29, 0xD0, 0x48, 0x8B, 0x49, 0x18, 0xB8, 0x01,
     0x00, 0x00, 0x00])

SIG_X86 = bytes([0x89, 0xCE, 0x8B, 0x01, 0x8B, 0x49, 0x04, 0x29, 0xC1, 0x51, 0x50, 0xFF, 0x76, 0x0C, 0xE8])
FIX_X86 = bytes(
    [0x89, 0xCE, 0x8B, 0x01, 0x8B, 0x49, 0x04, 0x29, 0xC1, 0x51, 0x50, 0xFF, 0x76, 0x0C, 0xB8, 0x01, 0x00, 0x00, 0x00])


def read_file(file_path):
    with open(file_path, 'rb') as file:
        return bytearray(file.read())


def scan_and_replace(buffer, pattern, replacement):
    index = 0
    while index < len(buffer):
        index = buffer.find(pattern, index)
        if index == -1:
            break
        buffer[index:index + len(replacement)] = replacement
        print(f'Found at 0x{index:08X}')
        index += len(replacement)


def patch_pe_file(file_path):
    try:
        save_path = file_path + ".bak"
        os.rename(file_path, save_path)
        print(f"已将原版备份在 : {save_path}")

        pe_file = read_file(save_path)

        if struct.calcsize("P") * 8 == 64:
            scan_and_replace(pe_file, SIG_X64, FIX_X64)
        else:
            scan_and_replace(pe_file, SIG_X86, FIX_X86)

        with open(file_path, 'wb') as output_file:
            output_file.write(pe_file)

        print("修补成功!")
    except Exception as e:
        print(f"发生错误: {e}")
        input("按 任意键 退出。")


def get_qq_exe_path():
    root = tk.Tk()
    root.withdraw()
    file_path = filedialog.askopenfilename(title="选择 QQ.exe 文件", filetypes=[("Executable files", "*.exe")])
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


def check_for_updates():
    try:
        # 获取最新版本号
        response = requests.get("https://api.github.com/repos/Mzdyl/LiteLoaderQQNT_Install/releases/latest")
        latest_release = response.json()
        tag_name = latest_release['tag_name']
        body = latest_release['body']
        if tag_name > current_version:
            print(f"发现新版本 {tag_name}！")
            print(f"更新日志：\n ")
            console = Console()
            markdown = Markdown(body)
            console.print(markdown)
            download_url = (
                f"https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/download/{tag_name}/install_windows.exe")
            urllib.request.urlretrieve(download_url, f"install_windows-{tag_name}.exe")
            print("版本号已更新。")
            print("请重新运行脚本。")
            sys.exit(0)
        else:
            print("当前已是最新版本，开始安装。")
    except Exception as e:
        print(f"检查更新阶段发生错误: {e}")


def get_qq_path():
    # 定义注册表路径和键名
    registry_hive = winreg.HKEY_LOCAL_MACHINE
    registry_subkey = r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ"
    registry_value_name = "UninstallString"

    # 读取 UninstallString 信息
    uninstall_string = read_registry_key(registry_hive, registry_subkey, registry_value_name)

    if os.path.exists(uninstall_string):
        qq_exe_path = uninstall_string.replace("Uninstall.exe", "QQ.exe")
        print(f"QQNT 的安装目录为: {qq_exe_path}")
    else:
        print("无法读取 QQNT 的安装目录，请手动选择.")
        qq_exe_path = get_qq_exe_path()

    return qq_exe_path


def can_connect_to_github():
    try:
        response = requests.get('https://github.com', timeout=5)
        return response.status_code == 200
    except requests.exceptions.RequestException:
        return False


def download_file(url, filename, proxy_url=None):
    if not can_connect_to_github() and proxy_url:
        proxy_url = proxy_url + url  # 将代理地址和要下载的文件 URL 拼接在一起
        response = requests.get(proxy_url)
    else:
        response = requests.get(url)

    with open(filename, 'wb') as file:
        file.write(response.content)


def download_and_install_liteloader(file_path):
    # 获取Windows下的临时目录
    temp_dir = tempfile.gettempdir()
    print(f"临时目录：{temp_dir}")

    # 使用urllib下载最新版本的仓库
    print("正在拉取最新版本的仓库…")
    zip_url = "https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/archive/master.zip"
    zip_path = os.path.join(temp_dir, "LiteLoader.zip")
    download_file(zip_url, zip_path, PROXY_URL)

    # 解压文件
    shutil.unpack_archive(zip_path, os.path.join(temp_dir, "LiteLoader"))

    # 移动到安装目录
    print("拉取完成，正在安装 LiteLoaderQQNT")

    # 打印调试信息
    print(f"Moving from: {os.path.join(temp_dir, 'LiteLoader', 'LiteLoaderQQNT-main')}")
    print(f"Moving to: {os.path.join(file_path, 'resources', 'app')}")

    # 移除目标路径及其内容
    shutil.rmtree(os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak'), ignore_errors=True)

    # 检查目标目录是否存在
    source_dir = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main')
    destination_dir = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak')

    if os.path.exists(source_dir):
        # 重命名目录
        os.rename(source_dir, destination_dir)
        print(f"已将旧版重命名为: {destination_dir}")
    else:
        print(f" {source_dir} 不存在，全新安装。")

    # 使用 shutil.move 移动文件
    shutil.move(os.path.join(temp_dir, 'LiteLoader', 'LiteLoaderQQNT-main'),
                os.path.join(file_path, 'resources', 'app'))


def download_and_install_plugin_store(file_path):
    # 获取Windows下的临时目录
    temp_dir = tempfile.gettempdir()
    print(f"临时目录：{temp_dir}")

    # 使用urllib下载最新版本的仓库
    print("正在拉取最新版本的插件商店…")
    store_zip_url = "https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/archive/master.zip"
    store_zip_path = os.path.join(temp_dir, "LiteLoaderQQNT-Plugin-Plugin-Store.zip")
    download_file(store_zip_url, store_zip_path, PROXY_URL)
    # 解压文件
    shutil.unpack_archive(store_zip_path, os.path.join(temp_dir, "LiteLoaderQQNT-Plugin-Plugin-Store"))

    # 获取LITELOADERQQNT_PROFILE环境变量的值
    lite_loader_profile = os.getenv('LITELOADERQQNT_PROFILE')

    # 如果环境变量不存在，则使用默认路径
    default_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main', 'plugins')
    plugin_path = os.path.join(lite_loader_profile, 'plugins') if lite_loader_profile else default_path

    existing_destination_path1 = os.path.join(plugin_path, 'LiteLoaderQQNT-Plugin-Plugin-Store-master')
    existing_destination_path2 = os.path.join(plugin_path, 'pluginStore')

    # 打印或使用 plugin_path 变量
    print(f"你的插件路径是 {plugin_path}")

    if not os.path.exists(existing_destination_path1) and not os.path.exists(existing_destination_path2):
        # 创建目标文件夹
        os.makedirs(os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main', 'plugins'), exist_ok=True)
        print(
            f"Moving from: {os.path.join(temp_dir, 'LiteLoaderQQNT-Plugin-Plugin-Store', 'LiteLoaderQQNT-Plugin-Plugin-Store-master')}")
        print(f"Moving to: {existing_destination_path2}")
        shutil.move(
            os.path.join(temp_dir, 'LiteLoaderQQNT-Plugin-Plugin-Store', 'LiteLoaderQQNT-Plugin-Plugin-Store-master'),
            plugin_path)
        # 重命名移动后的目录
        os.rename(os.path.join(plugin_path, 'LiteLoaderQQNT-Plugin-Plugin-Store-master'), os.path.join(plugin_path, 'pluginStore'))
    else:
        print("检测到已安装插件商店，不再重新安装")


def prepare_for_installation(qq_exe_path):
    # 检测是否安装过旧版 Liteloader
    file_path = os.path.dirname(qq_exe_path)
    package_file_path = os.path.join(file_path, 'resources', 'app', 'package.json')
    replacement_line = '"main": "./app_launcher/index.js"'
    target_line = '"main": "./LiteLoader"'
    with open(package_file_path, 'r') as file:
        content = file.read()
    if target_line in content:
        print("检测到安装过旧版，执行复原")
        content = content.replace(target_line, replacement_line)
        with open(package_file_path, 'w') as file:
            file.write(content)
        print(f"成功替换目标行: {target_line} -> {replacement_line}")
    else:
        print(f"未安装过旧版，全新安装")

    bak_file_path = qq_exe_path + ".bak"
    if os.path.exists(bak_file_path):
        os.remove(bak_file_path)
        print(f"已删除备份文件: {bak_file_path}")
    else:
        print("备份文件不存在，无需删除。")


def copy_old_files(file_path):
    old_plugins_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak', 'plugins')
    new_liteloader_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main')
    # 复制 LiteLoader_bak 中的插件到新的 LiteLoader 目录
    if os.path.exists(old_plugins_path):
        shutil.copytree(old_plugins_path, os.path.join(new_liteloader_path, "plugins"), dirs_exist_ok=True)
        print("已将 LiteLoader_bak 中旧插件 Plugins 复制到新的 LiteLoader 目录")
        old_config_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak')
        # 复制 LiteLoader_bak 中的 config.json 文件到新的 LiteLoader 目录
        shutil.copy(os.path.join(old_config_path, 'config.json'), os.path.join(new_liteloader_path, 'config.json'))
        print("已将 LiteLoader_bak 中旧 config.json 复制到新的 LiteLoader 目录")
    # 复制 LiteLoader_bak 中的数据文件到新的 LiteLoader 目录
    old_data_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak', 'data')
    if os.path.exists(old_data_path):
        shutil.copytree(old_data_path, os.path.join(new_liteloader_path, "data"), dirs_exist_ok=True)
        print("已将 LiteLoader_bak 中旧数据文件 data 复制到新的 LiteLoader 目录")


def patch_index_js(file_path):
    app_launcher_path = os.path.join(file_path, "resources", "app", "app_launcher")
    os.chdir(app_launcher_path)
    print("正在修补 index.js…")
    index_path = os.path.join(app_launcher_path, "index.js")
    with open(index_path, "r+", encoding='utf-8') as f:
        content = f.read()
        f.seek(0, 0)
        f.write(
            f"require('{os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main').replace(os.sep, '/')}');\n" + content)


def main():
    try:
        check_for_updates()
        qq_exe_path = get_qq_path()
        file_path = os.path.dirname(qq_exe_path)
        prepare_for_installation(qq_exe_path)
        patch_pe_file(qq_exe_path)
        download_and_install_liteloader(file_path)
        copy_old_files(file_path)
        patch_index_js(file_path)
        print("LiteLoaderQQNT 安装完成！接下来进行插件商店安装")
        download_and_install_plugin_store(file_path)
        # # 清理临时文件
        # shutil.rmtree(temp_dir)

        # # 错误处理
        # try:
        #     subprocess.run(["echo", "test"], check=True, shell=True)
        # except subprocess.CalledProcessError:
        #     print("发生错误，安装失败")
        #     exit(1)

        # 检测是否在 GitHub Actions 中运行
        github_actions = os.getenv("GITHUB_ACTIONS", False)

        if not github_actions:
            print("安装完毕，按 回车键 退出…")
            input("如有问题请截图安装界面反馈")

    except Exception as e:
        print(f"发生错误: {e}")
        input("按 任意键 退出。")


if __name__ == "__main__":
    main()
