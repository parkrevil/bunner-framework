# Multi-Repo Architecture Migration Plan

**Plan ID**: `260202_01_multi-repo-architecture`  
**Created**: 2026-02-02  
**Owner**: parkrevil  
**Status**: Draft

---

## Executive Summary

### Goal
Transform bunner monorepo into multi-repo architecture with orchestrator pattern to achieve **80% context reduction** per agent and enable scalable, isolated package development.

### Core Problems
1. **Context Overload**: 15,000-20,000 lines of docs must be loaded for any change
2. **Global Governance**: Package-local changes trigger workspace-level approvals
3. **Agent Confusion**: Single agent must understand 8+ packages simultaneously
4. **SSOT Fragmentation**: 40+ L3 specs in monorepo, no isolation

### Solution Architecture
```
bunner-framework (Orchestrator)
  ├─ specs/ (극도로 간결, 패키지당 200줄)
  └─ AGENTS.md (오케스트레이터 규약)
       ↓
  [USER_APPROVED]
       ↓
bunner-shared (Shared Contracts)
  ├─ L1 Invariants
  └─ Common Types
       ↓
Package Repos (8개 + example)
  ├─ docs/SPEC.md (상세, 제한 없음)
  └─ AGENTS.md (서브에이전트 규약)
```

---

## Repository Inventory (12 repos)

### Infrastructure Repos
1. **bunner-framework** - 중앙 오케스트레이터, 간결 스펙, DAG 계획
2. **bunner-agentops** - MCP 서버, Gateway, 컨테이너 실행

### Shared Repos
3. **bunner-shared** - L1 Invariants, 공통 타입, 크로스 패키지 인터페이스
4. **bunner-example** - 통합 예제, 서브에이전트 검증

### Package Repos (8개)
5. **bunner-cli** - CLI 도구
6. **bunner-core** - 프레임워크 코어
7. **bunner-common** - 공통 유틸리티
8. **bunner-http-adapter** - HTTP 어댑터
9. **bunner-logger** - 로깅 시스템
10. **bunner-scalar** - Scalar API 문서
11. **bunner-firebat** - 코드 품질 도구
12. **bunner-oxlint-plugin** - Oxlint 플러그인

---

## Phase 0: Foundation Design

### Objectives
- 오케스트레이터 AGENTS.md 명세 확정
- 중앙 스펙 템플릿 설계
- 서브에이전트 AGENTS.md 템플릿 설계
- 컨텍스트 자동 로딩 규칙 정의

### Deliverables

#### 0.1 Orchestrator AGENTS.md Template

**File**: `bunner-framework/AGENTS.md` (draft)

**Content Structure**:
```markdown
# Workspace Orchestrator Operating Contract

## 1. Purpose
오케스트레이터(Copilot Chat)의 운영 규약을 정의한다.

## 2. Authority & Scope
### 2.1 Identity
- 오케스트레이터는 Copilot Chat (사용자와 직접 대화하는 AI)이다.
- 단일 에이전트로 동작한다.
- 서브에이전트는 패키지별 컨테이너에서 실행된다.

### 2.2 Execution Authority
- 오케스트레이터는 **어떠한 경우에도 작업을 직접 실행하지 않는다**.
- 실행은 반드시 **USER_APPROVED** 이후에만 발생한다.
- 최종 산출물은 항상 **AgentOpsPipeline (DAG)** 이다.

### 2.3 Approval Model
IDEA → DISCUSSED → PLANNED → PIPELINED → PROPOSED
      → [USER_APPROVED] → EXECUTED

## 3. Responsibilities
### 3.1 Mandatory Workflow (5 Steps)

#### Step 1: Context Gathering
- 모든 관련 레포 코드/문서 직접 읽기
- 중앙 스펙 (bunner-framework/specs/) 확인
- 이전 작업 결과 확인
- 산출물: Context Report

#### Step 2: Requirement Analysis
- 사용자 의도 명확화
- 불명확성 질문
- 산출물: Clarified Requirements

#### Step 3: Planning
- 작업 분해 (Task → Jobs)
- 서브에이전트 할당 (repo 기준)
- 의존성 정의 (depends_on)
- 입출력 명세 (아티팩트 경로)
- 산출물: Draft Pipeline (DAG)

#### Step 4: Validation
- 라우팅 가능성 검증 (workers.json)
- 스펙 준수 검증 (bunner-framework/specs/)
- 의존성 순환 검증
- 영향 범위 분석
- 위험 요소 식별
- 산출물: Validated Pipeline + Risk Report

#### Step 5: Proposal
- 최종 계획 제시
- 위험 요소 명시
- 대안 제시 (있을 경우)
- 사용자 승인 대기

### 3.2 Context Loading Rules

#### 오케스트레이터 자동 로드
```typescript
function loadContextForPlanning(userRequest: string) {
  const docs = [];
  
  // 1. 항상 로드
  docs.push('bunner-framework/specs/OVERVIEW.md');
  
  // 2. 언급된 패키지
  const mentionedPackages = extractPackages(userRequest);
  for (const pkg of mentionedPackages) {
    docs.push(`bunner-framework/specs/packages/${pkg}.md`);
  }
  
  // 3. 의존 관계 (자동 탐색)
  const dependencies = findDependencies(mentionedPackages);
  for (const dep of dependencies) {
    docs.push(`bunner-framework/specs/packages/${dep}.md`);
  }
  
  return docs; // 보통 5-10페이지
}
```

## 4. Prohibited Actions
- 직접 코드 실행 금지
- MCP 서버에 실행 요청 전송 금지 (승인 전)
- 서브에이전트 내부 구현 추론/간섭 금지
- 다른 레포 파일 직접 수정 금지

## 5. Output Specification
### 5.1 AgentOpsPipeline Structure
```yaml
pipelineId: string
taskId: string
title: string
createdAt: IsoDateTimeString

jobs:
  - jobId: string
    title: string
    agent: "agent:bunner-<repo>"
    goal: string
    command: string (optional, 명시적 shell command)
    dependsOn: [jobId, ...]
    workspaceRef:
      repo: string
      path: string (optional)
    routingHint:
      labels: ["repo:bunner-<repo>"]
    input:
      - /work/tasks/{taskId}/artifacts/<repo>/<file>
    output:
      - /work/tasks/{taskId}/artifacts/<repo>/<file>
```

## 6. MCP Handoff Contract
- 오케스트레이터는 MCP 서버에 AgentOpsPipeline (DAG)만 전달
- 실행 요청은 사용자 승인 이벤트 발생 시에만
- MCP 서버는 Runner를 통해 서브에이전트 실행

## 7. Violation Handling
- 본 규약 위반은 **버그**로 기록
- "의도", "맥락", "편의성"은 위반 사유를 정당화하지 않음
```

**Size Limit**: ~500 lines (오케스트레이터는 중앙 역할이므로 상세)

---

#### 0.2 Central Spec Template

**File**: `bunner-framework/specs/packages/_TEMPLATE.md`

**Content Structure**:
```markdown
# Package: {package-name}

## Role
{패키지가 하는 일을 명사로 끝나는 한 문장으로. 3-5줄.}

## Public API

### Exports
- `functionName(args): ReturnType` - {한 줄 설명}
- `ClassName` - {한 줄 설명}

### Types
```typescript
// 타입 시그니처만, 구현 설명 없음
interface ConfigType {
  field: string;
}
```

## Dependencies
- `@bunner/<package>` - {의존 이유 한 줄}

## Dependents
- `@bunner/<package>` - {의존 이유 한 줄}

## Status
- Version: `1.0.0`
- Stability: `stable | experimental | deprecated`
- Last Updated: `YYYY-MM-DD`
```

**Size Limit**: 200 lines (엄격히 준수)

**Prohibited Content**:
- ❌ "왜" 설명 (로컬 문서로)
- ❌ 예제 코드 (로컬 문서로)
- ❌ 내부 구현 (로컬 문서로)
- ❌ 히스토리 (로컬 문서로)

