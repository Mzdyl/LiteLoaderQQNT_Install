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

        # 启动 QQ.exe
        launch_qq(qq_exe_path)
    
    except Exception as e:
        print(f"发生错误: {e}")
        traceback.print_exc()
        input("按 回车键 退出。")


if __name__ == "__main__":
    main()