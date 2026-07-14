# ming.sh

`ming.sh` は [kejilion/sh](https://github.com/kejilion/sh) を Apache
License 2.0 の条件でカスタマイズした、個人用 Linux サーバー管理ツールです。

[メイン README（中文 / English）](README.md)

> [!WARNING]
> ファイアウォール、ネットワーク、SSH、cron、Docker、systemd、パッケージ、
> システムファイルを変更する高権限機能を含みます。実行前にコードを確認し、
> リモートスクリプトを直接 shell に渡さないでください。

## デフォルト

- メインコマンド: `m`
- 互換コマンド: `k`
- テレメトリと利用統計: 常に無効
- プロジェクトの自己更新と自動更新: 無効
- エントリーポイント: `jp/ming.sh`

## 確認してから実行

```bash
curl -fL --output ming.sh \
  https://raw.githubusercontent.com/JohnMing143/ming-sh/main/jp/ming.sh
bash -n ming.sh
shellcheck ming.sh
less ming.sh
bash ming.sh
```

設定、互換性、上流依存関係、検証方法についてはメイン README と
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) を参照してください。