---

#### 0.3 Sub-Agent AGENTS.md Template

**File**: `<repo>/AGENTS.md` (each package repo)

**Content Structure**:
```markdown
# {Package Name} Sub-Agent Operating Contract

## 1. Purpose
{패키지명} 패키지 전문 실행 에이전트의 운영 규약을 정의한다.

## 2. Authority & Scope

### 2.1 Identity
- Agent ID: `agent:{repo-name}`
- Execution Environment: Docker container `agent-{repo-name}`
- Workspace Root: `/work/repos/{repo-name}`

### 2.2 Execution Authority
- 자기 레포 내 파일만 수정 가능
- 다른 레포 파일 직접 수정 금지
- Public API 변경 시 중앙 스펙 갱신 필요

### 2.3 Responsibility Scope
{이 패키지가 책임지는 기능 목록}

## 3. Context Loading Rules

### 3.1 Automatic Loading
```typescript
function loadContextForExecution(job: AgentOpsJob) {
  const docs = [];
  
  // 1. 자기 역할 (중앙)
  docs.push('bunner-framework/specs/packages/{repo}.md');
  
  // 2. 자기 레포 문서 (로컬)
  docs.push('{repo}/docs/ROLE.md');
  docs.push('{repo}/docs/DEPENDENCIES.md');
  docs.push('{repo}/docs/ARCHITECTURE.md');
  docs.push('{repo}/docs/SPEC.md');
  
  // 3. 의존하는 패키지의 PUBLIC API만 (중앙)
  const deps = parseDependencies('{repo}/package.json');
  for (const dep of deps.filter(d => d.startsWith('@bunner/'))) {
    const depName = dep.replace('@bunner/', '');
    docs.push(`bunner-framework/specs/packages/${depName}.md`);
  }
  
  // 4. 관련 코드 (semantic search)
  const relevantCode = semanticSearch(job.goal, '{repo}/src/**');
  docs.push(...relevantCode);
  
  return docs; // 보통 30-50페이지
}
```

### 3.2 Prohibited Loading
- ❌ 다른 패키지의 로컬 문서 (*/docs/SPEC.md)
- ❌ 다른 패키지의 소스 코드 (*/src/**)
- ❌ 중앙 스펙 이외의 다른 패키지 정보

## 4. Work Process

### 4.1 Job Execution Flow
1. Job 수신 (from Runner)
2. Context 자동 로딩
3. 현재 구현 확인 (자기 레포 코드)
4. 작업 수행
5. 로컬 문서 갱신
6. Public API 변경 시 중앙 스펙 갱신 요청
7. 아티팩트 생성 (output 경로)

### 4.2 Artifact Output
- Path: `/work/tasks/{taskId}/artifacts/{repo}/<file>`
- Format: JSON, Markdown, or other structured format
- 다음 Job의 input으로 사용 가능

### 4.3 Public API Changes
Public API 변경 시:
1. 로컬 `docs/SPEC.md` 갱신
2. 중앙 `bunner-framework/specs/packages/{repo}.md` 갱신
3. 변경 사항을 `output` 아티팩트에 명시

## 5. Dependencies

### 5.1 Allowed Dependencies
{package.json에 명시된 @bunner/* 패키지 목록}

### 5.2 Dependency Usage
- 의존 패키지의 Public API만 사용
- 내부 구현 의존 금지
- 타입 import는 허용

## 6. Prohibited Actions
- 다른 레포 파일 직접 수정
- 의존하지 않는 패키지 import
- Private API 사용 (export되지 않은 것)
- 중앙 스펙 이외 정보로 다른 패키지 추론

## 7. Violation Handling
- 본 규약 위반은 **버그**로 기록
- Job 실패 시 Runner에 보고
- 재시도 또는 사용자 개입 요청
```

**Size Limit**: ~300 lines

---

#### 0.4 Context Loading Automation Spec

**File**: `bunner-agentops/docs/CONTEXT_LOADING.md`

