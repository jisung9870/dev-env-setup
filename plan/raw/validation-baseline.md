# 검증 기준선

## 2026-08-10 실행 결과

| 범위 | 명령/검증 | 결과 |
|---|---|---|
| Workbench 정적 분석 | `go vet ./...` | 통과 |
| Workbench 전체 Go test | `go test ./...` | 전 패키지 통과 |
| Windows cross-build | `GOOS=windows GOARCH=amd64 go build ./cmd/wb` | 통과 |
| Dashboard browser logic | Node test | 9개 통과 |
| root cross-repo contract | `tests/contract-test.sh` | 18 group 통과 |
| binbox | shellcheck + bats | shellcheck 통과, 267 test 통과 |
| root aggregate health | `doctor.sh` | 통과 |
| Workbench integration E2E | `tests/workbench-e2e.sh` | 11 group 통과 |
| provider failure diagnostics | fake tmux stdout + exit 7 | 출력 보존, 명령 실패 유지 |

환경 PATH에서 Go, Node, bats shim이 직접 해석되지 않아 설치된 실제 runtime 경로를 사용했다. 이는
제품 코드 실패는 아니지만 새 장비 toolchain 발견성 문제의 근거가 될 수 있다.

## Doctor에서 확인된 제한

- 현재 환경에 cmux CLI가 없어 cmux config runtime check는 skipped였다.
- `shfmt`가 없어 formatting check는 skipped였다.
- nvim headless와 cmux reference generation/check는 통과했다.
- lock mismatch는 report-only이므로 aggregate 실패를 만들지 않는다.

## 아직 증명하지 못한 것

- 이번 기준선에서 `go test -race ./...`는 실행하지 않았다.
- 실제 macOS + cmux end-to-end smoke를 실행하지 않았다.
- 실제 native Windows 장비의 bootstrap과 Workbench 동작을 실행하지 않았다.
- 실제 Windows Terminal + WSL 장비의 전체 project/Agent/worktree 흐름을 실행하지 않았다.
- 별도 Linux 장비 또는 SSH 재접속 흐름을 실제 장비에서 검증하지 않았다.
- 장기간 scheduler/server 안정성과 실제 일상 사용 빈도 데이터가 없다.
- Secret의 변형·인코딩·file/network 유출을 막는 sandbox는 제품 범위에 없다.

## 검증 해석 규칙

- cross-build 성공은 해당 OS에서 실행 성공을 의미하지 않는다.
- fake provider E2E는 실패 계약을 증명하지만 실제 tmux 버전 호환 전체를 증명하지 않는다.
- optional provider skip은 core health 성공과 구분한다.
- 이전 시점의 race 또는 장비 smoke 기록을 현재 baseline 통과로 대체하지 않는다.
