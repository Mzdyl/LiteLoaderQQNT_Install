# LiteLoaderQQNT_Install
针对 LiteLoaderQQNT 的安装脚本

mac/linux 终端运行对应脚本即可

install_mac_launchd.sh 是给 macOS 写的设定环境变量的版本
但是由于 macOS 严格的软件沙盒限制，会遇到大量权限问题，**无法正常使用**，仅作为后续研究用
普通用户还请使用 install_mac.sh

**macOS 遇到 Operation not permitted 请检查是否给予 终端 完全磁盘访问权限 或者 允许 终端想访问其他App的数据。**

windows 下使用 python 运行对应脚本即可

目前对全新安装做了适配，升级安装等情况均做了适配
如有其他问题或者 bug 欢迎友好反馈

特别鸣谢：windows脚本借用[QQNTFileVerifyPatch](https://github.com/LiteLoaderQQNT/QQNTFileVerifyPatch)项目代码实现修补
