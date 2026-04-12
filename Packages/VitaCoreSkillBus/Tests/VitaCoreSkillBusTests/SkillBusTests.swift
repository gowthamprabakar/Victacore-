// SkillBusTests.swift
// VitaCoreSkillBus — Sprint 2.A tests.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
@testable import VitaCoreSkillBus

// MARK: - Manual Entry Tests

@Test("logGlucose writes Reading + Episode to GraphStore")
func testLogGlucose() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let result = await bus.logGlucose(value: 142, timestamp: Date())
    #expect(result.success)

    let latest = try await graph.getLatestReading(for: .glucose)
    #expect(latest != nil)
    #expect(latest?.value == 142)
    #expect(latest?.sourceSkillId == "skill.manual.glucose")

    let episodes = try await graph.getEpisodes(
        from: Date().addingTimeInterval(-60),
        to: Date().addingTimeInterval(60),
        types: [.manualGlucose]
    )
    #expect(episodes.count == 1)
}

@Test("logBloodPressure writes systolic + diastolic readings")
func testLogBP() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let result = await bus.logBloodPressure(systolic: 124, diastolic: 82, timestamp: Date())
    #expect(result.success)

    let sys = try await graph.getLatestReading(for: .bloodPressureSystolic)
    let dia = try await graph.getLatestReading(for: .bloodPressureDiastolic)
    #expect(sys?.value == 124)
    #expect(dia?.value == 82)
}

@Test("logFluidIntake writes to fluidIntake metric")
func testLogFluid() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let result = await bus.logFluidIntake(volumeML: 350, timestamp: Date())
    #expect(result.success)

    let latest = try await graph.getLatestReading(for: .fluidIntake)
    #expect(latest?.value == 350)
}

@Test("logFoodEntry writes calories + carbs + protein + fat readings")
func testLogFood() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let food = FoodAnalysisResult(
        recognisedItems: [
            FoodEntry(name: "Rice", portionGrams: 200, calories: 260, carbsG: 58,
                      proteinG: 5.4, fatG: 0.6, sourceSkillId: "skill.manual.food", timestamp: Date())
        ],
        totalCalories: 260, totalCarbsG: 58, totalProteinG: 5.4, totalFatG: 0.6,
        confidence: 0.9, analysedAt: Date()
    )
    let result = await bus.logFoodEntry(result: food, timestamp: Date())
    #expect(result.success)

    let cal = try await graph.getLatestReading(for: .calories)
    let carbs = try await graph.getLatestReading(for: .carbs)
    #expect(cal?.value == 260)
    #expect(carbs?.value == 58)
}

@Test("logWeight writes to weight metric")
func testLogWeight() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let result = await bus.logWeight(valueKg: 72.5, timestamp: Date())
    #expect(result.success)

    let latest = try await graph.getLatestReading(for: .weight)
    #expect(latest?.value == 72.5)
}

@Test("logSymptomNote writes episode with text payload")
func testLogNote() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let result = await bus.logSymptomNote(text: "Feeling dizzy after lunch", timestamp: Date())
    #expect(result.success)

    let episodes = try await graph.getEpisodes(
        from: Date().addingTimeInterval(-60),
        to: Date().addingTimeInterval(60),
        types: [.symptomNote]
    )
    #expect(episodes.count == 1)
    let payload = try? JSONSerialization.jsonObject(with: episodes[0].payload) as? [String: Any]
    #expect(payload?["text"] as? String == "Feeling dizzy after lunch")
}

// MARK: - Skill Management

@Test("getRegisteredSkills returns 6 manual skills")
func testRegisteredSkills() async {
    let graph = try! GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let skills = await bus.getRegisteredSkills()
    #expect(skills.count == 6)
    #expect(skills.allSatisfy { $0.status == .connected })
}

@Test("registerSkill adds external device skill")
func testRegisterExternalSkill() async {
    let graph = try! GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    bus.registerSkill(SkillDescriptor(
        id: "skill.healthKit",
        displayName: "Apple Health",
        iconName: "heart.fill",
        status: .connected,
        supportedMetrics: [.heartRate, .steps, .sleep]
    ))

    let skills = await bus.getRegisteredSkills()
    #expect(skills.count == 7)
    #expect(skills.contains { $0.id == "skill.healthKit" })
}

// MARK: - End-to-end: log → query

@Test("Multiple logs produce correct range query results")
func testMultipleLogsRangeQuery() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    let base = Date()
    _ = await bus.logGlucose(value: 120, timestamp: base.addingTimeInterval(-3600))
    _ = await bus.logGlucose(value: 145, timestamp: base.addingTimeInterval(-1800))
    _ = await bus.logGlucose(value: 130, timestamp: base)

    let range = try await graph.getRangeReadings(
        for: .glucose,
        from: base.addingTimeInterval(-7200),
        to: base.addingTimeInterval(60)
    )
    #expect(range.count == 3)

    let agg = try await graph.getAggregatedMetric(
        for: .glucose,
        from: base.addingTimeInterval(-7200),
        to: base.addingTimeInterval(60)
    )
    #expect(agg != nil)
    // Average of 120, 145, 130 = 131.67
    #expect(abs((agg?.average ?? 0) - 131.67) < 1.0)
}
