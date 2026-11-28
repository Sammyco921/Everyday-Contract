import Foundation

/// Host-owned derived views a Client may synchronize. The Client never sends these as truth.
public enum ProjectionKind: String, Codable, CaseIterable, Sendable {
    case tasks
    case conversations
    case approvals
    case hostStatus
    case channelStatus
}

/// Display-level status for a task projection. It is deliberately not the Host's internal execution
/// state machine; the Host owns and reports the authoritative meaning.
public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case active
    case waitingForInput
    case blocked
    case verifying
    case completed
    case failed
    case cancelled
    case uncertain
}

public enum VerificationState: String, Codable, CaseIterable, Sendable {
    case notStarted
    case pending
    case verified
    case failed
    case unavailable
}

public struct TaskProjection: Codable, Hashable, Sendable {
    public let objectiveID: ObjectiveID
    public let objectiveVersion: UInt64
    public let statement: ObjectiveStatement
    public let runID: RunID?
    public let planVersion: UInt64?
    public let status: TaskStatus
    public let currentWorkItemID: WorkItemID?
    public let completedWorkItemCount: UInt32
    public let remainingWorkItemCount: UInt32
    public let elapsedMilliseconds: UInt64
    public let blocker: String?
    public let verificationState: VerificationState

    public init(
        objectiveID: ObjectiveID,
        objectiveVersion: UInt64,
        statement: ObjectiveStatement,
        runID: RunID? = nil,
        planVersion: UInt64? = nil,
        status: TaskStatus,
        currentWorkItemID: WorkItemID? = nil,
        completedWorkItemCount: UInt32,
        remainingWorkItemCount: UInt32,
        elapsedMilliseconds: UInt64,
        blocker: String? = nil,
        verificationState: VerificationState
    ) {
        self.objectiveID = objectiveID
        self.objectiveVersion = objectiveVersion
        self.statement = statement
        self.runID = runID
        self.planVersion = planVersion
        self.status = status
        self.currentWorkItemID = currentWorkItemID
        self.completedWorkItemCount = completedWorkItemCount
        self.remainingWorkItemCount = remainingWorkItemCount
        self.elapsedMilliseconds = elapsedMilliseconds
        self.blocker = blocker
        self.verificationState = verificationState
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case objectiveID
        case objectiveVersion
        case statement
        case runID
        case planVersion
        case status
        case currentWorkItemID
        case completedWorkItemCount
        case remainingWorkItemCount
        case elapsedMilliseconds
        case blocker
        case verificationState
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "TaskProjection")
        self.init(
            objectiveID: try container.decode(ObjectiveID.self, forKey: .objectiveID),
            objectiveVersion: try container.decode(UInt64.self, forKey: .objectiveVersion),
            statement: try container.decode(ObjectiveStatement.self, forKey: .statement),
            runID: try container.decodeIfPresent(RunID.self, forKey: .runID),
            planVersion: try container.decodeIfPresent(UInt64.self, forKey: .planVersion),
            status: try container.decode(TaskStatus.self, forKey: .status),
            currentWorkItemID: try container.decodeIfPresent(WorkItemID.self, forKey: .currentWorkItemID),
            completedWorkItemCount: try container.decode(UInt32.self, forKey: .completedWorkItemCount),
            remainingWorkItemCount: try container.decode(UInt32.self, forKey: .remainingWorkItemCount),
            elapsedMilliseconds: try container.decode(UInt64.self, forKey: .elapsedMilliseconds),
            blocker: try container.decodeIfPresent(String.self, forKey: .blocker),
            verificationState: try container.decode(VerificationState.self, forKey: .verificationState)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objectiveID, forKey: .objectiveID)
        try container.encode(objectiveVersion, forKey: .objectiveVersion)
        try container.encode(statement, forKey: .statement)
        try container.encodeIfPresent(runID, forKey: .runID)
        try container.encodeIfPresent(planVersion, forKey: .planVersion)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(currentWorkItemID, forKey: .currentWorkItemID)
        try container.encode(completedWorkItemCount, forKey: .completedWorkItemCount)
        try container.encode(remainingWorkItemCount, forKey: .remainingWorkItemCount)
        try container.encode(elapsedMilliseconds, forKey: .elapsedMilliseconds)
        try container.encodeIfPresent(blocker, forKey: .blocker)
        try container.encode(verificationState, forKey: .verificationState)
    }
}

public enum CommunicationChannel: String, Codable, CaseIterable, Sendable {
    case client
    case host
    case messages
    case email
    case phone
}

/// Metadata for a Host message. Conversation bodies, attachment bytes, and artifacts are not carried.
public struct ConversationMessageReference: Codable, Hashable, Sendable {
    public let messageID: ConversationMessageID
    public let conversationID: ConversationID
    public let channel: CommunicationChannel
    public let senderHandle: String?
    public let receivedAt: Date
    public let contentReferenceID: ContentReferenceID
    public let externalReference: String?