**Content**:
```markdown
# Context Loading Automation

## Orchestrator Context Loading

### Trigger
- User request received in Copilot Chat

### Algorithm
1. Parse user request → extract mentioned packages
2. Load `bunner-framework/specs/OVERVIEW.md`
3. For each mentioned package:
   - Load `bunner-framework/specs/packages/<pkg>.md`
4. For each mentioned package:
   - Parse dependencies from central spec
   - Load dependency specs
5. Return document list (typically 5-10 files)

### Size Control
- Central specs: max 200 lines each
- Total context: typically <2,000 lines
- 80% reduction vs. monorepo (~15,000 lines)

## Sub-Agent Context Loading

### Trigger
- Job execution starts in container

### Algorithm
1. Load central role spec: `bunner-framework/specs/packages/{repo}.md`
2. Load local docs:
   - `{repo}/docs/ROLE.md` (copy of central)
   - `{repo}/docs/DEPENDENCIES.md`
   - `{repo}/docs/ARCHITECTURE.md`
   - `{repo}/docs/SPEC.md`
3. Parse `package.json` → extract @bunner/* dependencies
4. For each dependency:
   - Load ONLY central spec: `bunner-framework/specs/packages/<dep>.md`
   - Do NOT load `<dep>/docs/**`
5. Semantic search for relevant code in `{repo}/src/**`
6. Return document list (typically 30-50 files)

### Size Control
- Local docs: unlimited (detailed is better)
- Dependency specs: 200 lines each (central only)
- Total context: typically <5,000 lines
- 70% reduction vs. monorepo

## Implementation Notes

### MCP Server Integration
- Context loading logic in `bunner-agentops/apps/mcp-server/src/context-loader.ts`
- Caching strategy for central specs (read-once per session)
- Invalidation on central spec changes

### Validation
- Detect cross-repo reads (prohibited)
- Alert on oversized context (>10,000 lines)
- Log context size per execution for monitoring
```

---

### Phase 0 Validation Criteria
- [ ] All 3 AGENTS.md templates finalized
- [ ] Central spec template validated (<200 lines)
- [ ] Context loading algorithm documented
- [ ] No circular dependencies in templates
- [ ] Size limits mathematically proven to achieve 80% reduction

---

## Phase 1: Central Repository (bunner-framework)

### Objectives
- 중앙 스펙 디렉토리 구축
- 12개 패키지별 간결 스펙 작성
- L1/L2 요약본 생성
- 오케스트레이터 AGENTS.md 배치

### File Structure
```
bunner-framework/
  AGENTS.md                         # Orchestrator contract
  PLAN.md                           # This document
  specs/
    OVERVIEW.md                     # 1 page: architecture overview
    INVARIANTS.md                   # L1 summary (from bunner-shared)
    ARCHITECTURE.md                 # L2 summary
    packages/
      cli.md                        # Max 200 lines
      core.md
      common.md
      http-adapter.md
      logger.md
      scalar.md
      firebat.md
      oxlint-plugin.md
      shared.md                     # Shared types/contracts
      example.md                    # Example package
      agentops.md                   # AgentOps infrastructure
    contracts/
      cli-depends-on-core.md        # Explicit contracts
      cli-depends-on-common.md
      core-depends-on-common.md
      http-adapter-depends-on-core.md
      # ... (all dependency pairs)
```

---

### 1.1 OVERVIEW.md

**File**: `bunner-framework/specs/OVERVIEW.md`

**Content** (1 page, ~50 lines):
```markdown
# Bunner Framework Overview

## Architecture

Bunner is a TypeScript-first web framework organized as 12 repositories:

### Repository Layers
```
Infrastructure
  ├─ bunner-framework (orchestrator, central specs)
  └─ bunner-agentops (MCP server, execution runtime)

Shared
  ├─ bunner-shared (invariants, common types)
  └─ bunner-example (integration examples)

Core Packages
  ├─ bunner-core (DI, lifecycle, application)
  ├─ bunner-common (utilities, decorators)
  └─ bunner-http-adapter (HTTP layer)

CLI & Tools
  ├─ bunner-cli (dev server, build)
  ├─ bunner-logger (logging)
  ├─ bunner-scalar (API docs)
  ├─ bunner-firebat (code quality)
  └─ bunner-oxlint-plugin (linting)
```

## Dependency Graph
```
bunner-cli → bunner-core → bunner-common
bunner-http-adapter → bunner-core
bunner-logger → bunner-common
bunner-scalar → bunner-http-adapter
bunner-firebat → bunner-common
bunner-oxlint-plugin → (standalone)
```

## Development Model

- **Workspace Agent** (Orchestrator): Plans work as DAG
- **Sub-Agents**: Execute in isolated containers
- **Central Specs**: Minimal interface definitions (200 lines max)
- **Local Specs**: Detailed implementation docs (unlimited)

## Agent Context Loading

- Orchestrator: 5-10 central spec files (~2,000 lines)
- Sub-Agent: Own repo + dependency APIs (~5,000 lines)
- Goal: 80% context reduction vs. monorepo

## Further Reading

- [INVARIANTS.md](./INVARIANTS.md) - System invariants
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Structural boundaries
- [packages/](./packages/) - Package specifications
- [contracts/](./contracts/) - Inter-package contracts
```

---

### 1.2 Package Specs (Example: cli.md)

**File**: `bunner-framework/specs/packages/cli.md`

**Content** (~150 lines):
```markdown
# Package: bunner-cli

## Role
TypeScript-first CLI tool for Bunner framework development. Provides project scaffolding, dev server with hot reload, and production build.

## Public API

### Exports

#### Commands
- `createCLI(config: CLIConfig): CLI` - Create CLI instance
- `runDevServer(options: DevServerOptions): Promise<void>` - Start dev server
- `buildProject(options: BuildOptions): Promise<void>` - Production build

#### Types
```typescript
interface CLIConfig {
  projectRoot: string;
  configFile?: string; // bunner.json | bunner.jsonc
}

interface DevServerOptions {
  port?: number;
  watch?: boolean;
  hot?: boolean;
}

interface BuildOptions {
  outDir: string;
  minify?: boolean;
  sourcemap?: boolean;
}
```

### CLI Binary
- Binary: `bunner`
- Commands:
  - `bunner dev` - Start dev server
  - `bunner build` - Production build
  - `bunner create <name>` - Scaffold project

## Dependencies
- `@bunner/core` - DI container, application lifecycle
- `@bunner/common` - Utilities, decorators, types

## Dependents
- None (CLI is top-level consumer)

## Features
- AOT scanning of createApplication/defineModule
- DI graph construction at build time
- Hot module replacement
- Config validation (bunner.json/jsonc)

## Constraints
- Requires `bunner.json` or `bunner.jsonc` (not both)
- Config must specify `sourceDir` (scan root)
- Entry file must be under `sourceDir`

## Status
- Version: `1.0.0-alpha`
- Stability: `experimental`
- Last Updated: `2026-02-02`

## Agent Notes
- Sub-agent: `agent:bunner-cli`
- Container: `agent-bunner-cli`
- Local spec: `bunner-cli/docs/SPEC.md` (detailed)
```

**Repeat for all 12 packages** with similar structure.

---

### 1.3 Contract Docs (Example)

**File**: `bunner-framework/specs/contracts/cli-depends-on-core.md`

**Content** (~50 lines):
```markdown
# Contract: bunner-cli → bunner-core

## Dependency Type
**Consumer → Provider**

## Used APIs

### From @bunner/core
- `createApplication(config: ApplicationConfig)` - CLI invokes to bootstrap app
- `DIContainer` - CLI uses for command injection
- `LifecycleHooks` - CLI manages lifecycle events

### Type Imports
```typescript
import type { ApplicationConfig, DIContainer, LifecycleHooks } from '@bunner/core';
```

## Constraints
- CLI must NOT import internal Core modules (non-exported)
- CLI must NOT modify Core DI graph after initialization
- CLI passes user config to Core without interpretation

## Versioning
- Core breaking changes require CLI update
- Semantic versioning: Core patch/minor = CLI compatible

## Last Verified
2026-02-02
```

**Repeat for all dependency pairs.**

---

### 1.4 AGENTS.md Deployment

**File**: `bunner-framework/AGENTS.md`

Copy content from **Phase 0.1** template with all sections filled.

---

### Phase 1 Deliverables Checklist
- [ ] `bunner-framework/AGENTS.md` (orchestrator contract)
- [ ] `bunner-framework/specs/OVERVIEW.md`
- [ ] `bunner-framework/specs/INVARIANTS.md` (L1 summary)
- [ ] `bunner-framework/specs/ARCHITECTURE.md` (L2 summary)
- [ ] `bunner-framework/specs/packages/*.md` (12 files, each <200 lines)
- [ ] `bunner-framework/specs/contracts/*.md` (all dependency pairs)

### Phase 1 Validation Criteria
- [ ] All central specs <200 lines (strict)
- [ ] No broken references between files
- [ ] Dependency graph matches actual package.json
- [ ] OVERVIEW.md readable in <5 minutes
- [ ] Orchestrator can load all central specs in <2,000 lines

---

## Phase 2: Shared Contracts Repository (bunner-shared)

### Objectives
- L1 Invariants 전체 이관
- 공통 타입 정의
- 크로스 패키지 인터페이스
- bunner-shared 자체 스펙 작성

### File Structure
```
bunner-shared/
  AGENTS.md                         # Sub-agent contract
  package.json
  docs/
    ROLE.md                         # Copy from central
    SPEC.md                         # Detailed spec
    INVARIANTS.md                   # Full L1 from bunner/docs/10_FOUNDATION/
    ARCHITECTURE.md                 # Full L2 from bunner/docs/20_ARCHITECTURE/
  src/
    types/
      common.ts                     # Common types
      contracts.ts                  # Inter-package interfaces
    invariants/
      module-marker.ts              # Module marker validation
      file-attribution.ts           # File → Module attribution
```

---

### 2.1 bunner-shared AGENTS.md

**File**: `bunner-shared/AGENTS.md`

**Content** (using Phase 0.3 template):
```markdown
# bunner-shared Sub-Agent Operating Contract

## 1. Purpose
공유 계약 및 불변식 관리 에이전트의 운영 규약을 정의한다.

## 2. Authority & Scope

### 2.1 Identity
- Agent ID: `agent:bunner-shared`
- Execution Environment: Docker container `agent-bunner-shared`
- Workspace Root: `/work/repos/bunner-shared`

### 2.2 Execution Authority
- bunner-shared 레포 내 파일만 수정 가능
- L1 Invariants는 모든 패키지에 영향 → 변경 시 신중히
- 타입 변경 시 모든 dependents 영향 분석 필요

### 2.3 Responsibility Scope
- L1 Invariants 정의 및 유지
- L2 Architecture 경계 정의
- 공통 타입 정의 (모든 패키지가 사용)
- 크로스 패키지 인터페이스

## 3. Context Loading Rules
{Phase 0.3 template 내용 적용}

## 4. Work Process
{Phase 0.3 template 내용 적용}

## 5. Dependencies
- None (bunner-shared는 leaf 패키지, 다른 @bunner/* 의존하지 않음)

## 6. Dependents
- All other packages depend on bunner-shared

## 7. Special Constraints
- L1/L2 변경은 **전체 프로젝트 영향** → 오케스트레이터 통해 신중히
- 타입 변경 시 breaking change 여부 명시
- Invariant 추가/삭제는 Architecture Decision Record (ADR) 필요

## 8. Prohibited Actions
{Phase 0.3 template 내용 적용}

## 9. Violation Handling
{Phase 0.3 template 내용 적용}
```

---

### 2.2 bunner-shared/docs/SPEC.md

**File**: `bunner-shared/docs/SPEC.md`

**Content** (detailed, unlimited):
```markdown
# bunner-shared Detailed Specification

## Overview
bunner-shared는 Bunner 프레임워크의 공유 계약, 불변식, 공통 타입을 정의하는 레포지토리이다.

## Responsibilities

### L1 Invariants
다음 불변식을 정의하고 모든 패키지가 준수하도록 한다:

#### 1. Module Marker (from bunner/docs/10_FOUNDATION/01_INVARIANTS.md)
- 모든 모듈은 `module.fileName`으로 식별된다.
- 파일명 중복 시 first-match 원칙 적용.
- 모듈 파일에는 `defineModule()` 호출이 정확히 1개 존재해야 한다.

#### 2. File Attribution
- 모든 소스 파일은 정확히 하나의 모듈에 속한다.
- 파일 → 모듈 매핑은 디렉토리 구조 기반.
- Root 모듈은 `sourceDir` 직속 파일들을 관리.

#### 3. Dependency Direction
- Core → Common (허용)
- CLI → Core, Common (허용)
- Common → Core (금지)
- 순환 의존 금지

### Common Types

#### ApplicationConfig
```typescript
export interface ApplicationConfig {
  sourceDir: string;
  entry: string;
  modules: ModuleConfig[];
}
```

#### ModuleConfig
```typescript
export interface ModuleConfig {
  fileName: string; // Module marker
  imports?: string[]; // Other module fileNames
}
```

#### BunnerMetadata
```typescript
export interface BunnerMetadata {
  version: string;
  framework: 'bunner';
  invariants: InvariantVersion;
}
```

### Cross-Package Interfaces

#### ILogger (for bunner-logger)
```typescript
export interface ILogger {
  log(level: LogLevel, message: string, context?: object): void;
  error(error: Error, context?: object): void;
}
```

#### IDIContainer (for bunner-core)
```typescript
export interface IDIContainer {
  get<T>(token: Token<T>): T;
  register<T>(token: Token<T>, provider: Provider<T>): void;
}
```

## Export Structure

### Public API
- `src/types/common.ts` - CommonType exports
- `src/types/contracts.ts` - Interface exports
- `src/invariants/` - Invariant validators (runtime)

### Private Modules
- None (all exports are public for cross-package use)

## Versioning Strategy
- Semantic versioning: MAJOR.MINOR.PATCH
- MAJOR: Invariant 추가/삭제, breaking type change
- MINOR: New type 추가, non-breaking interface extension
- PATCH: Documentation, internal refactor

## Testing
- Unit tests for invariant validators
- Type tests (using `tsd` or similar)
- No integration tests (shared types only)

## Documentation
- `docs/INVARIANTS.md`: Full L1 content from bunner monorepo
- `docs/ARCHITECTURE.md`: Full L2 content from bunner monorepo
- Each invariant has:
  - Formal definition
  - Rationale
  - Validation rules
  - Examples

## Migration Notes
- Source: `bunner/docs/10_FOUNDATION/` → `bunner-shared/docs/INVARIANTS.md`
- Source: `bunner/docs/20_ARCHITECTURE/` → `bunner-shared/docs/ARCHITECTURE.md`
- All 40+ L3 specs stay in respective package repos (NOT in bunner-shared)

## Agent Workflow
1. Receive job to update invariant/type
2. Load `bunner-shared/docs/SPEC.md` (this file)
3. Load `bunner-shared/docs/INVARIANTS.md` (full L1)
4. Make changes
5. Update version in `package.json`
6. Generate changelog
7. Update central spec: `bunner-framework/specs/packages/shared.md`
8. Output artifact with breaking change analysis

## Special Considerations
- Changing invariants affects ALL packages → Orchestrator must plan carefully
- Type changes may require coordinated updates across multiple repos
- Deprecation policy: Mark deprecated types, remove in next MAJOR
```

---

### 2.3 Invariants Migration

**File**: `bunner-shared/docs/INVARIANTS.md`

**Content**: Full copy of `bunner/docs/10_FOUNDATION/01_INVARIANTS.md` with all sections:
- Module Marker
- File Attribution
- Dependency Direction
- Scope Rules
- Lifecycle Guarantees
- etc.

**Size**: ~800-1000 lines (detailed is good here)

---

### 2.4 Architecture Migration

**File**: `bunner-shared/docs/ARCHITECTURE.md`

**Content**: Full copy of `bunner/docs/20_ARCHITECTURE/` merged content:
- Structural boundaries
- Layering rules
- Module system architecture
- DI system architecture

**Size**: ~600-800 lines

---

### Phase 2 Deliverables Checklist
- [ ] `bunner-shared/AGENTS.md`
- [ ] `bunner-shared/docs/ROLE.md` (copy from central)
- [ ] `bunner-shared/docs/SPEC.md` (detailed)
- [ ] `bunner-shared/docs/INVARIANTS.md` (full L1)
- [ ] `bunner-shared/docs/ARCHITECTURE.md` (full L2)
- [ ] `bunner-shared/src/types/` (common types implementation)
- [ ] `bunner-shared/src/invariants/` (validators)
- [ ] Update `bunner-framework/specs/packages/shared.md` (central spec)

### Phase 2 Validation Criteria
- [ ] L1 Invariants fully migrated (no content loss)
- [ ] L2 Architecture fully migrated
- [ ] Common types compile without errors
- [ ] bunner-shared has no dependencies on other @bunner/* packages
- [ ] Central spec (`shared.md`) <200 lines

---

## Phase 3: Package Repository Migration

### Objectives
각 패키지 레포에 대해:
- AGENTS.md 배치
- docs/SPEC.md 작성 (상세, bunner/docs/30_SPEC/ 해당 내용 이관)
- docs/ROLE.md 배치 (중앙 스펙 복사)
- docs/DEPENDENCIES.md 작성 (의존성 문서)
- docs/ARCHITECTURE.md 작성 (내부 구조)
- 중앙 스펙 갱신 (bunner-framework/specs/packages/)

### Migration Order (의존성 역순)
1. bunner-common (no @bunner/* deps)
2. bunner-core (depends on: common)
3. bunner-logger (depends on: common)
4. bunner-http-adapter (depends on: core)
5. bunner-cli (depends on: core, common)
6. bunner-scalar (depends on: http-adapter)
7. bunner-firebat (depends on: common)
8. bunner-oxlint-plugin (standalone)
9. bunner-example (depends on: all)

---

### 3.1 bunner-common Migration

#### 3.1.1 File Structure
```
bunner-common/
  AGENTS.md
  package.json
  docs/
    ROLE.md                         # Copy from central
    SPEC.md                         # Detailed
    DEPENDENCIES.md
    ARCHITECTURE.md
    DECISIONS.md                    # Design decisions
  src/
    decorators/
    errors/
    helpers.ts
    # ... existing code
```

#### 3.1.2 AGENTS.md

**File**: `bunner-common/AGENTS.md`

**Content** (from Phase 0.3 template):
```markdown
# bunner-common Sub-Agent Operating Contract

## 1. Purpose
공통 유틸리티 및 데코레이터 패키지 전문 실행 에이전트의 운영 규약을 정의한다.

## 2. Authority & Scope

### 2.1 Identity
- Agent ID: `agent:bunner-common`
- Execution Environment: Docker container `agent-bunner-common`
- Workspace Root: `/work/repos/bunner-common`

### 2.2 Responsibility Scope
- 공통 데코레이터 (`@Injectable`, `@Module`, etc.)
- 공통 에러 클래스
- 헬퍼 함수 (타입 체킹, 유틸리티)
- 공통 인터페이스

## 3. Context Loading Rules
{Apply Phase 0.3 template}

Auto-load files:
- `bunner-framework/specs/packages/common.md` (자기 역할)
- `bunner-framework/specs/packages/shared.md` (bunner-shared API)
- `bunner-common/docs/SPEC.md`
- `bunner-common/docs/ARCHITECTURE.md`

## 4. Dependencies
- `@bunner/shared` - Common types only (no runtime dependency)

## 5. Dependents
- `@bunner/core`
- `@bunner/cli`
- `@bunner/logger`
- `@bunner/firebat`
- All other packages

## 6. Prohibited Actions
- Do NOT depend on `@bunner/core` (common is lower layer)
- Do NOT import from other packages except `@bunner/shared`

## 7. Violation Handling
{Apply Phase 0.3 template}
```

#### 3.1.3 SPEC.md

**File**: `bunner-common/docs/SPEC.md`

**Content** (detailed, from `bunner/docs/30_SPEC/common/*`):
```markdown
# bunner-common Detailed Specification

## Overview
bunner-common은 Bunner 프레임워크의 공통 유틸리티, 데코레이터, 에러 클래스를 제공하는 패키지이다.

## Public API

### Decorators

#### @Injectable()
```typescript
export function Injectable(options?: InjectableOptions): ClassDecorator;

interface InjectableOptions {
  scope?: 'singleton' | 'transient' | 'request';
  provide?: Token<any>;
}
```

**Purpose**: 클래스를 DI 컨테이너에 등록 가능하도록 마킹.

**Rules** (from bunner/docs/30_SPEC/di/di.spec.md):
- 클래스에만 적용 가능
- scope 기본값: `singleton`
- `provide` token 생략 시 클래스 자체가 token

**Example**:
```typescript
@Injectable({ scope: 'singleton' })
class UserService {
  // ...
}
```

#### @Module()
```typescript
export function Module(options: ModuleOptions): ClassDecorator;

interface ModuleOptions {
  imports?: ModuleClass[];
  providers?: Provider[];
  exports?: (Token<any> | Provider)[];
}
```

**Purpose**: 모듈 클래스 정의.

**Rules** (from bunner/docs/30_SPEC/module-system/define-module.spec.md):
- `defineModule()` 호출 대신 데코레이터 사용 가능
- `imports`: 다른 모듈 가져오기
- `providers`: DI 제공자 등록
- `exports`: 다른 모듈에 노출할 provider

### Error Classes

#### BunnerError
```typescript
export class BunnerError extends Error {
  constructor(message: string, public code: string);
}
```

#### DependencyError
```typescript
export class DependencyError extends BunnerError {
  constructor(message: string, public token: Token<any>);
}
```

#### ModuleNotFoundError
```typescript
export class ModuleNotFoundError extends BunnerError {
  constructor(public moduleName: string);
}
```

### Helpers

#### isClass()
```typescript
export function isClass(value: any): value is Class;
```

#### isConstructor()
```typescript
export function isConstructor(value: any): value is Constructor;
```

#### getMetadata()
```typescript
export function getMetadata<T>(key: string, target: object): T | undefined;
```

#### setMetadata()
```typescript
export function setMetadata(key: string, value: any, target: object): void;
```

## Internal Architecture

### Metadata Storage
- Uses `reflect-metadata` polyfill
- Metadata keys prefixed with `bunner:`
- Storage structure:
```typescript
{
  'bunner:injectable': InjectableOptions,
  'bunner:module': ModuleOptions,
  'bunner:design:paramtypes': Type[],
}
```

### Decorator Implementation
- Decorators are implemented as higher-order functions
- Use `setMetadata()` to attach options to class
- No runtime logic (metadata only)

## Dependencies

### Runtime
- None (standalone utilities)

### Type-only
- `@bunner/shared` - Common types import

## Testing
- Unit tests for each decorator
- Unit tests for each helper
- Error class tests
- Metadata storage tests

## Versioning
- MAJOR: Breaking API changes (decorator signature)
- MINOR: New decorator, new helper
- PATCH: Bug fix, internal refactor

## Migration Notes
- Source: `bunner/docs/30_SPEC/common/` → this file
- Source: `bunner/packages/common/` → implementation
- All decorator specs preserved

## Agent Workflow
1. Receive job (e.g., "Add new @Transient decorator")
2. Load context:
   - `bunner-framework/specs/packages/common.md` (role)
   - `bunner-common/docs/SPEC.md` (this file)
   - `bunner-common/docs/ARCHITECTURE.md`
3. Implement decorator in `src/decorators/`
4. Add tests
5. Update this SPEC.md
6. Update central spec if Public API changed
7. Output artifact
```

**Size**: ~1,000-2,000 lines (detailed)

#### 3.1.4 DEPENDENCIES.md

**File**: `bunner-common/docs/DEPENDENCIES.md`

**Content**:
```markdown
# bunner-common Dependencies

## Direct Dependencies

### @bunner/shared
- **Type**: Type-only (no runtime)
- **Used APIs**:
  - `CommonType` interface
  - `Token<T>` type
- **Why**: Shared type definitions
- **Version**: `^1.0.0`

### reflect-metadata
- **Type**: Runtime polyfill
- **Used APIs**: Global `Reflect.metadata`
- **Why**: Decorator metadata storage
- **Version**: `^0.2.2`

## Dependents (Reverse Dependencies)

### @bunner/core
- Uses decorators: `@Injectable`, `@Module`
- Imports error classes

### @bunner/cli
- Uses helpers: `isClass()`, `isConstructor()`
- Imports error classes

### @bunner/logger
- Uses helpers for validation

## Dependency Constraints
- MUST NOT depend on `@bunner/core` (layering violation)
- MUST NOT depend on any package except `@bunner/shared`
- Keep zero runtime dependencies (except reflect-metadata)

## Version Compatibility
- Compatible with all @bunner/* packages `>=1.0.0`
- Breaking changes require coordinated update across all dependents
```

#### 3.1.5 ARCHITECTURE.md

**File**: `bunner-common/docs/ARCHITECTURE.md`

**Content**:
```markdown
# bunner-common Internal Architecture

## Module Structure
```
src/
  decorators/
    injectable.decorator.ts
    module.decorator.ts
    index.ts
  errors/
    bunner-error.ts
    dependency-error.ts
    module-not-found-error.ts
    index.ts
  helpers/
    is-class.ts
    is-constructor.ts
    metadata.ts
    index.ts
  types.ts
  index.ts                      # Main entry
```

## Design Decisions

### Why decorators over plain functions?
- TypeScript decorator syntax는 메타데이터 자동 첨부
- Angular/NestJS와 유사한 API (친숙함)
- AOT 스캐닝 용이 (decorator = static marker)

### Why separate error classes?
- 타입 안전한 에러 핸들링
- `instanceof` 체크 가능
- 에러별 특수 필드 (e.g., `DependencyError.token`)

### Metadata key naming convention
- Prefix `bunner:` to avoid conflicts
- Use descriptive names (`bunner:injectable` not `b:i`)

## Patterns

### Decorator Factory Pattern
```typescript
export function Injectable(options?: InjectableOptions): ClassDecorator {
  return (target: any) => {
    setMetadata('bunner:injectable', options || {}, target);
  };
}
```

### Error Hierarchy
```
Error (native)
  └─ BunnerError (base)
       ├─ DependencyError
       ├─ ModuleNotFoundError
       └─ ... (extensible)
```

## Testing Strategy
- Unit tests: Each function isolated
- Integration tests: None (common is utilities only)
- Coverage target: >90%

## Performance Considerations
- Decorators: Zero runtime cost (metadata only)
- Helpers: Inline-able (simple type checks)
- Errors: Standard JS Error performance

## Future Extensions
- More decorators (e.g., `@Transient`, `@Scoped`)
- More helpers (e.g., `isPromise`, `isObservable`)
- Validation utilities (e.g., `validateModuleOptions`)
```

#### 3.1.6 Central Spec Update

**File**: `bunner-framework/specs/packages/common.md`

**Content** (concise, <200 lines):
```markdown
# Package: bunner-common

## Role
Common utilities, decorators, and error classes for all Bunner packages.

## Public API

### Decorators
- `@Injectable(options?)` - Mark class as injectable
- `@Module(options)` - Define module with imports/providers/exports

### Error Classes
- `BunnerError` - Base error
- `DependencyError` - DI resolution failure
- `ModuleNotFoundError` - Module lookup failure

### Helpers
- `isClass(value)` - Type guard for class
- `isConstructor(value)` - Type guard for constructor
- `getMetadata<T>(key, target)` - Retrieve metadata
- `setMetadata(key, value, target)` - Store metadata

### Types
```typescript
interface InjectableOptions {
  scope?: 'singleton' | 'transient' | 'request';
  provide?: Token<any>;
}

interface ModuleOptions {
  imports?: ModuleClass[];
  providers?: Provider[];
  exports?: (Token<any> | Provider)[];
}
```

## Dependencies
- `@bunner/shared` (type-only)

## Dependents
- `@bunner/core`
- `@bunner/cli`
- `@bunner/logger`
- `@bunner/firebat`

## Constraints
- No runtime dependencies (except reflect-metadata)
- MUST NOT depend on `@bunner/core` (layering)

## Status
- Version: `1.0.0`
- Stability: `stable`
- Last Updated: `2026-02-02`

## Agent
- Sub-agent: `agent:bunner-common`
- Container: `agent-bunner-common`
- Local spec: `bunner-common/docs/SPEC.md`
```

**Size**: ~180 lines ✅

---

### 3.2-3.9 Other Package Migrations

Repeat the same structure for:
- **bunner-core**: DI container, lifecycle, application
- **bunner-logger**: Logging system
- **bunner-http-adapter**: HTTP layer
- **bunner-cli**: CLI tool
- **bunner-scalar**: API docs
- **bunner-firebat**: Code quality
- **bunner-oxlint-plugin**: Linting plugin
- **bunner-example**: Integration examples

Each includes:
1. `AGENTS.md` (from Phase 0.3 template)
2. `docs/SPEC.md` (detailed, from bunner/docs/30_SPEC/<pkg>/)
3. `docs/DEPENDENCIES.md`
4. `docs/ARCHITECTURE.md`
5. Update central spec (`bunner-framework/specs/packages/<pkg>.md`)

---

### Phase 3 Deliverables Checklist (Per Package)
For each of 10 packages:
- [ ] `<repo>/AGENTS.md`
- [ ] `<repo>/docs/ROLE.md` (copy from central)
- [ ] `<repo>/docs/SPEC.md` (detailed, >500 lines OK)
- [ ] `<repo>/docs/DEPENDENCIES.md`
- [ ] `<repo>/docs/ARCHITECTURE.md`
- [ ] `bunner-framework/specs/packages/<pkg>.md` (<200 lines)

Total files: 10 repos × 6 files = **60 files**

### Phase 3 Validation Criteria
- [ ] All L3 specs from `bunner/docs/30_SPEC/` migrated (no content loss)
- [ ] All central specs <200 lines
- [ ] All local specs >500 lines (detailed)
- [ ] Dependency graph matches package.json
- [ ] No cross-repo imports except via public API
- [ ] Each agent context <5,000 lines when loaded

---

## Phase 4: AgentOps Integration

### Objectives
- MCP 서버에 컨텍스트 로딩 로직 구현
- 워커 설정 업데이트 (workers.json)
- Gateway 연동 검증
- 자동 로딩 알고리즘 테스트

### 4.1 Context Loader Implementation

**File**: `bunner-agentops/apps/mcp-server/src/context-loader.ts`

**Content** (~300 lines):
```typescript
import { resolve } from 'node:path';
import { readFile } from 'node:fs/promises';

interface LoadedContext {
  files: Array<{ path: string; content: string; size: number }>;
  totalSize: number;
}

/**
 * Orchestrator context loading (for planning)
 */
