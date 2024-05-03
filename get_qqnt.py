from requests import get
plat=input()
if plat=='Windows':
    url='https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js'
    key='"ntDownloadX64Url"'
    name='QQInstaller.exe'
elif plat=='Linux':
    pass
elif plat=='Macos':
    pass
else:
    exit(-1)
r=get(url).text
r=r[r.find(key):]
r=r[r.find('"'):]
with open(name,'wb') as QQ:
    QQ.write(get(r[1:r.find('"')],stream=True).content)
