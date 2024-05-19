# LiteLoaderQQNT_Install
针对 [LiteLoaderQQNT](https://liteloaderqqnt.github.io) 的安装脚本

~~同时安装 eee 大佬编写的[插件商店](https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/releases)，作者不再维护，已经删库~~

## 安装方法

windows 运行对应 exe 即可 [Releases 下载链接](https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest/download/install_windows.exe) 

mac 终端运行对应脚本即可或者


```
# Stable通道
curl -L "https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest/download/install_mac.sh" -o /tmp/install_stable.sh && bash /tmp/install_stable.sh
# Git通道
curl -L "https://github.com/Mzdyl/LiteLoaderQQNT_Install/raw/main/install_mac.sh" -o /tmp/install_git.sh && bash /tmp/install_git.sh
```

linux 在下方选择一条指令运行
```bash
# Stable通道
curl -L "https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest/download/install_linux.sh" -o /tmp/install_stable.sh && bash /tmp/install_stable.sh
# Git通道
curl -L "https://github.com/Mzdyl/LiteLoaderQQNT_Install/raw/main/install_linux.sh" -o /tmp/install_git.sh && bash /tmp/install_git.sh
```

### 测试版

Win 用户可以通过 [Github Action](https://github.com/Mzdyl/LiteLoaderQQNT_Install/actions) 下载最新测试版本

## 版本支持

理论支持 QQNT 桌面端 全架构 全版本

## 升级更新

若 LiteLoaderQQNT 更新版本一样可以使用 脚本/exe 升级

## 针对仓库内其他文件的附加说明

install_mac_launchd.sh 是给 macOS 写的设定环境变量的版本

但是由于 macOS 严格的软件沙盒限制，会遇到大量权限问题，**无法正常使用**，仅作为后续研究用

普通用户还请使用 install_mac.sh

## 常见问题

**Windows 用户请确保使用 已管理员身份运行。**

**macOS 遇到 Operation not permitted 请检查是否给予 终端 完全磁盘访问权限 或者 允许 终端想访问其他App的数据。**

**LiteLoaderQQNT 安装后无法使用插件请自行检测原因或加群交流，本脚本仅负责安装，同时步骤完全遵循官网指南**

**如有[报毒](https://github.com/Mzdyl/LiteLoaderQQNT_Install/issues/20)请自行判断，本代码完全开源，同时发布的exe均由 GitHub Actions 通过 pyinstaller 构建，代码公开可以自行审查**

软件目前使用 GitHub Action 自动化验证脚本效果

如仍有其他问题或者 bug 欢迎友好反馈

**反馈群 : [Telegram](https://t.me/+EKoVlfEI7Ow4MzJl)**

## TODO List

- [x] [repack_appimage.sh](https://github.com/Mzdyl/LiteLoaderQQNT_Install/blob/main/repack_appimage.sh) 添加选择QQ.AppImage路径功能
- [x] [install_linux.sh](https://github.com/Mzdyl/LiteLoaderQQNT_Install/blob/main/install_linux.sh) 更通用环境变量设置以及特殊shell的适配
- [x] [install_linux.sh](https://github.com/Mzdyl/LiteLoaderQQNT_Install/blob/main/install_linux.sh) 添加 Arch Linux 下提示可以使用 aur liteloaderqqnt-bin
- [x] [install_windows.py](https://github.com/Mzdyl/LiteLoaderQQNT_Install/blob/main/install_windows.py) 避免权限问题，如WinError5
- [x] [.github/workflows ](https://github.com/Mzdyl/LiteLoaderQQNT_Install/tree/main/.github/workflows) 更新QQ安装包版本
- [ ] [install_mac.sh](https://github.com/Mzdyl/LiteLoaderQQNT_Install/blob/main/install_mac.sh) 研究如何快速复制 plugins 和 data 文件夹
- [ ] [install_windows.py](https://github.com/Mzdyl/LiteLoaderQQNT_Install/blob/main/install_windows.py) 更新打包方式，替代PyInstaller，避免报毒
## 特别鸣谢：

[LiteLoaderQQNT](https://github.com/LiteLoaderQQNT/LiteLoaderQQNT)

windows脚本借用[QQNTFileVerifyPatch](https://github.com/LiteLoaderQQNT/QQNTFileVerifyPatch)项目代码实现修补

~~附加安装的[插件商店](https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/releases)~~