export async function loadOrchestratorContext(
  userRequest: string,
  workspaceRoot: string,
): Promise<LoadedContext> {
  const files: Array<{ path: string; content: string; size: number }> = [];
  
  // 1. Always load overview
  const overviewPath = resolve(workspaceRoot, 'bunner-framework/specs/OVERVIEW.md');
  const overviewContent = await readFile(overviewPath, 'utf-8');
  files.push({ path: overviewPath, content: overviewContent, size: overviewContent.length });
  
  // 2. Extract mentioned packages from user request
  const mentionedPackages = extractPackages(userRequest);
  
  // 3. Load central specs for mentioned packages
  for (const pkg of mentionedPackages) {
    const specPath = resolve(workspaceRoot, `bunner-framework/specs/packages/${pkg}.md`);
    const specContent = await readFile(specPath, 'utf-8');
    files.push({ path: specPath, content: specContent, size: specContent.length });
  }
  
  // 4. Load dependency specs (transitive)
  const deps = await findDependencies(mentionedPackages, workspaceRoot);
  for (const dep of deps) {
    const depSpecPath = resolve(workspaceRoot, `bunner-framework/specs/packages/${dep}.md`);
    const depSpecContent = await readFile(depSpecPath, 'utf-8');
    files.push({ path: depSpecPath, content: depSpecContent, size: depSpecContent.length });
  }
  
  const totalSize = files.reduce((sum, f) => sum + f.size, 0);
  
  return { files, totalSize };
}

