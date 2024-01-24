import os
import sys
import time
import winreg
import shutil
import struct
import tempfile
import urllib.request
import tkinter as tk
from tkinter import filedialog

# 设置标准输出编码为UTF-8
sys.stdout.reconfigure(encoding='utf-8')

# x64 or x86 signatures and replacements
SIG_X64 = bytes([0x48, 0x89, 0xCE, 0x48, 0x8B, 0x11, 0x4C, 0x8B, 0x41, 0x08, 0x49, 0x29, 0xD0, 0x48, 0x8B, 0x49, 0x18, 0xE8])
FIX_X64 = bytes([0x48, 0x89, 0xCE, 0x48, 0x8B, 0x11, 0x4C, 0x8B, 0x41, 0x08, 0x49, 0x29, 0xD0, 0x48, 0x8B, 0x49, 0x18, 0xB8, 0x01, 0x00, 0x00, 0x00])

SIG_X86 = bytes([0x89, 0xCE, 0x8B, 0x01, 0x8B, 0x49, 0x04, 0x29, 0xC1, 0x51, 0x50, 0xFF, 0x76, 0x0C, 0xE8])
FIX_X86 = bytes([0x89, 0xCE, 0x8B, 0x01, 0x8B, 0x49, 0x04, 0x29, 0xC1, 0x51, 0x50, 0xFF, 0x76, 0x0C, 0xB8, 0x01, 0x00, 0x00, 0x00])

def read_file(file_path):
    with open(file_path, 'rb') as file:
        return bytearray(file.read())

def scan_and_replace(buffer, pattern, replacement):
    index = 0
    while index < len(buffer):
        index = buffer.find(pattern, index)
        if index == -1:
            break
        buffer[index:index+len(replacement)] = replacement
        print(f'Found at 0x{index:08X}')
        index += len(replacement)

def patch_pe_file(file_path):
    try:
        save_path = file_path + ".bak"
        print(f"PE File Path: {file_path}")
        os.rename(file_path, save_path)
        print(f"Backup At: {save_path}")

        pe_file = read_file(save_path)

        if struct.calcsize("P") * 8 == 64:
            scan_and_replace(pe_file, SIG_X64, FIX_X64)
        else:
            scan_and_replace(pe_file, SIG_X86, FIX_X86)

        with open(file_path, 'wb') as output_file:
            output_file.write(pe_file)

        print("Patched!")
    except Exception as e:
        print(f"An error occurred: {e}")
        input("Press Enter to exit.")

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
        print(f"Error reading registry key: {e}")
        return None



def main():
    try:
        # 定义注册表路径和键名
        registry_hive = winreg.HKEY_LOCAL_MACHINE
        registry_subkey = r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ"
        registry_value_name = "UninstallString"

        # 读取 UninstallString 信息
        uninstall_string = read_registry_key(registry_hive, registry_subkey, registry_value_name)
        qq_exe_path = uninstall_string.replace("Uninstall.exe", "QQ.exe")

        if uninstall_string is not None:
            print(f"QQ 的安装目录为: {qq_exe_path}")
        else:
            print("无法读取 QQ 的安装目录，请手动选择.")
            qq_exe_path = get_qq_exe_path()

        file_path = os.path.dirname(qq_exe_path)

        # 检测是否安装过旧版 Liteloader
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

        # 检查备份文件是否存在
        bak_file_path = qq_exe_path + ".bak"
        if os.path.exists(bak_file_path):
            os.remove(bak_file_path)
            print(f"已删除备份文件: {bak_file_path}")
        else:
            print("备份文件不存在，无需删除。")

        # 修补PE文件
        patch_pe_file(qq_exe_path)

        # 获取Windows下的临时目录
        temp_dir = tempfile.gettempdir()
        print(f"临时目录：{temp_dir}")

        # 使用urllib下载最新版本的仓库
        print("正在拉取最新版本的仓库...")
        zip_url = "https://github.com/LiteLoaderQQNT/LiteLoaderQQNT/archive/master.zip"
        zip_path = os.path.join(temp_dir, "LiteLoader.zip")
        urllib.request.urlretrieve(zip_url, zip_path)

        # 解压文件
        shutil.unpack_archive(zip_path, os.path.join(temp_dir, "LiteLoader"))

        # 移动到安装目录
        print("拉取完成，正在安装LiteLoader...")

        # 打印调试信息
        print(f"Moving from: {os.path.join(temp_dir, 'LiteLoader','LiteLoaderQQNT-main')}")
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
        shutil.move(os.path.join(temp_dir, 'LiteLoader', 'LiteLoaderQQNT-main'), os.path.join(file_path, 'resources', 'app'))

        # 复制 LiteLoader_bak 中的插件到新的 LiteLoader 目录
        old_plugins_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak', 'plugins')
        new_plugins_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main')
        if os.path.exists(old_plugins_path):
            shutil.copytree(old_plugins_path, os.path.join(new_plugins_path, "plugins"), dirs_exist_ok=True)
            print("已将 LiteLoader_bak 中旧插件 Plugins 复制到新的 LiteLoader 目录")

        # 复制 LiteLoader_bak 中的数据文件到新的 LiteLoader 目录
        old_data_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak', 'data')
        new_data_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main')
        if os.path.exists(old_data_path):
            shutil.copytree(old_data_path, os.path.join(new_data_path, "data"), dirs_exist_ok=True)
            print("已将 LiteLoader_bak 中旧数据文件 data 复制到新的 LiteLoader 目录")

        # 动态生成目标目录
        app_launcher_path = os.path.join(file_path, "resources", "app", "app_launcher")

        # 进入安装目录
        os.chdir(app_launcher_path)

        # 修改index.js
        print("正在修补index.js...")
        index_path = os.path.join(app_launcher_path, "index.js")
        with open(index_path, "r+") as f:
            content = f.read()
            f.seek(0, 0)
            f.write(f"require('{os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main').replace(os.sep, '/')}');\n" + content)

        print("LiteLoaderQQNT安装完成！接下来进行插件商店安装")

        # 使用urllib下载最新版本的仓库
        print("正在拉取最新版本的插件商店...")
        store_zip_url = "https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/archive/master.zip"
        store_zip_path = os.path.join(temp_dir, "LiteLoaderQQNT-Plugin-Plugin-Store.zip")
        urllib.request.urlretrieve(store_zip_url, store_zip_path)

        # 解压文件
        shutil.unpack_archive(store_zip_path, os.path.join(temp_dir, "LiteLoaderQQNT-Plugin-Plugin-Store"))
        existing_destination_path = os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main', 'plugins', 'LiteLoaderQQNT-Plugin-Plugin-Store-master')
        print(f"Moving from: {os.path.join(temp_dir, 'LiteLoaderQQNT-Plugin-Plugin-Store','LiteLoaderQQNT-Plugin-Plugin-Store-master')}")
        print(f"Moving to: {os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main', 'plugins')}")
        if not os.path.exists(existing_destination_path):
            shutil.move(os.path.join(temp_dir, 'LiteLoaderQQNT-Plugin-Plugin-Store','LiteLoaderQQNT-Plugin-Plugin-Store-master'), os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main', 'plugins'))
        else :
            print("检测到已安装插件商店，不做重新安装")

        # # 清理临时文件
        # shutil.rmtree(temp_dir)

        # # 错误处理
        # try:
        #     subprocess.run(["echo", "test"], check=True, shell=True)
        # except subprocess.CalledProcessError:
        #     print("发生错误，安装失败")
        #     exit(1)



    except Exception as e:
        print(f"An error occurred: {e}")
        input("Press Enter to exit.")

if __name__ == "__main__":
    main()

