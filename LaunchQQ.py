# coding=utf-8
import os
import sys
import winreg
import subprocess
import traceback
import tkinter as tk
from tkinter import filedialog
import shutil
import json
import re

# 设置标准输出编码为UTF-8
sys.stdout.reconfigure(encoding="utf-8")
subprocess.run("chcp 65001", shell=True)


def get_qq_exe_path():
    """通过文件对话框手动选择 QQ.exe 文件的路径"""
    root = tk.Tk()
    root.withdraw()
    file_path = filedialog.askopenfilename(
        title="选择 QQ.exe 文件", filetypes=[("Executable files", "*.exe")]
    )
    if not file_path:
        raise FileNotFoundError("未选择 QQ.exe 文件。")
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


def patch_package_json(file_path, latest_version):
    """
    修补 package.json 文件，修改 "main" 字段的值。

    :param file_path: QQ.exe 的安装目录路径
    :param latest_version: 最新版本目录名称
    """
    try:
        app_launcher_path = os.path.join(file_path, 'versions', latest_version, 'resources', 'app')
        if not os.path.isdir(app_launcher_path):
            raise FileNotFoundError(f"无法找到 app_launcher 目录: {app_launcher_path}")
            
        os.chdir(app_launcher_path)
        print("开始修补 package.json…")
        package_path = os.path.join(app_launcher_path, "package.json")
        
        if not os.path.isfile(package_path):
            raise FileNotFoundError(f"package.json 文件不存在: {package_path}")
            
        # 备份原文件
        bak_package_path = package_path + ".bak"
        shutil.copyfile(package_path, bak_package_path)
        print(f"已将旧版文件备份为 {bak_package_path}")
        
        with open(package_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
            
        # 修改 "main" 字段的值
        original_main = data.get("main", "")
        data["main"] = r"./app_launcher/index.js"
        
        # 将修改后的内容写回 package.json 文件
        with open(package_path, 'w', encoding='utf-8') as file:
            json.dump(data, file, indent=4, ensure_ascii=False)
            
        print(f'"main" 字段已从 "{original_main}" 修改为: "{data["main"]}"')
    except Exception as e:
        print(f"修补 package.json 时发生错误: {e}")
        traceback.print_exc()


def launch_qq(exe_path):
    """
    启动 QQ.exe，并附加参数 --enable-logging，同时打印启动过程中的输出内容。

    :param exe_path: QQ.exe 的完整路径
    """
    try:
        print(f"正在启动 QQ: {exe_path} --enable-logging")
        
        # 启动 QQ.exe 并附加参数 --enable-logging
        process = subprocess.Popen(
            [exe_path, '--enable-logging'],
            stdout=subprocess.PIPE,  # 捕获标准输出
            stderr=subprocess.PIPE,  # 捕获标准错误
            text=True,               # 以文本模式处理输出
            encoding='utf-8',        # 显式指定编码为 UTF-8
            errors='replace'         # 替换无法解码的字节
        )
        
        # 实时打印标准输出和标准错误
        for stdout_line in iter(process.stdout.readline, ''):
            print(stdout_line, end='')
            
        for stderr_line in iter(process.stderr.readline, ''):
            print(stderr_line, end='', file=sys.stderr)
            
        process.stdout.close()
        process.stderr.close()
        process.wait()
        
        print("QQ 已启动。")
    except Exception as e:
        print(f"启动 QQ 失败: {e}")
        traceback.print_exc()


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


def main():
    try:
        qq_exe_path = get_qq_path()
        file_path = os.path.dirname(qq_exe_path)

        latest_version = get_latest_version(file_path)
        patch_package_json(file_path, latest_version)

        # 启动 QQ.exe
        launch_qq(qq_exe_path)
    
    except Exception as e:
        print(f"发生错误: {e}")
        traceback.print_exc()
        input("按 回车键 退出。")


if __name__ == "__main__":
    main()