/**
 * Sub-agent context loading (for execution)
 */
export async function loadSubAgentContext(
  job: AgentOpsJob,
  workspaceRoot: string,
): Promise<LoadedContext> {
  const files: Array<{ path: string; content: string; size: number }> = [];
  const repo = job.workspaceRef.repo!;
  
  // 1. Load central role spec
  const centralSpecPath = resolve(workspaceRoot, `bunner-framework/specs/packages/${repo}.md`);
  const centralSpecContent = await readFile(centralSpecPath, 'utf-8');
  files.push({ path: centralSpecPath, content: centralSpecContent, size: centralSpecContent.length });
  
  // 2. Load local docs
  const localDocs = ['ROLE.md', 'DEPENDENCIES.md', 'ARCHITECTURE.md', 'SPEC.md'];
  for (const doc of localDocs) {
    const docPath = resolve(workspaceRoot, `${repo}/docs/${doc}`);
    try {
      const docContent = await readFile(docPath, 'utf-8');
      files.push({ path: docPath, content: docContent, size: docContent.length });
    } catch {
      // Document may not exist (e.g., DECISIONS.md is optional)
    }
  }
  
  // 3. Parse package.json for dependencies
  const pkgJsonPath = resolve(workspaceRoot, `${repo}/package.json`);
  const pkgJson = JSON.parse(await readFile(pkgJsonPath, 'utf-8'));
  const bunnerDeps = Object.keys(pkgJson.dependencies || {})
    .filter(dep => dep.startsWith('@bunner/'))
    .map(dep => dep.replace('@bunner/', ''));
  
  // 4. Load dependency PUBLIC APIs (central specs only)
  for (const dep of bunnerDeps) {
    const depSpecPath = resolve(workspaceRoot, `bunner-framework/specs/packages/${dep}.md`);
    const depSpecContent = await readFile(depSpecPath, 'utf-8');
    files.push({ path: depSpecPath, content: depSpecContent, size: depSpecContent.length });
  }
  
  // 5. Semantic search for relevant code (simplified: load main entry)
  const entryPath = resolve(workspaceRoot, `${repo}/src/index.ts`);
  try {
    const entryContent = await readFile(entryPath, 'utf-8');
    files.push({ path: entryPath, content: entryContent, size: entryContent.length });
  } catch {
    // Entry may not exist
  }
  
  const totalSize = files.reduce((sum, f) => sum + f.size, 0);
  
  // Alert if oversized (>10,000 lines)
  if (totalSize > 10000) {
    console.warn(`[Context Warning] Sub-agent ${repo} context size: ${totalSize} chars (>10k)`);
  }
  
  return { files, totalSize };
}

