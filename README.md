# Everyday — Contract

The shared, contracts-only Swift package for Everyday. This repository is independent of
`Everyday - Host Application` and `Everyday - User Application`. Dependency direction is:

```text
Host Application ──► Contract ◄── User Application
Contract ──► no application
```

The package contains protocol definitions, synchronization contracts, compatibility rules, schema
validation, and contract-level security expectations. It contains no Host services, persistence,
execution, orchestration, adapters, User Application views, navigation, presentation, or state
management.

## Package structure

- `Package.swift` — SwiftPM manifest with the `EverydayContract` library product and
  `EverydayContractTests` test target. The package declares no external dependencies.
- `Sources/EverydayContract/` — the shared contract library.
- `Tests/EverydayContractTests/` — compatibility, versioning, synchronization, and validation tests.
- `Tests/EverydayContractTests/Fixtures/` — checked-in JSON contract fixtures.

## Contract surface

### Message envelope

Every message carries message, correlation, optional causation, session/device binding, optional Host
identity and position, protocol and schema versions, payload kind, optional idempotency key, and
origin. Host-authored state messages require Host identity and Host position.

Payload kinds are `request`, `response`, `event`, `acknowledgement`, `error`, and `heartbeat`.
`AcknowledgementMeaning.transportReceipt`, `.hostAcceptance`, and `.completionOutcome` are distinct
reported meanings: a transport receipt is not Host acceptance, and Host acceptance is not a completion
outcome or approval. A delivery receipt is never approval.

Structural origin checks require `client` origin for requests and `host` origin for responses and
events. Binding checks require a session or device identifier on non-heartbeat messages. These checks
only validate message shape; they do not authenticate a sender, verify a credential, or establish
freshness. Contract does not replace Host authority, Host execution state, or durable decision
records, and an acknowledgement never grants authority.

### Requests and responses

Requests may be a query, a command, or a synchronization operation. Commands carry an idempotency
key; command parameters are bounded JSON intent, never authority. The shared `CommandKind` cases do
not define per-command parameter schemas, required targets, consequences, approval semantics, or
authority effects. Those rules belong to the Host, which remains the source of truth for every
projection. `CommandRequest.payload` is an optional typed payload used only where a command cannot
safely carry its subject through generic parameters.

Responses carry query results, command outcomes, or synchronization results. A `CommandResult` may
be positionless when no committed position applies. When it reports a position, the envelope must
carry matching Host identity and position; `acceptedMessageID` is a structural reference to the
command being answered, not evidence that the Host authorized or completed the command.

### Conversation message submission and publication

`CommandKind.submitConversationMessage` is a Client-origin command intent targeting one conversation.
It requires `CommandPayload.conversationMessageSubmission` with an explicit `ConversationID` matching
`CommandRequest.target` and a typed `ConversationMessageBody`. It requires the standard envelope
idempotency key; it rejects generic parameters, Client-supplied Host identity or Host position, and
unknown fields. It carries no approval, tool, objective, task, execution, attachment, image, file, or
artifact fields. Contract does not authenticate the sender, authorize the command, persist the
message, invoke inference, or publish content.

A `ConversationMessageBody` must contain at least one non-whitespace character after trimming. The
original string is retained. The exact inclusive limits are:

| Limit | Constant | Value |
|---|---|---|
| UTF-8 bytes | `ConversationMessageBody.maximumUTF8Bytes` | 1,048,576 (1 MiB) |
| Unicode scalars | `ConversationMessageBody.maximumUnicodeScalars` | 524,288 (one half of the byte ceiling, so both limits are independently enforceable) |

The whole encoded `ContractMessage` is still subject to `ContractLimits.maximumMessageBytes`, so a
body near the body ceiling can make the complete message exceed the wire ceiling. Contract rejects
oversized bodies at the validated boundary; it does not silently increase an existing limit.

Host-authored publication uses `EventPayload.conversationMessageContent` carrying
`ConversationMessageContent`: Host-assigned message identity, conversation identity, owner/assistant
role, actual bounded text body, and `HostPosition`. The Host-authored envelope supplies Host identity
and position, and its optional causation may link the publication to a preceding submission.
`content.hostPosition` must equal the envelope Host position. This is a separate body-bearing
representation; `ConversationMessageReference` and `ContentAvailability` remain metadata-only.

Existing `CommandResult` statuses are reused without new runtime guarantees. Contract validates the
status shape and optional fields only; it does not verify that the Host recorded an intent, completed a
turn, refused a command, or retained a durable result. Applications decide when to emit each status,
and any idempotency, persistence, replay behavior, or outcome truthfulness is an application
responsibility.

### Response identity and position

Host-authored state responses carry Host identity and the committed position they reflect on the
envelope. The current rules are:

| Response variant | Host identity and position | Additional check |
|---|---|---|
| `QueryResult.projection` | Required | Envelope position and identity equal the snapshot's |
| `QueryResult.conversationPage` | Required | Envelope position equals `ConversationPage.hostPosition` |
| `QueryResult.contentAvailability` | Required | Envelope position is when the availability fact was reported |
| `SynchronizationResponse.snapshot` | Required | Envelope position and identity equal the snapshot's |
| `SynchronizationResponse.delta` | Required | Envelope position and identity equal `toPosition` and `hostIdentity` |
| `SynchronizationResponse.applied` | Required | Envelope position equals the acknowledged position |
| `SynchronizationResponse.unavailable` | Not required | Error response; it does not replace committed projection state |
| `CommandResult` | Conditional | May be positionless when no committed position applies. If `hostPosition` is present, the envelope must carry Host identity and position and they must agree |

Events require Host identity and position. An `approvalAvailable` event or delta change must carry an
`ApprovalNotice.hostPosition` equal to the containing position. Acknowledgement, error, and heartbeat
messages are not projection state and do not independently require Host state.

### Task and conversation synchronization

The contract provides Host positions, snapshots, deltas, projection kinds, task projections,
conversation projections and message references, paging cursors, and content availability metadata.
Projection events carry conversation and artifact references and metadata in typed fields; they do
not carry conversation message bodies or artifact bytes. The separate
`EventPayload.conversationMessageContent` event carries an actual bounded text body and does not
weaken the metadata-only semantics of references or availability. Artifact bytes remain outside the
contract.

Contract validates these consistency relationships: a snapshot's `projection` matches its
`ProjectionPayload` case; every delta change belongs to the delta's declared projection; a
conversations snapshot's nested `ConversationPage.hostPosition` equals the snapshot position;
envelope Host position agrees with nested snapshot, page, delta, and approval-notice positions; and
request/response conversation pages stay within `ContractLimits.maximumPageSize` items.

Contract does not validate or enforce delta ordering, contiguity, deduplication, gap buffering, stale
detection, or recovery. Position ordering, continuity decisions, buffering, and recovery behavior are
consumer responsibilities. In particular, Contract does not require `fromPosition < toPosition` or a
nonempty `changes` array; those remain application-level policy decisions.

### Errors and status

Errors use the approved classes: transport, authentication, authorization, stale/consistency,
validation, Host condition, and channel condition. Each error includes a code, plain-language
message, optional next step, and retry guidance. Host acceptance and completion remain distinct
statuses.

### Versioning and compatibility

Contract releases use SemVer. The supported grammar is the strict numeric triple
`major.minor.patch`; component values are unsigned integers without leading zeros. Prerelease and
build metadata such as `1.0.0-alpha` or `1.0.0+build.5` are **not** currently supported and are
rejected as malformed.

This release publishes Contract package `1.1.0`. Its current profile advertises package version
`1.1.0`, protocol version `1.0.0`, schema version `1.0.0`, and supported protocol range
`1.0.0...1.0.0`. `ProtocolRange.supports(_:)`, `ProtocolRange.intersection(with:)`,
and profile validation are package-local compatibility helpers over the versions peers declare. They
do not perform a wire-level version-negotiation handshake; applications decide how to exchange
declarations and select a mutually supported version. A breaking protocol change requires a Contract
major version. Unsupported versions are refused by validation rather than silently downgraded.

Schema compatibility is exact for the current profile: an incoming message whose schema version is
not exactly `1.0.0` is refused. A future schema change must therefore be treated as a coordinated
release. Because unknown fields are rejected, a newer peer that adds a field will be refused by an
older peer.

This release also adds the `submitConversationMessage` command, the optional `CommandRequest.payload`
field, and the `conversationMessageContent` event under that same schema version. Strict peers on
older Contract releases reject these cases and the new field. Applications must upgrade Contract
dependencies together before emitting or accepting the new wire surface; mixed-release tolerance is
not implemented.

### Serialization and the validated decoding boundary

`JSONContractCoder` is the supported boundary for messages received from another application.

On encode, it calls `ContractValidator.validate` before writing bytes, uses sorted keys,
`.withoutEscapingSlashes`, and ISO-8601 dates, then checks the encoded output against the 1 MiB
message-size limit. A message that exceeds the limit fails with `ContractValidationError.messageTooLarge`
after validation and encoding.

On decode, it checks the raw input byte count before parsing, configures the decoder with the ISO-8601
date strategy, and injects the per-decode `JSONValue` nesting budget. The contract types' custom
`init(from:)` implementations use strict key-set checks (`strictContainer`) and case-specific field
checks (`rejectFieldsOutsideCase`) to reject unknown or inapplicable fields; identifier and version
types add their own format checks. After decoding, `ContractValidator.validate` applies all semantic
rules.

