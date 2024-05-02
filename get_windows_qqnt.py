from requests import get
r=get('https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js').text
r=r[r.find('ntDownloadX64Url')+19:]
with open('QQInstaller.exe','wb') as QQ:
	QQ.write(get(r[:r.find('"')],stream=True).content)