/**
 * Extract package names mentioned in user request
 */
function extractPackages(request: string): string[] {
  const packages = [
    'cli', 'core', 'common', 'http-adapter',
    'logger', 'scalar', 'firebat', 'oxlint-plugin',
    'shared', 'example', 'agentops',
  ];
  
  return packages.filter(pkg => {
    const patterns = [
      new RegExp(`\\bbunner-${pkg}\\b`, 'i'),
      new RegExp(`\\b${pkg}\\b`, 'i'),
      new RegExp(`@bunner/${pkg}`, 'i'),
    ];
    return patterns.some(p => p.test(request));
  });
}

/**
 * Find transitive dependencies for given packages
 */
async function findDependencies(
  packages: string[],
  workspaceRoot: string,
): Promise<string[]> {
  const allDeps = new Set<string>();
  
  for (const pkg of packages) {
    const pkgJsonPath = resolve(workspaceRoot, `bunner-${pkg}/package.json`);
    try {
      const pkgJson = JSON.parse(await readFile(pkgJsonPath, 'utf-8'));
      const deps = Object.keys(pkgJson.dependencies || {})
        .filter(dep => dep.startsWith('@bunner/'))
        .map(dep => dep.replace('@bunner/', ''));
      deps.forEach(d => allDeps.add(d));
    } catch {
      // Package may not exist yet
    }
  }
  
  // Remove already-mentioned packages
  packages.forEach(p => allDeps.delete(p));
  
  return Array.from(allDeps);
}
```

### 4.2 MCP Server Integration

**File**: `bunner-agentops/apps/mcp-server/src/tools.ts`

**Modify** `agentops.submitPipeline` tool to include context loading:

```typescript
server.tool(
  'agentops.submitPipeline',
  {
    pipeline: z.any(),
    userRequest: z.string().optional(), // Add user request for context
  },
  async (args) => {
    const req = args as SubmitPipelineRequest & { userRequest?: string };
    const createdAt = req.pipeline.createdAt ?? nowIso();
    const pipeline: AgentOpsPipeline = {
      ...req.pipeline,
      createdAt,
    };
    
    // Validate routing
    validatePipelineRoutable(pipeline);
    
    // Load orchestrator context (for logging/debugging)
    if (req.userRequest) {
      const context = await loadOrchestratorContext(req.userRequest, process.env.BUNNER_WORKDIR || '/work');
      console.log(`[Context] Orchestrator loaded ${context.files.length} files, ${context.totalSize} chars`);
    }
    
    const run = store.createRun(pipeline);
    const res: SubmitPipelineResponse = { runId: run.runId };
    return jsonText(res);
  },
);
```

### 4.3 Runner Integration

**File**: `bunner-agentops/apps/mcp-server/src/runner.ts`

**Modify** job execution to load sub-agent context:

```typescript
async function executeJob(job: AgentOpsJob, worker: WorkerTarget): Promise<void> {
  // Load sub-agent context
  const context = await loadSubAgentContext(job, process.env.BUNNER_WORKDIR || '/work');
  console.log(`[Context] Sub-agent ${job.workspaceRef.repo} loaded ${context.files.length} files, ${context.totalSize} chars`);
  
  // Execute job (existing docker exec logic)
  // ...
}
```

### 4.4 Workers Config Update

**File**: `bunner-agentops/workers.json`

**Update** to include all 12 repos:

```json
{
  "workers": [
    {
      "id": "agent-bunner-framework",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-framework"],
      "docker": { "service": "agent-bunner-framework", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-agentops",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-agentops"],
      "docker": { "service": "agent-bunner-agentops", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-shared",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-shared"],
      "docker": { "service": "agent-bunner-shared", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-example",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-example"],
      "docker": { "service": "agent-bunner-example", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-cli",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-cli"],
      "docker": { "service": "agent-bunner-cli", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-core",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-core"],
      "docker": { "service": "agent-bunner-core", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-common",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-common"],
      "docker": { "service": "agent-bunner-common", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-http-adapter",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-http-adapter"],
      "docker": { "service": "agent-bunner-http-adapter", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-logger",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-logger"],
      "docker": { "service": "agent-bunner-logger", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-scalar",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-scalar"],
      "docker": { "service": "agent-bunner-scalar", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-firebat",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-firebat"],
      "docker": { "service": "agent-bunner-firebat", "workdir": "/work" }
    },
    {
      "id": "agent-bunner-oxlint-plugin",
      "kind": "docker",
      "queue": "default",
      "labels": ["repo:bunner-oxlint-plugin"],
      "docker": { "service": "agent-bunner-oxlint-plugin", "workdir": "/work" }
    }
  ]
}
```

### Phase 4 Deliverables Checklist
- [ ] `bunner-agentops/apps/mcp-server/src/context-loader.ts` (new file)
- [ ] `bunner-agentops/apps/mcp-server/src/tools.ts` (modified)
- [ ] `bunner-agentops/apps/mcp-server/src/runner.ts` (modified)
- [ ] `bunner-agentops/workers.json` (updated with 12 workers)
- [ ] `bunner-agentops/docker-compose.yml` (add missing services)
- [ ] `bunner-agentops/docs/CONTEXT_LOADING.md` (documentation)

### Phase 4 Validation Criteria
- [ ] Context loader unit tests pass
- [ ] Orchestrator context <2,000 lines
- [ ] Sub-agent context <5,000 lines
- [ ] All 12 workers routable
- [ ] Docker containers start successfully
- [ ] MCP server handles pipeline submission with context logging

---

## Phase 5: Validation & Migration

### Objectives
- 크로스 레포 작업 시뮬레이션
- 컨텍스트 로딩 실제 검증
- bunner/ 레포 docs 아카이빙
- 최종 문서 검토

### 5.1 Cross-Repo Task Simulation

**Scenario**: "bunner-core DI 시스템 개선 + bunner-cli 연동"

#### 5.1.1 Orchestrator Planning (Manual Test)
```bash
# In VS Code Copilot Chat
User: "bunner-core의 DI Container API 개선하고, bunner-cli에서 새 API 사용하도록 수정"

