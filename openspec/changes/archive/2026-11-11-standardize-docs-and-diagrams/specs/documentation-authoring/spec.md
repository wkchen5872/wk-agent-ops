## Purpose

建立跨工具一致的文件與圖稿交付契約，讓新讀者及長時間後回訪的維護者能理解用途、操作方式與目前有效設計，同時保留來源、驗證限制及既有文件的漸進遷移能力。

## ADDED Requirements

### Requirement: Shared authoring policy activation
Agents SHALL read the shared authoring policy before creating or updating documentation or design diagrams, including nested module docs and Work Item diagrams. The policy SHALL remain reachable through the tool-neutral protocol and SHALL NOT depend on invoking a skill.

#### Scenario: Nested docs or standalone diagram task
- **WHEN** a task targets module documentation or a Work Item diagram outside root docs
- **THEN** the shared protocol directs the agent to the same authoring policy
- **AND** Work Item-specific record, storage and handoff rules reside in its convention, with shared visual rules referenced rather than duplicated
- **AND** schema-owned OpenSpec artifacts and historical records retain their own structure

### Requirement: OKF v0.2 authoring and bounded migration
The policy SHALL distinguish OKF requirements from project conventions, document v0.2 metadata and source attribution, and migrate only new or substantively edited documents. Existing unrelated documents, unknown extension fields and historical evidence MUST be preserved.

#### Scenario: New concept document
- **WHEN** a new non-reserved document is authored in a documentation bundle
- **THEN** it has parseable frontmatter with type and the project-required title, description and tags
- **AND** known production metadata uses generated.by and generated.at rather than a new timestamp field
- **AND** sourced claims use stable footnote labels matching sources entries with resource values

#### Scenario: Legacy document migration
- **WHEN** an existing document with timestamp and a Citations list receives a substantive update
- **THEN** applicable metadata and citations migrate without inventing original authors or verification
- **AND** unknown source-to-claim mappings are reported for review rather than guessed
- **AND** unrelated legacy documents are not rewritten or declared invalid solely for legacy fields

#### Scenario: Optional trust and lifecycle fields
- **WHEN** verification evidence is absent or the implementation is not deployed
- **THEN** no verified event or deployment success is fabricated
- **AND** status uses document lifecycle values draft, stable or deprecated when present; implementation and deployment state remain separately described

#### Scenario: Reserved files and links
- **WHEN** index.md, log.md or cross-links are authored
- **THEN** reserved files follow OKF structures, with optional okf_version only at the bundle-root index
- **AND** links use bundle-relative or document-relative paths, never personal absolute paths

### Requirement: API documentation explains usable contracts
API documentation SHALL explain purpose, environment/version, HTTP method and path, authentication, parameters, request and response examples, response field meanings, and common errors with remedies. Examples MUST identify placeholders, synthetic data and unverified behavior.

#### Scenario: Reader calls an endpoint
- **WHEN** a reader follows an API document
- **THEN** required parameters, types, locations and constraints are explicit and a complete request is available
- **AND** response status, fields, units and missing-value meanings are explained where applicable
- **AND** errors identify symptoms, causes and corrective actions without exposing credentials

### Requirement: Operation documents support beginners
Operation documents SHALL contain prerequisites, numbered steps, execution directory, executable commands with substitution instructions, expected results, completion checks and troubleshooting Q&A. Destructive or externally consequential steps MUST describe their effects before execution.

#### Scenario: First-time operation
- **WHEN** a reader has no prior session context
- **THEN** prerequisites and steps provide enough information to attempt the operation in order
- **AND** each meaningful step explains how to recognize success and common failures
- **AND** unexecuted instructions are not described as tested

### Requirement: Current design without conversation history
Design and specification documentation SHALL explain purpose, scope, concepts, component responsibilities, rules and limitations using currently effective decisions. It MUST retain necessary technical rationale and distinguish approved design, implementation, deployment and verification. Discussion narratives and superseded options SHALL remain outside current reference prose.

#### Scenario: A design decision changes
- **WHEN** a current design document is updated
- **THEN** contradictory or duplicate affected statements and diagrams are reconciled
- **AND** it describes the selected architecture directly without attributing it to a user conversation
- **AND** historical archives and evidence are not erased and proposed behavior is not presented as deployed

### Requirement: Deliver viewable diagrams in the appropriate format
Flowcharts, sequence diagrams, architecture diagrams and static graphic/layout designs SHALL default to standalone SVG. Designs requiring UX interaction SHALL use HTML. Explicit requested formats take precedence; practical exceptions MUST explain the limitation. Editable sources alone SHALL NOT substitute for a viewable deliverable.

#### Scenario: Static versus interactive review
- **WHEN** a design only needs visual review
- **THEN** SVG is delivered and linked or embedded from its related document
- **AND** an interactive HTML prototype is used when clicking, switching or entering input is required

#### Scenario: Diagram storage and validation
- **WHEN** a diagram is delivered or updated
- **THEN** it resides in the owning document diagrams directory or the Work Item diagrams directory defined by its own convention with portable links
- **AND** labels, states and flows match the document; complex content is split when needed for readability
- **AND** syntax/link checks and actual rendered inspection for clipping, overlap, arrows and readable zoom are distinguished
- **AND** unavailable visual verification is explicitly reported, not claimed as passed
