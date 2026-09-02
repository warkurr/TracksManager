import SwiftUI

struct ProcessingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Traitement")
                .font(.largeTitle.bold())

            ContentUnavailableView {
                Label("Aucun traitement en cours", systemImage: "gearshape.2")
            } description: {
                Text("Les traitements par lot apparaîtront ici avec leur progression et leur étape exacte.")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text("Cette section sera ajoutée dans les prochaines étapes du prototype.")
        }
    }
}