Expected Context Loading:
- bunner-framework/specs/OVERVIEW.md
- bunner-framework/specs/packages/core.md
- bunner-framework/specs/packages/cli.md
- bunner-framework/specs/packages/common.md (dependency)
Total: ~4 files, ~800 lines

Expected Output: AgentOpsPipeline with 2 jobs
```

#### 5.1.2 Sub-Agent Execution (Simulated)
```bash
# Job 1: agent:bunner-core
cd bunner-agentops
./scripts/task-run.sh test-task-001 bunner-core -- echo "Simulating job"

Expected Context Loading:
- bunner-framework/specs/packages/core.md (central)
- bunner-core/docs/SPEC.md
- bunner-core/docs/ARCHITECTURE.md
- bunner-framework/specs/packages/common.md (dependency)
- bunner-core/src/index.ts
Total: ~5 files, ~3,000 lines

# Job 2: agent:bunner-cli
./scripts/task-run.sh test-task-001 bunner-cli -- echo "Simulating job"

Expected Context Loading:
- bunner-framework/specs/packages/cli.md
- bunner-cli/docs/SPEC.md
- bunner-cli/docs/ARCHITECTURE.md
- bunner-framework/specs/packages/core.md (updated API)
- bunner-framework/specs/packages/common.md
- bunner-cli/src/index.ts
Total: ~6 files, ~4,000 lines
```

### 5.2 Context Size Verification

**Test Script**: `bunner-agentops/scripts/verify-context-size.sh`

```bash
#!/bin/bash
set -e

WORKDIR=${BUNNER_WORKDIR:-./.work}

echo "=== Context Size Verification ==="
echo ""

# Test orchestrator context for various scenarios
scenarios=(
  "bunner-cli dev server"
  "bunner-core DI system"
  "bunner-http-adapter routing"
  "bunner-cli and bunner-core integration"
)

for scenario in "${scenarios[@]}"; do
  echo "Scenario: $scenario"
  # Simulate context loading (call context-loader)
  bun run apps/mcp-server/src/context-loader.ts orchestrator "$scenario" "$WORKDIR"
  echo ""
done

