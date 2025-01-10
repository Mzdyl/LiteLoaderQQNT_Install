from requests import get
from sys import exit, argv
from os import mkdir
from os.path import join as pjoin,isfile,isdir
from shutil import copyfile

# index2cdnjs
def get1(r):
    r = get(r).text
    r = r[r.find("var rainbowConfigUrl") :]
    r = r[r.find('"') + 1 :]
    r = r[: r.find('"')]
    return r


# content2link
def get2(r, key):
    r = r[r.find(key) :]
    r = r[r.find('"') + 1 :]
    r = r[r.find('"') + 1 :]
    r = r[: r.find('"')]
    return r


# get plat
plat = argv[1]
print("plat:%s" % plat)

# get link
if plat == "Windowsx64":
    r = get2(
        get(get1("https://im.qq.com/pcqq/index.shtml")).text,
        "ntDownloadX64Url",
    )
    name = "QQInstaller.exe"
elif plat == "Debianx64":
    r = get(get1("https://im.qq.com/linuxqq/index.shtml")).text
    r = r[r.find("x64DownloadUrl") :]
    r = get2(r[: r.find("}")], "deb")
    name = "LinuxQQ.deb"
elif plat == "Macos":
    r = get2(
        get(get1("https://im.qq.com/macqq/index.shtml")).text,
        "downloadUrl",
    )
    name = "QQ.dmg"
elif plat == "AppImage":
    r = get(get1("https://im.qq.com/linuxqq/index.shtml")).text
    r = r[r.find("x64DownloadUrl") :]
    r = get2(r[: r.find("}")], "appimage")
    name = "QQ.AppImage"
else:
    exit(-1)
print("url:%s" % r)

# download
p=pjoin("QQ",name)
if not isfile(p):
    if not isdir("QQ"):
        mkdir("QQ")
    with open(p, "wb") as QQ:
        for chunk in get(r, stream=True).iter_content(chunk_size=4096):
            QQ.write(chunk)
copyfile(p,'.')