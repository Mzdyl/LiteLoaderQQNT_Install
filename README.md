# LiteLoaderQQNT_Install
针对 [LiteLoaderQQNT](https://liteloaderqqnt.github.io) 的安装脚本

同时安装 eee 大佬编写的[插件商店](https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/releases)

## 安装方法

windows 运行对应 exe  即可

mac 终端运行对应脚本即可

linux 在下方选择一条指令运行
```bash
# Stable通道
curl -L "https://github.com/Mzdyl/LiteLoaderQQNT_Install/releases/latest/download/install_linux.sh" | eval $SHELL
# Git通道
curl -L "https://github.com/Mzdyl/LiteLoaderQQNT_Install/raw/main/install_linux_cn.sh" | eval $SHELL
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

**Windows 插件安装后无法读取：删除掉环境变量目录下的config.json**

**Windows 用户请确保使用 已管理员身份运行。**

**macOS 遇到 Operation not permitted 请检查是否给予 终端 完全磁盘访问权限 或者 允许 终端想访问其他App的数据。**

**LiteLoaderQQNT 安装后无法使用插件请自行检测原因或加群交流，本脚本仅负责安装，同时步骤完全遵循官网指南**

**如有[报毒](https://github.com/Mzdyl/LiteLoaderQQNT_Install/issues/20)请自行判断，本代码完全开源，同时发布的exe均由 GitHub Actions 通过 pyinstaller 构建，代码公开可以自行审查**

软件目前使用 GitHub Action 自动化验证脚本效果

如仍有其他问题或者 bug 欢迎友好反馈

**反馈群 : [Telegram](https://t.me/+EKoVlfEI7Ow4MzJl)**


特别鸣谢：

[LiteLoaderQQNT](https://github.com/LiteLoaderQQNT/LiteLoaderQQNT)

windows脚本借用[QQNTFileVerifyPatch](https://github.com/LiteLoaderQQNT/QQNTFileVerifyPatch)项目代码实现修补

附加安装的[插件商店](https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/releases)
