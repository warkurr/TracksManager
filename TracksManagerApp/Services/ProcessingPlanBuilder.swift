import Foundation

struct ProcessingPlanBuilder: Sendable {
    func makeAnalysisPlan(for file: MediaFile) -> ProcessingPlan {
        ProcessingPlan(
            fileURL: file.url,
            operations: [
                ProcessingOperation(
                    kind: .analyze,
                    title: "Analyser le MKV",
                    detail: "Inventorier les pistes et les métadonnées du conteneur."
                )
            ]
        )
    }

    func makeValidationPlan(for file: MediaFile) -> ProcessingPlan {
        ProcessingPlan(
            fileURL: file.url,
            operations: [
                ProcessingOperation(
                    kind: .validate,
                    title: "Valider le MKV",
                    detail: "Ré-analyser le conteneur et vérifier que sa structure reste lisible après traitement."
                )
            ],
            requiresBackup: false
        )
    }
}
