# 中文快速开始

这份说明适合帮家人、邻居、社区用户或小店先看一遍 Windows 电脑健康状态。PC Health Check 只做诊断：不删除文件、不修改设置、不关闭启动项、不安装软件、不上传数据。

## 适合什么场景

- 电脑变慢，但说不清是内存、磁盘、启动项、更新还是浏览器问题。
- 远程帮别人判断下一步该查什么。
- 维修前后想保留一份可比较的基础报告。
- 在公开 issue、聊天或邮件里分享问题前，先生成一份去身份化报告。

## 运行前

1. 先得到电脑主人的同意。
2. 告诉对方这个工具只读，不会修复或改动电脑。
3. 如果报告可能发给外人，请优先使用 `-RedactIdentity`。
4. 不要要求对方提供密码、支付信息、聊天记录、浏览器历史或私人文件。

## 最简单运行方式

在 Windows 电脑上下载或克隆本仓库后，双击：

```text
run-pc-health-check.cmd
```

运行完成后，桌面会生成类似下面的文件：

```text
PC-Health-Report-20260622-101530.txt
PC-Health-Report-20260622-101530.json
```

先打开 `.txt` 文件。它更适合人工阅读。

## PowerShell 运行方式

如果你习惯使用 PowerShell，可以在仓库目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -OpenReport
```

如果报告可能发到 GitHub issue、聊天群、邮件或任何非私密支持场景，请使用去身份化模式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity -OpenReport
```

如果你想给不懂技术的人看一个更清楚的页面，可以加上 HTML 报告：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity -HtmlReport -OpenReport
```

HTML 报告是本地文件，不包含 JavaScript，不加载外部资源，也不会联网。

## 先看哪些部分

建议按这个顺序看：

1. `Quick Findings`
2. `Performance`
3. `Drives`
4. `Startup Items`
5. `Antivirus`
6. `Windows Update`
7. `Browser Check`

这些部分通常能快速判断电脑慢是资源压力、磁盘空间、启动项、更新、杀毒软件冲突，还是浏览器扩展过多。

## 看完以后不要急着改

- 不要直接删除文件。
- 不要直接关闭安全软件。
- 不要直接禁用所有启动项。
- 不要把报告当成硬件损坏证明。
- 做任何修复前，先让电脑主人确认。
- 修复后再跑一次报告，对比前后变化。

## 下一步

英文报告解读说明在 [Report Interpretation Guide](../report-interpretation.md)。如果要把报告发给别人，请先看 [报告分享与隐私检查](report-sharing.md)。