    public init(
        messageID: ConversationMessageID,
        conversationID: ConversationID,
        channel: CommunicationChannel,
        senderHandle: String? = nil,
        receivedAt: Date,
        contentReferenceID: ContentReferenceID,
        externalReference: String? = nil
    ) {
        self.messageID = messageID
        self.conversationID = conversationID
        self.channel = channel
        self.senderHandle = senderHandle
        self.receivedAt = receivedAt
        self.contentReferenceID = contentReferenceID
        self.externalReference = externalReference
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case messageID
        case conversationID
        case channel
        case senderHandle
        case receivedAt
        case contentReferenceID
        case externalReference
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ConversationMessageReference")
        self.init(
            messageID: try container.decode(ConversationMessageID.self, forKey: .messageID),
            conversationID: try container.decode(ConversationID.self, forKey: .conversationID),
            channel: try container.decode(CommunicationChannel.self, forKey: .channel),
            senderHandle: try container.decodeIfPresent(String.self, forKey: .senderHandle),
            receivedAt: try container.decode(Date.self, forKey: .receivedAt),
            contentReferenceID: try container.decode(ContentReferenceID.self, forKey: .contentReferenceID),
            externalReference: try container.decodeIfPresent(String.self, forKey: .externalReference)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageID, forKey: .messageID)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(channel, forKey: .channel)
        try container.encodeIfPresent(senderHandle, forKey: .senderHandle)
        try container.encode(receivedAt, forKey: .receivedAt)
        try container.encode(contentReferenceID, forKey: .contentReferenceID)
        try container.encodeIfPresent(externalReference, forKey: .externalReference)
    }
}

/// Role of a Host-authored conversation message. The owner and assistant roles describe
/// authorship for display and carry no authority.
public enum ConversationMessageRole: String, Codable, CaseIterable, Sendable {
    case owner
    case assistant
}

/// Host-authored publication of actual text content in one conversation message.
///
/// This is a separate body-bearing representation. It does not repurpose `ConversationMessageReference`
/// or `ContentAvailability`, and it carries no attachment, image, file, or artifact payload. The
/// envelope supplies Host identity, correlation, and causation; `hostPosition` must agree with the
/// envelope position.
public struct ConversationMessageContent: Codable, Hashable, Sendable {
    public let messageID: ConversationMessageID
    public let conversationID: ConversationID
    public let role: ConversationMessageRole
    public let body: ConversationMessageBody
    public let hostPosition: HostPosition

    public init(
        messageID: ConversationMessageID,
        conversationID: ConversationID,
        role: ConversationMessageRole,
        body: ConversationMessageBody,
        hostPosition: HostPosition
    ) {
        self.messageID = messageID
        self.conversationID = conversationID
        self.role = role
        self.body = body
        self.hostPosition = hostPosition
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case messageID
        case conversationID
        case role
        case body
        case hostPosition
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            CodingKeys.self,
            from: decoder,
            type: "ConversationMessageContent"
        )
        self.init(
            messageID: try container.decode(ConversationMessageID.self, forKey: .messageID),
            conversationID: try container.decode(ConversationID.self, forKey: .conversationID),
            role: try container.decode(ConversationMessageRole.self, forKey: .role),
            body: try container.decode(ConversationMessageBody.self, forKey: .body),
            hostPosition: try container.decode(HostPosition.self, forKey: .hostPosition)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageID, forKey: .messageID)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(role, forKey: .role)
        try container.encode(body, forKey: .body)
        try container.encode(hostPosition, forKey: .hostPosition)
    }
}

public struct ConversationProjection: Codable, Hashable, Sendable {
    public let conversationID: ConversationID
    public let associatedObjectiveID: ObjectiveID?
    public let lastMessageID: ConversationMessageID?
    public let messageCount: UInt64
    public let isStale: Bool

