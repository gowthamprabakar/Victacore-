import Foundation
import VitaCoreContracts

/// Central provider holding all mock instances.
/// Inject via SwiftUI environment for development and Xcode Previews.
public final class MockDataProvider: @unchecked Sendable {

    public static let shared = MockDataProvider()

    public let graphStore: GraphStoreProtocol
    public let personaEngine: PersonaEngineProtocol
    public let inferenceProvider: InferenceProviderProtocol
    public let skillBus: SkillBusProtocol
    public let alertRouter: AlertRouterProtocol

    public init() {
        self.graphStore = MockGraphStore()
        self.personaEngine = MockPersonaEngine()
        self.inferenceProvider = MockInferenceProvider()
        self.skillBus = MockSkillBus()
        self.alertRouter = MockAlertRouter()
    }
}
