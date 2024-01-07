## ❀ A simple, user-friendly Powershell script to make use of yt-dlp video downloading on Windows
## ❀ 简单方便的yt-dlp视频下载器操作界面脚本

Previously published on / 原文发布于：https://nazorip.site/archives/1313/<br>

This script was written & deployed in panic due to my saved-for-later YouTube videos were removed for "not meeting community guidelines"<br>
因油管河蟹，及不慎手抽而痛失收藏视频，遂慌而疾书所得（文言文太差，尽力了）<br>

This script inherited my advanced user-input feature in the following repository:<br>
此脚本继承了个人所开发的高级多行用户输入对话框工具，于：[Multiline input-dialog advanced](https://github.com/iAvoe/Multi-Line-Input-Dialog-Advanced)

## ▲How to run ▲如何运行
- Lift PSScript running restriction under Settings-->Update & Security-->For Developers:
- 在设置-->更新和安全-->开发者选项中解除PowerShell的运行限制，如图：
 ![bbenc-ttl5en.png](bbenc-ttl5en.png)

-----

### ▲Work flow ▲工作及使用流程
1. [Download yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/releases)
    - For best result, extract yt-dlp.exe into a folder
2. [Download yt-dlp-ops-en.ps1](yt-dlp-ops-en.ps1) and place this script in the same folder
3. Run yt-dlp-ops.ps1，whether by PowerShell ISE，or right-click→Run by PowerShell
    - Paste all your download links inside, one link per line
      - You may need a mass-URL-copying tool to copy a bunch of video links at once like [Snap Links Plus](https://addons.mozilla.org/en-US/firefox/addon/snaplinksplus/)
    - Select downloading path in the popped menu
    - Select path for yt-dlp.exe in the popped menu
      - (or auto-skipped if you place this script in the same folder as yt-dlp.exe)
    - Select batch script exporting path in the popped menu
    - For best result on your own computer, input 'y' to get cookies from a logged browser for yt-dlp's website identificaiton
    - Done！double-click to run the generated `yt-dlp-download.bat`

.
1. [下载一个 yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/releases)
    - 为实现最优结果，建议创建一个文件夹用于放置yt-dlp.exe
2. [下载 yt-dlp-ops-zh.ps1](yt-dlp-ops-zh.ps1) 并建议将本脚本放入yt-dlp.exe同文件夹下
3. 运行yt-dlp-ops.ps1，可以在PowerShell ISE中打开并运行，也可以右键→用PowerShell运行
    - 将所有要下载的视频链接粘贴进去
      - 可以用批量拷贝链接的浏览器插件，如[Snap Links Plus](https://addons.mozilla.org/zh-CN/firefox/addon/snaplinksplus/)
    - 通过弹出的选择窗选择下载视频的路径
    - 通过弹出的选择窗定位yt-dlp.exe
      - (若该脚本位于yt-dlp同文件夹下，则自动完成选择)
    - 通过弹出的选择窗选择导出批处理的路径
    - 每天第一次使用时，选择y以添加一行导出当前浏览器cookie的命令以便yt-dlp读取和登录
    - 完成！双击运行导出的`yt-dlp-download.bat`以开始下载

### ▲Extras ▲其它特性
- Each downloading task has a random gap of 1~7 seconds to somewhat mimic a normal watching traffic and offloads website platform a bit
- The entire script is basically a GUI program which makes everything easier for normal user
- Exports UTF-8 No BOM text codec

.
- 每个下载线程之间会随机生成一个1~7秒的间隔，从而让下载进程更像正常观看，且每次都不会重复
- 通过GUI窗口选择各种路径，极大地降低了操作难度
- 导出UTF-8 No BOM编码的批处理
