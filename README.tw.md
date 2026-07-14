# ming.sh

`ming.sh` 是從 [kejilion/sh](https://github.com/kejilion/sh) 依 Apache
License 2.0 個人化而來的 Linux 伺服器管理工具。

[主要 README（中文 / English）](README.md)

> [!WARNING]
> 專案包含會修改防火牆、網路、SSH、cron、Docker、systemd、套件與系統檔案的
> 高權限功能。執行前請先審閱程式碼，不要把遠端腳本直接交給 shell。

## 預設值

- 主要命令：`m`
- 相容命令：`k`
- 遙測與使用統計：永久停用
- 專案自我更新與自動更新：停用
- 入口：`tw/ming.sh`

## 審閱後執行

```bash
curl -fL --output ming.sh \
  https://raw.githubusercontent.com/JohnMing143/ming-sh/main/tw/ming.sh
bash -n ming.sh
shellcheck ming.sh
less ming.sh
bash ming.sh
```

設定、相容策略、上游依賴與驗證方式請參閱主要 README 與
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)。
