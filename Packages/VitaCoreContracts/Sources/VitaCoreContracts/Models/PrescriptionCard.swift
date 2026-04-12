import Foundation

// MARK: - Prescription

/// A single ranked action recommendation.
/// This is a frozen interface contract — changes require a version bump.
public struct Prescription: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    /// Lower rank = higher priority (1 = top recommendation).
    public let rank: Int
    /// Imperative verb describing the action (e.g., "Drink", "Walk", "Reduce").
    public let actionVerb: String
    /// Specific detail elaborating on the verb (e.g., "250 mL of water").
    public let actionDetail: String
    /// Scalar quantity associated with the action.
    public let actionQuantity: Double
    /// Unit for the quantity (e.g., "mL", "min", "g").
    public let actionUnit: String
    /// Headline benefit communicated to the user.
    public let primaryBenefit: String
    /// How long the user has to act (e.g., "next 30 minutes").
    public let timeWindow: String
    /// Absolute deadline for the action (nil if open-ended).
    public let closingTime: Date?
    /// Composite trajectory score [0, 1] — higher means stronger projected improvement.
    public let trajectoryScore: Float
    /// Projected delta vs. the baseline outcome.
    public let baselineDelta: Double
    /// Reasons this prescription should not be applied for this user.
    public let contraindications: [String]

    public init(
        id: UUID = UUID(),
        rank: Int,
        actionVerb: String,
        actionDetail: String,
        actionQuantity: Double,
        actionUnit: String,
        primaryBenefit: String,
        timeWindow: String,
        closingTime: Date? = nil,
        trajectoryScore: Float,
        baselineDelta: Double,
        contraindications: [String] = []
    ) {
        self.id = id
        self.rank = rank
        self.actionVerb = actionVerb
        self.actionDetail = actionDetail
        self.actionQuantity = actionQuantity
        self.actionUnit = actionUnit
        self.primaryBenefit = primaryBenefit
        self.timeWindow = timeWindow
        self.closingTime = closingTime
        self.trajectoryScore = trajectoryScore
        self.baselineDelta = baselineDelta
        self.contraindications = contraindications
    }
}

// MARK: - PrescriptionCard

/// The top-level inference output surfaced to the UI layer.
/// This is a frozen interface contract — changes require a version bump.
public struct PrescriptionCard: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    /// Ordered list of action recommendations (sorted by rank ascending).
    public let prescriptions: [Prescription]
    /// Projected metric trajectory if the user takes no action.
    public let baselineOutcome: String
    /// Aggregate confidence in this card [0, 1].
    public let overallConfidence: Float
    /// Proportion of required data that was available [0, 1].
    public let dataCoverage: Float
    /// The inference request this card was derived from.
    public let sourceRequestId: UUID
    /// Wall-clock time the card was generated.
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        prescriptions: [Prescription],
        baselineOutcome: String,
        overallConfidence: Float,
        dataCoverage: Float,
        sourceRequestId: UUID,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.prescriptions = prescriptions
        self.baselineOutcome = baselineOutcome
        self.overallConfidence = overallConfidence
        self.dataCoverage = dataCoverage
        self.sourceRequestId = sourceRequestId
        self.generatedAt = generatedAt
    }

    /// Returns the highest-priority (rank == 1) prescription, if any.
    public var topPrescription: Prescription? {
        prescriptions.min(by: { $0.rank < $1.rank })
    }
}