    public init(
        conversationID: ConversationID,
        associatedObjectiveID: ObjectiveID? = nil,
        lastMessageID: ConversationMessageID? = nil,
        messageCount: UInt64,
        isStale: Bool
    ) {
        self.conversationID = conversationID
        self.associatedObjectiveID = associatedObjectiveID
        self.lastMessageID = lastMessageID
        self.messageCount = messageCount
        self.isStale = isStale
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case conversationID
        case associatedObjectiveID
        case lastMessageID
        case messageCount
        case isStale
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ConversationProjection")
        self.init(
            conversationID: try container.decode(ConversationID.self, forKey: .conversationID),
            associatedObjectiveID: try container.decodeIfPresent(ObjectiveID.self, forKey: .associatedObjectiveID),
            lastMessageID: try container.decodeIfPresent(ConversationMessageID.self, forKey: .lastMessageID),
            messageCount: try container.decode(UInt64.self, forKey: .messageCount),
            isStale: try container.decode(Bool.self, forKey: .isStale)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encodeIfPresent(associatedObjectiveID, forKey: .associatedObjectiveID)
        try container.encodeIfPresent(lastMessageID, forKey: .lastMessageID)
        try container.encode(messageCount, forKey: .messageCount)
        try container.encode(isStale, forKey: .isStale)
    }
}

public struct ConversationPage: Codable, Hashable, Sendable {
    public let conversationID: ConversationID
    public let hostPosition: HostPosition
    public let items: [ConversationMessageReference]
    public let nextCursor: ConversationMessageID?

    public init(
        conversationID: ConversationID,
        hostPosition: HostPosition,
        items: [ConversationMessageReference],
        nextCursor: ConversationMessageID? = nil
    ) {
        self.conversationID = conversationID
        self.hostPosition = hostPosition
        self.items = items
        self.nextCursor = nextCursor
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case conversationID
        case hostPosition
        case items
        case nextCursor
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ConversationPage")
        self.init(
            conversationID: try container.decode(ConversationID.self, forKey: .conversationID),
            hostPosition: try container.decode(HostPosition.self, forKey: .hostPosition),
            items: try container.decode([ConversationMessageReference].self, forKey: .items),
            nextCursor: try container.decodeIfPresent(ConversationMessageID.self, forKey: .nextCursor)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(hostPosition, forKey: .hostPosition)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
    }
}

public enum ContentAvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available
    case missing
    case hashMismatch
    case unavailable
}

public struct ContentIntegrity: Codable, Hashable, Sendable {
    public let sha256Hex: String
    public let byteCount: UInt64
    public let version: UInt64

    public init(sha256Hex: String, byteCount: UInt64, version: UInt64) {
        self.sha256Hex = sha256Hex
        self.byteCount = byteCount
        self.version = version
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case sha256Hex
        case byteCount
        case version
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ContentIntegrity")
        self.init(
            sha256Hex: try container.decode(String.self, forKey: .sha256Hex),
            byteCount: try container.decode(UInt64.self, forKey: .byteCount),
            version: try container.decode(UInt64.self, forKey: .version)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sha256Hex, forKey: .sha256Hex)
        try container.encode(byteCount, forKey: .byteCount)
        try container.encode(version, forKey: .version)
    }
}

public struct ContentAvailability: Codable, Hashable, Sendable {
    public let contentReferenceID: ContentReferenceID
    public let status: ContentAvailabilityStatus
    public let integrity: ContentIntegrity?

