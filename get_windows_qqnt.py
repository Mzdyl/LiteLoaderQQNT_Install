from requests import get
r=get('https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js').text
r=r[r.find('"ntDownloadX64Url"'):]
r=r[r.find('"'):]
with open('QQInstaller.exe','wb') as QQ:
	QQ.write(get(r[1:r.find('"')],stream=True).content)