# LiteLoaderQQNT_Install
针对 [LiteLoaderQQNT](https://liteloaderqqnt.github.io) 的安装脚本

## 安装方法

windows 运行对应 exe  即可

mac/linux 终端运行对应脚本即可

**window 平台 专门添加 老版本升级检测 ， 自动安装插件商店，自动读取 QQ 路径实现全自动安装 等功能**


## 升级更新

若 LiteLoaderQQNT 更新版本一样可以使用 脚本/exe 升级

不会影响已安装的插件（但会默认启用所有已安装的插件）

## 针对仓库内其他文件的附加说明

install_mac_launchd.sh 是给 macOS 写的设定环境变量的版本

但是由于 macOS 严格的软件沙盒限制，会遇到大量权限问题，**无法正常使用**，仅作为后续研究用

普通用户还请使用 install_mac.sh

## 常见问题

**macOS 遇到 Operation not permitted 请检查是否给予 终端 完全磁盘访问权限 或者 允许 终端想访问其他App的数据。**

软件目前使用 GitHub Action 自动化验证脚本效果

如仍有其他问题或者 bug 欢迎友好反馈


特别鸣谢：

[LiteLoaderQQNT](https://github.com/LiteLoaderQQNT/LiteLoaderQQNT)

windows脚本借用[QQNTFileVerifyPatch](https://github.com/LiteLoaderQQNT/QQNTFileVerifyPatch)项目代码实现修补

附加安装的[插件商店](https://github.com/Night-stars-1/LiteLoaderQQNT-Plugin-Plugin-Store/releases)
