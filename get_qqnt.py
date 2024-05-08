from requests import get
from sys import exit, argv

plat = argv[1]
print("plat:%s" % plat)
if plat == "Windowsx64":
    r = get(
        "https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js"
    ).text
    key = "ntDownloadX64Url"
    name = "QQInstaller.exe"
elif plat == "Debianx64":
    r = get(
        "https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxQQDownload.js"
    ).text
    r = r[r.find("x64DownloadUrl") :]
    r = r[: r.find("}")]
    key = "deb"
    name = "LinuxQQ.deb"
elif plat == "Macos":
    r = get(
        "https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/ntQQDownload.js"
    ).text
    key = "downloadUrl"
    name = "QQ.dmg"
else:
    exit(-1)
r = r[r.find(key) :]
r = r[r.find('"') + 1 :]
r = r[r.find('"') + 1 :]
r = r[: r.find('"')]
print("url:%s" % r)
with open(name, "wb") as QQ:
    for chunk in get(r, stream=True).iter_content(chunk_size=4096):
        QQ.write(chunk)
