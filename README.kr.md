# ming.sh

`ming.sh`은 [kejilion/sh](https://github.com/kejilion/sh)를 Apache License
2.0 조건에 따라 개인용으로 수정한 Linux 서버 관리 도구입니다.

[기본 README (中文 / English)](README.md)

> [!WARNING]
> 방화벽, 네트워크, SSH, cron, Docker, systemd, 패키지 및 시스템 파일을
> 변경하는 고권한 기능이 포함되어 있습니다. 실행 전에 코드를 검토하고 원격
> 스크립트를 shell에 직접 전달하지 마십시오.

## 기본값

- 기본 명령: `m`
- 호환 명령: `k`
- 텔레메트리와 사용 통계: 항상 비활성화
- 프로젝트 자체 업데이트와 자동 업데이트: 비활성화
- 진입점: `kr/ming.sh`

## 검토 후 실행

```bash
curl -fL --output ming.sh \
  https://raw.githubusercontent.com/JohnMing143/ming-sh/main/kr/ming.sh
bash -n ming.sh
shellcheck ming.sh
less ming.sh
bash ming.sh
```

설정, 호환성, 업스트림 의존성 및 검증 방법은 기본 README와
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)를 참조하십시오.