    public init(
        contentReferenceID: ContentReferenceID,
        status: ContentAvailabilityStatus,
        integrity: ContentIntegrity? = nil
    ) {
        self.contentReferenceID = contentReferenceID
        self.status = status
        self.integrity = integrity
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case contentReferenceID
        case status
        case integrity
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ContentAvailability")
        self.init(
            contentReferenceID: try container.decode(ContentReferenceID.self, forKey: .contentReferenceID),
            status: try container.decode(ContentAvailabilityStatus.self, forKey: .status),
            integrity: try container.decodeIfPresent(ContentIntegrity.self, forKey: .integrity)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentReferenceID, forKey: .contentReferenceID)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(integrity, forKey: .integrity)
    }
}

public enum ProjectionPayload: Codable, Hashable, Sendable {
    case tasks([TaskProjection])
    case conversations(ConversationPage)
    case approvals([ApprovalNotice])
    case hostStatus(HostCondition)
    case channelStatus([ChannelCondition])

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case tasks
        case conversations
        case approvals
        case hostStatus
        case channelStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ProjectionPayload")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .tasks: self = .tasks(try container.decode([TaskProjection].self, forKey: .value))
        case .conversations: self = .conversations(try container.decode(ConversationPage.self, forKey: .value))
        case .approvals: self = .approvals(try container.decode([ApprovalNotice].self, forKey: .value))
        case .hostStatus: self = .hostStatus(try container.decode(HostCondition.self, forKey: .value))
        case .channelStatus: self = .channelStatus(try container.decode([ChannelCondition].self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .tasks(value):
            try container.encode(Kind.tasks, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .conversations(value):
            try container.encode(Kind.conversations, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .approvals(value):
            try container.encode(Kind.approvals, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .hostStatus(value):
            try container.encode(Kind.hostStatus, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .channelStatus(value):
            try container.encode(Kind.channelStatus, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

/// A complete Host projection at a committed position.
///
/// `payload` must belong to `projection`. For conversations, the nested `ConversationPage.hostPosition`
/// must equal the snapshot position.
public struct ProjectionSnapshot: Codable, Hashable, Sendable {
    public let projection: ProjectionKind
    public let hostPosition: HostPosition
    public let hostIdentity: HostIdentity
    public let payload: ProjectionPayload

    public init(
        projection: ProjectionKind,
        hostPosition: HostPosition,
        hostIdentity: HostIdentity,
        payload: ProjectionPayload
    ) {
        self.projection = projection
        self.hostPosition = hostPosition
        self.hostIdentity = hostIdentity
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case projection
        case hostPosition
        case hostIdentity
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ProjectionSnapshot")
        self.init(
            projection: try container.decode(ProjectionKind.self, forKey: .projection),
            hostPosition: try container.decode(HostPosition.self, forKey: .hostPosition),
            hostIdentity: try container.decode(HostIdentity.self, forKey: .hostIdentity),
            payload: try container.decode(ProjectionPayload.self, forKey: .payload)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projection, forKey: .projection)
        try container.encode(hostPosition, forKey: .hostPosition)
        try container.encode(hostIdentity, forKey: .hostIdentity)
        try container.encode(payload, forKey: .payload)
    }
}

public enum ProjectionChange: Codable, Hashable, Sendable {
    case taskUpserted(TaskProjection)
    case taskRemoved(ObjectiveID)
    case conversationMessageAppended(ConversationMessageReference)
    case conversationUpdated(ConversationProjection)
    case approvalAvailable(ApprovalNotice)
    case hostConditionChanged(HostCondition)
    case channelConditionChanged(ChannelCondition)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case taskUpserted
        case taskRemoved
        case conversationMessageAppended
        case conversationUpdated
        case approvalAvailable
        case hostConditionChanged
        case channelConditionChanged
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ProjectionChange")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .taskUpserted: self = .taskUpserted(try container.decode(TaskProjection.self, forKey: .value))
        case .taskRemoved: self = .taskRemoved(try container.decode(ObjectiveID.self, forKey: .value))
        case .conversationMessageAppended:
            self = .conversationMessageAppended(try container.decode(ConversationMessageReference.self, forKey: .value))
        case .conversationUpdated:
            self = .conversationUpdated(try container.decode(ConversationProjection.self, forKey: .value))
        case .approvalAvailable: self = .approvalAvailable(try container.decode(ApprovalNotice.self, forKey: .value))
        case .hostConditionChanged: self = .hostConditionChanged(try container.decode(HostCondition.self, forKey: .value))
        case .channelConditionChanged:
            self = .channelConditionChanged(try container.decode(ChannelCondition.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .taskUpserted(value):
            try container.encode(Kind.taskUpserted, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .taskRemoved(value):
            try container.encode(Kind.taskRemoved, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .conversationMessageAppended(value):
            try container.encode(Kind.conversationMessageAppended, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .conversationUpdated(value):
            try container.encode(Kind.conversationUpdated, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .approvalAvailable(value):
            try container.encode(Kind.approvalAvailable, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .hostConditionChanged(value):
            try container.encode(Kind.hostConditionChanged, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .channelConditionChanged(value):
            try container.encode(Kind.channelConditionChanged, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

/// An ordered set of changes from one Host position to another.
///
/// Every change must belong to `projection`. An embedded `ApprovalNotice.hostPosition` must equal
/// `toPosition`.
public struct ProjectionDelta: Codable, Hashable, Sendable {
    public let projection: ProjectionKind
    public let fromPosition: HostPosition
    public let toPosition: HostPosition
    public let hostIdentity: HostIdentity
    public let changes: [ProjectionChange]

    public init(
        projection: ProjectionKind,
        fromPosition: HostPosition,
        toPosition: HostPosition,
        hostIdentity: HostIdentity,
        changes: [ProjectionChange]
    ) {
        self.projection = projection
        self.fromPosition = fromPosition
        self.toPosition = toPosition
        self.hostIdentity = hostIdentity
        self.changes = changes
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case projection
        case fromPosition
        case toPosition
        case hostIdentity
        case changes
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ProjectionDelta")
        self.init(
            projection: try container.decode(ProjectionKind.self, forKey: .projection),
            fromPosition: try container.decode(HostPosition.self, forKey: .fromPosition),
            toPosition: try container.decode(HostPosition.self, forKey: .toPosition),
            hostIdentity: try container.decode(HostIdentity.self, forKey: .hostIdentity),
            changes: try container.decode([ProjectionChange].self, forKey: .changes)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projection, forKey: .projection)
        try container.encode(fromPosition, forKey: .fromPosition)
        try container.encode(toPosition, forKey: .toPosition)
        try container.encode(hostIdentity, forKey: .hostIdentity)
        try container.encode(changes, forKey: .changes)
    }
}