# Test sub-agent context for each repo
repos=(
  bunner-cli
  bunner-core
  bunner-common
  bunner-http-adapter
  bunner-logger
  bunner-scalar
  bunner-firebat
  bunner-oxlint-plugin
  bunner-shared
  bunner-example
)

for repo in "${repos[@]}"; do
  echo "Sub-agent: $repo"
  bun run apps/mcp-server/src/context-loader.ts sub-agent "$repo" "$WORKDIR"
  echo ""
done

echo "=== Verification Complete ==="
```

### 5.3 bunner/ Repo Archival

**Action**: Archive old docs, DO NOT DELETE (for reference)

```bash
cd bunner
mkdir -p archived/docs-monorepo-$(date +%Y%m%d)
mv docs/* archived/docs-monorepo-$(date +%Y%m%d)/
echo "# Archived Documentation" > docs/README.md
echo "" >> docs/README.md
echo "Documentation has been migrated to:" >> docs/README.md
echo "- Central specs: bunner-framework/specs/" >> docs/README.md
echo "- Package specs: <repo>/docs/SPEC.md" >> docs/README.md
echo "" >> docs/README.md
echo "Archived monorepo docs: archived/docs-monorepo-YYYYMMDD/" >> docs/README.md
```

### 5.4 Final Documentation Review

**Checklist**:
- [ ] All central specs <200 lines (strict)
- [ ] All local specs >500 lines (detailed)
- [ ] No broken cross-references
- [ ] All AGENTS.md follow template
- [ ] All 12 repos have complete docs/
- [ ] Dependency graph correct in all specs
- [ ] Context loading achieves 80% reduction target

### Phase 5 Deliverables Checklist
- [ ] Cross-repo task simulation successful
- [ ] Context size verification script
- [ ] Context size measurements logged
- [ ] bunner/docs archived (not deleted)
- [ ] Final documentation review complete
- [ ] Migration guide written

### Phase 5 Validation Criteria
- [ ] Orchestrator context consistently <2,000 lines
- [ ] Sub-agent context consistently <5,000 lines
- [ ] 80% reduction achieved vs. monorepo baseline
- [ ] All 12 repos pass local tests
- [ ] Cross-repo workflow end-to-end successful

---

## Rollout Strategy

### Stage 1: Foundation (Week 1)
- Phase 0: Design templates
- Phase 1: Central repo (bunner-framework)
- Phase 2: Shared repo (bunner-shared)
- **Milestone**: Orchestrator can read central specs

### Stage 2: Package Migration (Week 2-3)
- Phase 3.1-3.3: Leaf packages (common, logger, oxlint-plugin)
- Phase 3.4-3.6: Mid-tier packages (core, http-adapter, firebat)
- Phase 3.7-3.9: Top-tier packages (cli, scalar, example)
- **Milestone**: All packages have AGENTS.md + docs/

### Stage 3: Integration (Week 4)
- Phase 4: AgentOps integration
- Phase 5: Validation
- **Milestone**: End-to-end workflow functional

### Stage 4: Dogfooding (Week 5+)
- Use new architecture for real tasks
- Iterate based on agent performance
- **Milestone**: 80% context reduction verified in production

---

## Success Metrics

### Quantitative
- [ ] Central spec size: <200 lines per package (strict)
- [ ] Orchestrator context: <2,000 lines per planning session
- [ ] Sub-agent context: <5,000 lines per job execution
- [ ] Context reduction: ≥80% vs. monorepo baseline (~15,000 lines)
- [ ] All 12 repos migrated

### Qualitative
- [ ] Agent accuracy improved (fewer hallucinations)
- [ ] Agent understands specs on first read (no missed details)
- [ ] Cross-repo tasks complete without manual intervention
- [ ] Developers find specs readable (central = 5min read)
- [ ] Sub-agents work within their scope (no cross-repo violations)

---

## Risk Mitigation

### Risk 1: Central specs exceed 200 lines
**Mitigation**: Strict review + automated size check in CI

### Risk 2: Agent ignores context loading rules
**Mitigation**: MCP server enforces loading, logs violations

### Risk 3: Cross-references break during migration
**Mitigation**: Automated link checker, validate all references

### Risk 4: Dependency graph inconsistency
**Mitigation**: Script to parse package.json + verify against central specs

### Risk 5: Context still too large
**Mitigation**: Further split large packages, or introduce sub-modules

---

## Appendix A: File Count Summary

| Phase | Files Created | Files Modified | Total |
|-------|---------------|----------------|-------|
| Phase 0 | 4 templates | 0 | 4 |
| Phase 1 | 16 (central specs + AGENTS.md) | 0 | 16 |
| Phase 2 | 6 (bunner-shared) | 1 (central spec) | 7 |
| Phase 3 | 60 (10 repos × 6 files) | 10 (central specs) | 70 |
| Phase 4 | 2 (context-loader + doc) | 3 (MCP tools/runner + workers.json) | 5 |
| Phase 5 | 1 (verify script) | 0 | 1 |
| **Total** | **89** | **14** | **103** |

---

## Appendix B: Dependency Matrix

| Package | Dependencies | Dependents |
|---------|--------------|------------|
| bunner-shared | None | All |
| bunner-common | shared | core, cli, logger, firebat |
| bunner-core | common, shared | cli, http-adapter |
| bunner-logger | common, shared | (optional by all) |
| bunner-http-adapter | core, shared | scalar, cli |
| bunner-cli | core, common, shared | None |
| bunner-scalar | http-adapter, shared | None |
| bunner-firebat | common, shared | None |
| bunner-oxlint-plugin | None | None |
| bunner-example | All | None |

---

## Appendix C: Context Loading Examples

### Example 1: Orchestrator Planning
**User Request**: "Implement request logging in bunner-http-adapter"

**Auto-loaded files**:
1. `bunner-framework/specs/OVERVIEW.md` (50 lines)
2. `bunner-framework/specs/packages/http-adapter.md` (180 lines)
3. `bunner-framework/specs/packages/core.md` (190 lines, dependency)
4. `bunner-framework/specs/packages/logger.md` (150 lines, implied)

**Total**: 570 lines (~80% reduction from ~15,000)

### Example 2: Sub-Agent Execution
**Job**: "Add request logging to http-adapter"

**Auto-loaded files**:
1. `bunner-framework/specs/packages/http-adapter.md` (180 lines)
2. `bunner-http-adapter/docs/ROLE.md` (180 lines, copy)
3. `bunner-http-adapter/docs/SPEC.md` (1,200 lines)
4. `bunner-http-adapter/docs/ARCHITECTURE.md` (800 lines)
5. `bunner-framework/specs/packages/core.md` (190 lines)
6. `bunner-framework/specs/packages/logger.md` (150 lines)
7. `bunner-http-adapter/src/index.ts` (300 lines)

**Total**: 3,000 lines (~70% reduction)

---

## Appendix D: Template Inventory

### Templates Created in Phase 0
1. `bunner-framework/AGENTS.md` (orchestrator contract)
2. `bunner-framework/specs/packages/_TEMPLATE.md` (central spec)
3. `<repo>/AGENTS.md` (sub-agent contract)
4. `bunner-agentops/docs/CONTEXT_LOADING.md` (algorithm spec)

### Templates Applied in Phase 3
- 10 repos × 1 AGENTS.md = 10 instances
- 10 repos × 1 central spec = 10 instances

**Total template applications**: 20

---

## Next Steps After Plan Approval

1. **Phase 0 Execution**: Finalize all 4 templates
2. **Pilot Migration**: bunner-common only (test workflow)
3. **Validation**: Measure context size for bunner-common
4. **Full Rollout**: If pilot successful, proceed with remaining 9 repos
5. **Dogfooding**: Use new architecture for next real task

---

**Plan Status**: ✅ Ready for Review  
**Estimated Effort**: 4-5 weeks (1 phase per week)  
**Risk Level**: Medium (large scope, but incremental)  
**Approval Required**: Yes (user must approve before Phase 1 execution)
