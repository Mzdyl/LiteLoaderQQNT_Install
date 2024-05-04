from requests import get
r=get('https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js').text
r=r[r.find('ntDownloadX64Url'):]
r=r[r.find('"')+1:]
r=r[r.find('"')+1:]
with open('QQInstaller.exe','wb') as QQ:
    for chunk in get(r[:r.find('"')],stream=True).iter_content(chunk_size=4096):
        QQ.write(chunk)