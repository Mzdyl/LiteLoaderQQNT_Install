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

def get_file_path():
    root = tk.Tk()
    root.withdraw()
    file_path = filedialog.askdirectory(title="选择 QQ 安装路径")
    return file_path

def main():
    try:
        # 检测是否在 GitHub Actions 中运行
        github_actions = os.getenv("GITHUB_ACTIONS", False)

        # 在 GitHub Actions 中运行时，不需要用户输入路径，使用默认路径
        if github_actions:
            file_path = os.path.abspath("C:\\Program Files\\Tencent\\QQNT")
        else:
            # 不在 GitHub Actions 中运行时，允许用户输入路径
            print("请输入 QQ 安装路径，默认为 C:\\Program Files\\Tencent\\QQNT")
            file_path = get_file_path()
        
        # 如果用户没有输入路径，默认使用默认路径
        if not file_path:
            file_path = r"C:\Program Files\Tencent\QQNT"

        # 修补PE文件
        qq_exe_path = os.path.join(file_path, "QQ.exe")
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

        shutil.move(os.path.join(temp_dir, "LiteLoader", "LiteLoaderQQNT-main"), os.path.join(file_path, "resources", "app"))

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

        # 清理临时文件
        shutil.rmtree(temp_dir)

        # 错误处理
        try:
            subprocess.run(["echo", "test"], check=True, shell=True)
        except subprocess.CalledProcessError:
            print("发生错误，安装失败")
            exit(1)

        # 等待3秒后退出
        time.sleep(3)
        exit(0)

    except Exception as e:
        print(f"An error occurred: {e}")
        input("Press Enter to exit.")

if __name__ == "__main__":
    main()