The contract types are public `Codable`. Direct use of those conformances bypasses the validated
boundary: it does not apply the message-size checks, the injected `JSONValue` nesting budget, the
ISO-8601 decoder configuration, or `ContractValidator` semantics. Type-level strict decoding may still
run, so direct `Codable` use is not equivalent to unvalidated dictionary parsing, but a successful
direct decode is not Contract acceptance. Use `JSONContractCoder.decode` for every inbound message.
`ContractValidator.validate` may be called explicitly after constructing a message programmatically.

`JSONContractCoder.canonicalData(for:)` is package-local deterministic serialization. It calls the
same validated encode path and sorted-key encoder configuration for reproducible fixtures and future
content hashing. It is not standards-based canonical JSON, and deterministic bytes do not confer
authority or trust.

Duplicate JSON object keys are not rejected. The strict key-set checks inspect distinct key names, so
a repeated name collapses into one set element before validation; Foundation's decoder supplies one
value (last-value-wins). Rejecting duplicates safely would require a custom JSON parser, which is
outside this package's scope. Duplicate keys remain a hardening limitation, peers must emit
non-duplicated field names, and Contract does not treat a duplicate-key result as authority.

### JSON parameter limits

Command parameters and command-result metadata are bounded at the Contract boundary:

- at most 64 top-level parameters,
- at most 16 KiB of encoded parameter data,
- at most 32 nested arrays or objects per `JSONValue`, and
- no non-finite floating-point values.

These are intent limits, not semantic authorization. The Host must still validate command-specific
parameters, targets, consequences, and approvals.

### Contract validation summary

`ContractValidator` checks envelope/payload agreement, exact protocol and schema support, origin,
session/device binding presence, Host identity and position for Host-authored state, envelope/nested
position agreement, projection/payload and change/projection consistency, idempotency presence,
request and response page bounds, parameter bounds and nesting, conversation submission target and
typed-payload rules, Client Host-state exclusion, Host publication position agreement, and error
representations. Body non-emptiness and body byte/scalar bounds are enforced by
`ConversationMessageBody` at construction and decoding.

### Secure communication expectations

`SecureCommunicationExpectations` is a set of declared expectation constants, not an implemented
security system. It records the transport and session assumptions for integrators: TLS 1.3, encrypted
transport, authenticated session or device binding, Host identity and position for Host-authored
state, idempotency for commands, strict field rejection, the message-size limit, and no authority
carried in messages.

| Property | Contract behavior |
|---|---|
| TLS 1.3 and encryption | Declared expectation only; implemented by Host/User Application transport, not enforced by Contract |
| Authentication, pairing, enrollment | Declared expectation only; not implemented by Contract |
| Session/device binding | Contract requires a session or device identifier to be present; it does not authenticate it or establish freshness |
| Host identity and position | Presence and structural agreement are validated for Host-authored state as described above |
| Command idempotency | Presence required; reuse, expiry, and scope belong to the Host |
| Authorization and approval | Not implemented; commands are intent and the Host decides |
| Message-size and shape limits | Enforced by the validated encode/decode boundary |
| Unknown and case-invalid fields | Rejected by the custom strict decoders |
| Delivery receipt versus approval | Represented as distinct meanings; never treated as approval |

Networking, cryptography, pairing, enrollment, authentication, authorization, origin trust, and
transport sessions belong to the applications. Contract validates message structure and declared
semantics; it does not secure a connection, authenticate a peer, or replace Host authority.

## Build and test

```sh
swift build
swift test
```

The test suite covers JSON fixture round trips, strict unknown-field and case-specific field
rejection, origin and binding presence checks, error representation and identifier limits, missing
Host position and identity, missing idempotency, payload-kind mismatch, unsupported versions, inverted protocol-version
ranges, restricted SemVer grammar, compatibility helpers, Host-positioned snapshots and deltas,
nested position agreement, projection/payload and change/projection consistency, acknowledgement
meaning boundaries, conversation references without bodies, typed conversation submission and
Host-authored body-bearing content round trips, body byte/scalar limits, submission target and
payload validation, parameter smuggling and Client Host-state rejection, request and response page
bounds, inclusive parameter/nesting/message-size limits and their rejection just beyond those limits,
event and command-result round trips, encode-side size enforcement, the structural-versus-validated
decoding distinction, and the public message/status surface.

This coverage is a regression check, not a guarantee. These tests do not establish duplicate-key
rejection, standards-based canonical JSON, TLS or authentication enforcement, delta ordering or gap
handling, a wire-level negotiation handshake, or Host authority and durable decision records. Those
behaviors are explicitly outside Contract or belong to the applications.

## Non-goals

This package does not implement Host authority, persistence, execution, recovery, transport,
authentication, authorization, pairing, device enrollment, User Application presentation,
application-specific adapters, feature state, or any general-purpose shared utility. Types belong
here only when they are genuinely shared protocol contracts.
