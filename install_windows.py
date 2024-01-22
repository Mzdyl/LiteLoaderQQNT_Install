import os
import subprocess
import time
import shutil
import struct
import tempfile
import urllib.request
import sys
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

def main():
    try:
        # 检测是否在 GitHub Actions 中运行
        github_actions = os.getenv("GITHUB_ACTIONS", False)

        # 在 GitHub Actions 中运行时，不需要用户输入路径，使用默认路径
        if github_actions:
            file_path = os.path.abspath("C:\\Program Files\\Tencent\\QQNT")
            qq_exe_path = os.path.join(file_path, "QQ.exe")
        else:
            # 不在 GitHub Actions 中运行时，允许用户输入路径
            print("请选择 QQ.exe 文件，默认路径为 C:\\Program Files\\Tencent\\QQNT\\QQ.exe")
            qq_exe_path = get_qq_exe_path()
            file_path = os.path.dirname(qq_exe_path)
        # 移除上次备份文件
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

        # 重命名目标路径
        os.rename(os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main'), os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT_bak'))

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

        # 修改index.json
        print("正在修补index.json...")
        index_path = os.path.join(app_launcher_path, "index.js")
        with open(index_path, "r+") as f:
            content = f.read()
            f.seek(0, 0)
            f.write(f"require('{os.path.join(file_path, 'resources', 'app', 'LiteLoaderQQNT-main').replace(os.sep, '/')}');\n" + content)


        print("安装完成！脚本将在3秒后退出...")

        # # 清理临时文件
        # shutil.rmtree(temp_dir)

        # # 错误处理
        # try:
        #     subprocess.run(["echo", "test"], check=True, shell=True)
        # except subprocess.CalledProcessError:
        #     print("发生错误，安装失败")
        #     exit(1)

        # 等待3秒后退出
        time.sleep(3)
        exit(0)

    except Exception as e:
        print(f"An error occurred: {e}")
        input("Press Enter to exit.")

if __name__ == "__main__":
    main()

