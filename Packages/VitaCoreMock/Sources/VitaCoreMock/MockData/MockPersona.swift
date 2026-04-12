import Foundation
import VitaCoreContracts

/// Static persona data for the VitaCore demo user (Praba).
/// Used by MockPersonaEngine and Xcode Previews.
public enum MockPersona {

    // MARK: - User Identity

    public static let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let displayName = "Praba"
    public static let email = "praba@vitacore.demo"

    public static var dateOfBirth: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: 1990, month: 1, day: 15))!
    }

    public static let biologicalSex: BiologicalSex = .male
    public static let heightCm: Double = 175

    public static var userProfile: UserProfile {
        UserProfile(
            id: userId,
            displayName: displayName,
            email: email,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            heightCm: heightCm
        )
    }

    // MARK: - Conditions

    public static let conditions: [ConditionSummary] = [
        ConditionSummary(conditionKey: .type2Diabetes, severity: "moderate", daysActive: 365),
        ConditionSummary(conditionKey: .hypertension, severity: "mild", daysActive: 180)
    ]

    // MARK: - Goals

    public static let goals: [GoalSummary] = [
        GoalSummary(goalType: .stepsDaily, target: 10_000, current: 7_520, direction: 1),
        GoalSummary(goalType: .fluidDaily, target: 2_500, current: 1_200, direction: 1),
        GoalSummary(goalType: .timeInRange, target: 80, current: 84, direction: -1)
    ]

    // MARK: - Goal Progress

    public static let goalProgress: [GoalProgress] = [
        GoalProgress(
            goalType: .stepsDaily,
            target: 10_000,
            current: 7_520,
            trend: .improving,
            streakDays: 4
        ),
        GoalProgress(
            goalType: .fluidDaily,
            target: 2_500,
            current: 1_200,
            trend: .worsening,
            streakDays: 0
        ),
        GoalProgress(
            goalType: .timeInRange,
            target: 80,
            current: 84,
            trend: .improving,
            streakDays: 7
        )
    ]

    // MARK: - Medications

    public static let medications: [MedicationSummary] = [
        MedicationSummary(
            classKey: .metformin,
            name: "Metformin",
            dose: "500mg",
            frequency: "BID",
            interactionFlags: []
        ),
        MedicationSummary(
            classKey: .aceInhibitor,
            name: "Lisinopril",
            dose: "10mg",
            frequency: "QD",
            interactionFlags: []
        )
    ]

    // MARK: - Allergies

    public static let allergies: [AllergenSummary] = [
        AllergenSummary(
            allergen: "Peanut",
            severity: .severe,
            semanticMapRefs: ["groundnut", "satay", "peanut butter", "arachis oil"]
        )
    ]

    // MARK: - Preferences

    public static let preferences = PreferenceSummary(
        dietaryRestrictions: [],
        cuisinePreferences: ["Indian", "Mediterranean"],
        notificationQuietHoursStart: 22,
        notificationQuietHoursEnd: 7,
        preferMetricUnits: true,
        languageCode: "en"
    )

    // MARK: - Response Profiles

    public static let responseProfiles: [ResponseProfileSummary] = [
        ResponseProfileSummary(
            interventionType: "10min_walk",
            avgDelta: -18,
            sampleCount: 23,
            confidence: 0.87
        ),
        ResponseProfileSummary(
            interventionType: "500mL_water",
            avgDelta: -6,
            sampleCount: 15,
            confidence: 0.72
        ),
        ResponseProfileSummary(
            interventionType: "low_carb_meal",
            avgDelta: -22,
            sampleCount: 18,
            confidence: 0.81
        )
    ]

    // MARK: - Full PersonaContext

    public static var personaContext: PersonaContext {
        PersonaContext(
            userId: userId,
            activeConditions: conditions,
            activeGoals: goals,
            activeMedications: medications,
            allergies: allergies,
            preferences: preferences,
            responseProfiles: responseProfiles,
            thresholdOverrides: [],
            dataQualityFlags: [],
            goalProgress: goalProgress
        )
    }
}
