# {Package Name} Sub-Agent Operating Contract

**Document Type**: Normative Specification  
**Package**: {repo-name}  
**Agent ID**: `agent:{repo-name}`  
**Version**: 0.1.0  
**Last Updated**: YYYY-MM-DD

---

## 1. Purpose (목적)

{패키지명} 패키지 전문 실행 에이전트의 운영 규약을 정의한다.

이 문서는 **규범 문서(Normative Specification)** 이다.  
본 문서에 정의된 규칙을 위반하는 모든 행위는 **시스템 버그**로 간주한다.

---

## 2. Authority & Scope (권한 및 책임 범위)

### 2.1 Identity (정체성)

- **Agent ID**: `agent:{repo-name}`
- **Execution Environment**: Docker container `agent-{repo-name}`
- **Workspace Root**: `/work/repos/{repo-name}`
- **Artifacts Path**: `/work/tasks/{taskId}/artifacts/{repo-name}`

### 2.2 Execution Authority (실행 권한)

- ✅ 자기 레포 (`{repo-name}/`) 내 파일만 수정 가능
- ❌ 다른 레포 파일 직접 수정 금지
- ✅ Public API 변경 시 중앙 스펙 갱신 필요

### 2.3 Responsibility Scope (책임 범위)

{이 패키지가 책임지는 기능 목록}

**Example**:
```
- 공통 데코레이터 제공 (@Injectable, @Module)
- 공통 에러 클래스 제공
- 헬퍼 함수 제공 (타입 체킹, 유틸리티)
- 공통 인터페이스 정의
```

---

## 3. Context Loading Rules (컨텍스트 로딩 규칙)

### 3.1 Automatic Loading (자동 로딩)

Job 실행 시 다음 문서들이 자동으로 로드된다:

```typescript
function loadContextForExecution(job: AgentOpsJob) {
  const docs = [];
  
  // 1. 자기 역할 (중앙 스펙)
  docs.push('bunner-framework/specs/packages/{repo}.md');
  
  // 2. 자기 레포 문서 (로컬)
  docs.push('{repo}/docs/ROLE.md');          // 중앙 스펙 복사본
  docs.push('{repo}/docs/DEPENDENCIES.md');  // 의존성 문서
  docs.push('{repo}/docs/ARCHITECTURE.md');  // 내부 구조
  docs.push('{repo}/docs/SPEC.md');          // 상세 스펙
  
  // 3. 의존하는 패키지의 PUBLIC API만 (중앙 스펙)
  const deps = parseDependencies('{repo}/package.json');
  for (const dep of deps.filter(d => d.startsWith('@bunner/'))) {
    const depName = dep.replace('@bunner/', '');
    docs.push(`bunner-framework/specs/packages/${depName}.md`);
  }
  
  // 4. 관련 코드 (semantic search)
  const relevantCode = semanticSearch(job.goal, '{repo}/src/**');
  docs.push(...relevantCode);
  
  return docs; // 일반적으로 30-50 files, ~5,000 lines
}
```

### 3.2 Prohibited Loading (금지된 로딩)

다음 문서는 로드해서는 안 된다:

- ❌ 다른 패키지의 로컬 문서 (`*/docs/SPEC.md`, `*/docs/ARCHITECTURE.md`)
- ❌ 다른 패키지의 소스 코드 (`*/src/**`)
- ❌ 중앙 스펙 이외의 다른 패키지 정보

### 3.3 Size Control (크기 제어)

- 일반적인 컨텍스트: <5,000 lines
- 경고 임계값: 10,000 lines
- 목표: 모노레포 대비 70% 감소

---

## 4. Work Process (작업 프로세스)

### 4.1 Job Execution Flow (Job 실행 흐름)

1. **Job 수신** (from Runner)
   - Job 정의 파싱
   - 입력 아티팩트 확인

2. **Context 자동 로딩**
   - Section 3.1 규칙에 따라 자동 로드

3. **현재 구현 확인**
   - 자기 레포 코드 읽기
   - 현재 상태 파악

4. **작업 수행**
   - `goal`에 명시된 작업 수행
   - `command`가 있으면 실행

5. **로컬 문서 갱신**
   - `docs/SPEC.md` 업데이트 (구현 변경 시)
   - `docs/ARCHITECTURE.md` 업데이트 (구조 변경 시)

6. **중앙 스펙 갱신 요청** (Public API 변경 시)
   - `bunner-framework/specs/packages/{repo}.md` 갱신
   - 변경 사항을 `output` 아티팩트에 명시

7. **아티팩트 생성**
   - 다음 Job의 input으로 사용할 파일 생성
   - `/work/tasks/{taskId}/artifacts/{repo}/<file>` 경로

### 4.2 Artifact Output (아티팩트 출력)

**Path Convention**:
```
/work/tasks/{taskId}/artifacts/{repo}/
  ├─ output.json          # 주요 출력 (구조화된 데이터)
  ├─ changes.md           # 변경 사항 요약
  ├─ api-changes.json     # Public API 변경 (있을 경우)
  └─ <custom-file>        # Job별 커스텀 파일
```

**Format**: JSON, Markdown, or other structured format

**Usage**: 다음 Job의 `input`으로 사용 가능

### 4.3 Public API Changes (Public API 변경)

Public API 변경 시 반드시 수행:

1. **로컬 `docs/SPEC.md` 갱신**
   - 새 API 문서화
   - 예제 추가

2. **중앙 스펙 갱신**
   - `bunner-framework/specs/packages/{repo}.md`
   - Public API 섹션만 업데이트 (200줄 제한 유지)

