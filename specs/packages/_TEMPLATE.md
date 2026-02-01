# Package: {package-name}

**Document Type**: Central Specification (Concise)  
**Size Limit**: 200 lines (strict)  
**Last Updated**: YYYY-MM-DD

---

## Role

{패키지가 하는 일을 명사로 끝나는 한 문장으로 작성. 3-5줄로 제한.}

**Example**:
```
Common utilities, decorators, and error classes for all Bunner packages.
Provides @Injectable, @Module decorators and type-checking helpers.
```

---

## Public API

### Exports

{공개된 함수, 클래스만 나열. 한 줄 설명 포함.}

#### Functions
- `functionName(args): ReturnType` - {한 줄 설명}

#### Classes
- `ClassName` - {한 줄 설명}

#### Types
```typescript
// 타입 시그니처만, 구현 설명 없음
interface ConfigType {
  field: string;
  optionalField?: number;
}

type AliasType = string | number;
```

### CLI (if applicable)
- Binary: `bunner-<package>`
- Commands:
  - `command-name` - {한 줄 설명}

---

## Dependencies

{이 패키지가 의존하는 다른 @bunner/* 패키지 목록}

- `@bunner/<package>` - {의존 이유 한 줄}

**Example**:
```
- `@bunner/core` - DI container, application lifecycle
- `@bunner/common` - Utilities, decorators
```

---

## Dependents

{이 패키지에 의존하는 다른 @bunner/* 패키지 목록}

- `@bunner/<package>` - {의존 이유 한 줄}

**Example**:
```
- `@bunner/cli` - Uses logger for output
- `@bunner/http-adapter` - Uses for request logging
```

---

## Constraints

{이 패키지가 가진 제약사항}

**Example**:
```
- No runtime dependencies (except reflect-metadata)
- MUST NOT depend on @bunner/core (layering violation)
- Config file required (bunner.json or bunner.jsonc)
```

---

## Features

{주요 기능 목록 (간결하게)}

**Example**:
```
- AOT scanning of createApplication/defineModule
- DI graph construction at build time
- Hot module replacement
- Config validation
```

---

## Status

- **Version**: `X.Y.Z`
- **Stability**: `stable | experimental | deprecated`
- **Last Updated**: `YYYY-MM-DD`

---

## Agent Information

- **Sub-agent**: `agent:{repo-name}`
- **Container**: `agent-{repo-name}`
- **Local spec**: `{repo}/docs/SPEC.md` (detailed)

---

## Prohibited Content

❌ **이 문서에 포함하지 말 것**:

- "왜" 설명 (→ 로컬 `docs/DECISIONS.md`로)
- 예제 코드 (→ 로컬 `docs/SPEC.md`로)
- 내부 구현 세부사항 (→ 로컬 `docs/ARCHITECTURE.md`로)
- 히스토리, 변경 로그 (→ 로컬 `CHANGELOG.md`로)
- 긴 타입 정의 (→ 시그니처만, 구현은 로컬로)

---

## Usage Guidelines

### For Orchestrator
- 이 문서로 패키지 역할 파악
- 이 문서로 Public API 확인
- 이 문서로 의존성 그래프 구성
- **로컬 문서는 읽지 않음**

### For Sub-Agent
- 이 문서를 `docs/ROLE.md`에 복사
- 의존하는 패키지의 이 문서만 읽음
- 자기 레포의 `docs/SPEC.md` (상세) 추가 로드

---

**Template Version**: 1.0.0  
**Usage**: Copy this template for each package in `bunner-framework/specs/packages/`
