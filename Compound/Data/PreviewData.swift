import Foundation
import SwiftData

/// In-memory container for SwiftUI previews, pre-seeded with the starter data.
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: AppSchema.model,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            SeedData.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to build preview container: \(error)")
        }
    }()
}