3. **아티팩트에 명시**
   - `artifacts/{repo}/api-changes.json`:
   ```json
   {
     "breaking": true,
     "changes": [
       {
         "type": "modified",
         "name": "functionName",
         "before": "functionName(a: string): void",
         "after": "functionName(a: string, b: number): void"
       }
     ],
     "affectedPackages": ["bunner-cli", "bunner-http-adapter"]
   }
   ```

4. **Dependents 영향 분석**
   - 영향받는 패키지 목록 생성
   - 다음 Job에서 수정하도록 계획

---

## 5. Dependencies (의존성)

### 5.1 Allowed Dependencies (허용된 의존성)

{package.json에 명시된 @bunner/* 패키지 목록}

**Example**:
```
- @bunner/shared@^1.0.0
- @bunner/core@^1.0.0
```

### 5.2 Dependency Usage (의존성 사용)

- ✅ 의존 패키지의 **Public API만** 사용
- ❌ 내부 구현 의존 금지 (export되지 않은 것)
- ✅ 타입 import는 허용 (`import type { ... }`)

**Example**:
```typescript
// ✅ OK: Public API 사용
import { Injectable } from '@bunner/common';

// ✅ OK: Type import
import type { DIContainer } from '@bunner/core';

// ❌ NOT OK: 내부 모듈 import
import { internalHelper } from '@bunner/core/internal';
```

### 5.3 Adding Dependencies (의존성 추가)

새 의존성 추가 시:
1. `package.json` 업데이트
2. `docs/DEPENDENCIES.md` 업데이트
3. 중앙 스펙의 `Dependencies` 섹션 업데이트
4. 아티팩트에 의존성 변경 명시

---

## 6. Prohibited Actions (금지 사항)

서브에이전트는 다음 행위를 해서는 안 된다:

- ❌ **다른 레포 파일 직접 수정**: 자기 레포만 수정 가능
- ❌ **의존하지 않는 패키지 import**: package.json에 없는 패키지 사용 금지
- ❌ **Private API 사용**: export되지 않은 함수/클래스 사용 금지
- ❌ **중앙 스펙 이외 정보로 추론**: 다른 패키지 내부를 추측하지 말 것
- ❌ **다른 서브에이전트와 직접 통신**: 오직 아티팩트를 통해서만 통신

---

## 7. Communication (통신)

### 7.1 Inter-Agent Communication (에이전트 간 통신)

서브에이전트는 **아티팩트 파일 시스템**을 통해서만 통신한다.

**금지**:
- ❌ 네트워크 통신 (HTTP, WebSocket 등)
- ❌ 공유 메모리
- ❌ 직접 함수 호출

**허용**:
- ✅ 아티팩트 파일 읽기/쓰기
- ✅ 중앙 스펙 참조

### 7.2 Orchestrator Communication (오케스트레이터 통신)

- 오케스트레이터는 서브에이전트 실행을 **관찰만** 한다.
- 서브에이전트는 오케스트레이터에게 직접 보고하지 않는다.
- Runner가 실행 상태를 Gateway Server에 전송한다.

---

## 8. Error Handling (에러 처리)

### 8.1 Job Failure (Job 실패)

Job 실패 시:
1. 에러 메시지 생성
2. 아티팩트에 실패 정보 기록
3. Runner에 실패 보고
4. 컨테이너 종료

**Artifact on Failure**:
```json
{
  "status": "failed",
  "error": {
    "message": "DI container initialization failed",
    "code": "DI_INIT_ERROR",
    "stack": "..."
  },
  "partialOutput": { /* 부분 결과 (있다면) */ }
}
```

### 8.2 Retry Policy (재시도 정책)

- Runner가 재시도 여부 결정
- 서브에이전트는 재시도를 요청하지 않음
- 최대 3회 재시도 (기본값)

---

## 9. Validation (검증)

### 9.1 Pre-execution Validation (실행 전 검증)

Job 실행 전:
- ✅ 입력 아티팩트 존재 확인
- ✅ 의존성 설치 확인 (`node_modules/`)
- ✅ 권한 확인 (파일 쓰기 권한)

### 9.2 Post-execution Validation (실행 후 검증)

Job 실행 후:
- ✅ 출력 아티팩트 생성 확인
- ✅ 로컬 테스트 실행 (있다면)
- ✅ 린트 검사 (있다면)

---

## 10. Violation Handling (위반 처리)

본 규약 위반 시:
- **버그로 기록**
- Job 즉시 실패 처리
- Runner에 보고
- 재시도 또는 사용자 개입 요청

**"의도", "맥락", "편의성"은 위반 사유를 정당화하지 않는다.**

---

## 11. Versioning (버전 관리)

### 11.1 문서 버전

- 현재 버전: **0.1.0** (Draft)
- 오케스트레이터 AGENTS.md와 동일한 MAJOR 버전 유지

### 11.2 호환성

- 오케스트레이터 MAJOR 버전 변경 시 이 문서도 업데이트 필요
- 패키지 자체 버전과는 독립적

---

## 12. References (참조)

- [Orchestrator AGENTS.md](../../bunner-framework/AGENTS.md) - 워크스페이스 오케스트레이터 규약
- [Central Spec](../../bunner-framework/specs/packages/{repo}.md) - 중앙 간결 스펙
- [Local SPEC.md](./docs/SPEC.md) - 로컬 상세 스펙
- [PLAN.md](../../PLAN.md) - Migration plan

---

**Template Version**: 1.0.0  
**Usage**: Copy to `{repo}/AGENTS.md` for each package repository
