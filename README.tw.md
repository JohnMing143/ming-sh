# ming.sh

一站式 Linux 伺服器管理工具箱。安裝後輸入一個 `m` 命令，即可透過互動式選單
完成系統維護、Docker、架站、網路最佳化等日常維運工作。

[简体中文](README.md) · [日本語](README.ja.md) · [한국어](README.kr.md)

> [!WARNING]
> 本工具包含修改防火牆、網路、SSH、cron、Docker、systemd、套件以及
> `/etc`、`/usr`、`/home` 下檔案的高權限功能。請先審閱程式碼，在測試機驗證，
> 再以適當權限執行。不要把遠端腳本直接交給 shell。

## 功能一覽

- **系統管理**：系統資訊查詢、系統更新、垃圾清理、常用基礎工具
- **Docker 管理**：容器、映像檔、網路、卷的安裝與維護，常用應用一鍵部署
- **架站與維運**：LNMP 環境、站點管理、SSL 憑證、備份與遷移
- **網路最佳化**：BBR 加速、核心調校、防火牆與連接埠管理
- **實用工具**：SSH 防護、磁碟管理、rsync 同步、叢集管理、背景任務
- **附加模組**：OpenClaw、遊戲伺服器（Palworld、Minecraft）等輔助功能

## 安裝

建議先把腳本下載到本地，檢查後再執行（請勿使用 `curl ... | bash`）：

```bash
curl -fL --output ming.sh \
  https://raw.githubusercontent.com/JohnMing143/ming-sh/main/tw/ming.sh
bash -n ming.sh
less ming.sh
bash ming.sh
```

首次執行會把命令安裝到 `/usr/local/bin/m`，之後在任意目錄輸入 `m` 即可開啟
主選單。

如需其他語言版本，把下載路徑中的 `tw/ming.sh` 換成：

```text
ming.sh       主實作（简体中文）
cn/ming.sh    简体中文
en/ming.sh    English
jp/ming.sh    日本語
kr/ming.sh    한국어
```

## 使用

```bash
m
```

按選單編號選擇功能即可。各功能會在執行前說明將要進行的操作；涉及下載相依套件
或修改系統的操作，均只在你主動選擇對應選單項目時才會發生。

系統調校相關功能使用 `/etc/sysctl.d/99-ming-sh-*.conf` 設定檔和
`# ming-sh-optimize` 標記，便於識別和清理。

## 隱私與安全預設值

- **無使用統計**：專案原始碼不包含任何遙測或統計上報邏輯。
- **無自動更新**：專案自我更新和自動更新 cron 均已停用，更新完全由你掌控。
- **直連 GitHub**：預設不使用任何 GitHub 代理。
- **相依來源透明**：部分 Nginx 範本、Docker Compose 檔案、Docker 映像檔等仍來自
  上游專案，所有位址集中在 [`config/project.conf`](config/project.conf) 中以
  `UPSTREAM_*` 變數維護，完整清單見 [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)。
- **開發用翻譯腳本預設停用**：該腳本會把原始碼片段傳送給 Google Translate，
  僅在明確設定 `ALLOW_REMOTE_TRANSLATION=true` 後才會執行，一般使用無需理會。

## 參與開發

開發驗證方式、儲存庫結構和測試說明見 [`AGENTS.md`](AGENTS.md) 與
[`tests/`](tests) 目錄；安全邊界稽核見 [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)。

## 原始儲存庫與授權

本專案基於 [kejilion/sh](https://github.com/kejilion/sh) 定製，依
Apache License 2.0 授權。儲存庫保留了 [`LICENSE`](LICENSE) 檔案和必要的上游
歸屬聲明；個人化名稱不表示對原作者版權或授權聲明的移除。
