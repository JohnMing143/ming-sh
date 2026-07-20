# ming.sh

올인원 Linux 서버 관리 도구 모음입니다. 설치 후 `m` 명령 하나만 입력하면
대화형 메뉴를 통해 시스템 유지 관리, Docker, 웹 사이트 구축, 네트워크 최적화
등 일상적인 운영 작업을 수행할 수 있습니다.

[简体中文](README.md) · [繁體中文](README.tw.md) · [日本語](README.ja.md)

## 주요 기능

- **시스템 관리**: 시스템 정보 조회, 시스템 업데이트, 불필요한 파일 정리, 기본 도구
- **Docker 관리**: 컨테이너·이미지·네트워크·볼륨 설치와 유지 관리, 인기 앱 원클릭 배포
- **웹 사이트 구축·운영**: LNMP 환경, 사이트 관리, SSL 인증서, 백업과 마이그레이션
- **네트워크 최적화**: BBR 가속, 커널 튜닝, 방화벽과 포트 관리
- **실용 도구**: SSH 보호, 디스크 관리, rsync 동기화, 클러스터 관리, 백그라운드 작업
- **추가 모듈**: OpenClaw, 게임 서버(Palworld, Minecraft) 등 보조 기능

## 설치

명령 하나로 설치와 실행이 완료됩니다:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JohnMing143/ming-sh/main/kr/ming.sh)
```

처음 실행하면 명령이 `/usr/local/bin/m`에 설치되며, 이후에는 어느 디렉터리
에서든 `m`을 입력하면 메인 메뉴가 열립니다.

다른 언어 버전이 필요하면 다운로드 경로의 `kr/ming.sh`를 다음 중 하나로
바꾸십시오:

```text
ming.sh       메인 구현(简体中文)
cn/ming.sh    简体中文
en/ming.sh    English
jp/ming.sh    日本語
tw/ming.sh    繁體中文
```

## 사용법

```bash
m
```

메뉴 번호를 선택하기만 하면 각 기능을 사용할 수 있습니다. 각 기능은 실행
전에 수행할 작업을 설명합니다. 의존성 다운로드나 시스템 변경이 필요한 작업은
해당 메뉴 항목을 직접 선택했을 때만 수행됩니다.

시스템 튜닝 관련 기능은 `/etc/sysctl.d/99-ming-sh-*.conf` 설정 파일과
`# ming-sh-optimize` 마커를 사용하고, 네트워크 자동 튜닝 모드는
`/etc/sysctl.d/99-network-optimize.conf`를 사용하므로 식별과 정리가
쉽습니다.

## 개인정보 보호와 보안 기본값

- **사용 통계 없음**: 프로젝트 소스 코드에는 텔레메트리나 통계 전송 로직이
  전혀 포함되어 있지 않습니다.
- **자동 업데이트 없음**: 프로젝트 자체 업데이트와 자동 업데이트 cron이 모두
  비활성화되어 있어 업데이트는 전적으로 사용자가 제어합니다.
- **GitHub 직접 연결**: 기본적으로 GitHub 프록시를 사용하지 않습니다.
- **의존성 출처 투명성**: 일부 Nginx 템플릿, Docker Compose 파일, Docker
  이미지 등은 여전히 업스트림 프로젝트에서 가져옵니다. 이러한 주소는 모두
  [`config/project.conf`](config/project.conf)의 `UPSTREAM_*` 변수로 관리되며,
  전체 목록은 [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)를 참조하십시오.
- **개발용 번역 스크립트 기본 비활성화**: 이 스크립트는 소스 코드 조각을
  Google Translate로 전송하므로 `ALLOW_REMOTE_TRANSLATION=true`를 명시적으로
  설정한 경우에만 실행됩니다. 일반 사용에서는 신경 쓸 필요가 없습니다.

## 개발 참여

개발 검증 방법, 저장소 구조, 테스트 설명은 [`AGENTS.md`](AGENTS.md)와
[`tests/`](tests) 디렉터리를, 보안 경계 감사는
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)를 참조하십시오.

## 원본 저장소와 라이선스

이 프로젝트는 [kejilion/sh](https://github.com/kejilion/sh)를 기반으로
커스터마이즈한 것으로, Apache License 2.0에 따라 제공됩니다. 저장소에는
[`LICENSE`](LICENSE) 파일과 필요한 업스트림 귀속 표시가 유지되어 있습니다.
이름의 개인화는 원저자의 저작권 또는 라이선스 고지의 제거를 의미하지
않습니다.
