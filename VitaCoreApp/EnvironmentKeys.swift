import SwiftUI
import VitaCoreContracts
import VitaCoreMock

// MARK: - GraphStore Environment Key

private struct GraphStoreKey: EnvironmentKey {
    static let defaultValue: GraphStoreProtocol = MockGraphStore()
}

extension EnvironmentValues {
    public var graphStore: GraphStoreProtocol {
        get { self[GraphStoreKey.self] }
        set { self[GraphStoreKey.self] = newValue }
    }
}

// MARK: - PersonaEngine Environment Key

private struct PersonaEngineKey: EnvironmentKey {
    static let defaultValue: PersonaEngineProtocol = MockPersonaEngine()
}

extension EnvironmentValues {
    public var personaEngine: PersonaEngineProtocol {
        get { self[PersonaEngineKey.self] }
        set { self[PersonaEngineKey.self] = newValue }
    }
}

// MARK: - InferenceProvider Environment Key

private struct InferenceProviderKey: EnvironmentKey {
    static let defaultValue: InferenceProviderProtocol = MockInferenceProvider()
}

extension EnvironmentValues {
    public var inferenceProvider: InferenceProviderProtocol {
        get { self[InferenceProviderKey.self] }
        set { self[InferenceProviderKey.self] = newValue }
    }
}

// MARK: - SkillBus Environment Key

private struct SkillBusKey: EnvironmentKey {
    static let defaultValue: SkillBusProtocol = MockSkillBus()
}

extension EnvironmentValues {
    public var skillBus: SkillBusProtocol {
        get { self[SkillBusKey.self] }
        set { self[SkillBusKey.self] = newValue }
    }
}

// MARK: - AlertRouter Environment Key

private struct AlertRouterKey: EnvironmentKey {
    static let defaultValue: AlertRouterProtocol = MockAlertRouter()
}

extension EnvironmentValues {
    public var alertRouter: AlertRouterProtocol {
        get { self[AlertRouterKey.self] }
        set { self[AlertRouterKey.self] = newValue }
    }
}
