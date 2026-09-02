import SwiftUI

struct ProcessingView: View {
    @State private var jobs: [ProcessingJob] = []
    @State private var mode: JobScheduler.ConcurrencyMode = .automatic
    @State private var scheduler = JobScheduler()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Traitement").font(.largeTitle.bold())
                    Text(jobs.isEmpty ? "Aucun fichier dans la file." : "\(jobs.count) tâche\(jobs.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Concurrence", selection: $mode) {
                    Text("Auto").tag(JobScheduler.ConcurrencyMode.automatic)
                    Text("Économie").tag(JobScheduler.ConcurrencyMode.economy)
                    ForEach(1...20, id: \.self) { value in Text("\(value)").tag(JobScheduler.ConcurrencyMode.manual(value)) }
                }
                .pickerStyle(.menu)
                Button("Effacer terminés") {
                    Task { await scheduler.clearFinished(); await refresh() }
                }
            }

            if jobs.isEmpty {
                ContentUnavailableView {
                    Label("Aucun traitement en cours", systemImage: "gearshape.2")
                } description: {
                    Text("Les traitements par lot apparaîtront ici avec leur progression et leur étape exacte.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(jobs) { job in
                    JobRow(job: job)
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await scheduler.setConcurrencyMode(mode)
            await refresh()
        }
        .onChange(of: mode) { _, newMode in
            Task { await scheduler.setConcurrencyMode(newMode); await refresh() }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        jobs = await scheduler.snapshot()
    }
}

private struct JobRow: View {
    let job: ProcessingJob

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(job.fileURL.lastPathComponent).lineLimit(1)
                HStack(spacing: 8) {
                    Text(stateLabel).font(.caption).foregroundStyle(.secondary)
                    if let currentOperation = job.currentOperation {
                        Text("•").foregroundStyle(.tertiary)
                        Text(currentOperation).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if job.state == .planning || job.state == .processing || job.state == .validating {
                    ProgressView(value: job.progress).frame(maxWidth: 260)
                }
                if let error = job.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            Text("\(Int(job.progress * 100)) %").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private var stateLabel: String {
        switch job.state {
        case .waiting: "En attente"
        case .analyzing: "Analyse"
        case .planning: "Préparation"
        case .processing: "Traitement"
        case .validating: "Vérification"
        case .completed: "Terminé"
        case .failed: "Échec"
        case .skipped: "Ignoré"
        case .cancelled: "Annulé"
        case .warning: "Terminé avec avertissement"
        }
    }

    private var icon: String {
        switch job.state {
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .cancelled: "stop.circle"
        case .processing, .analyzing, .planning, .validating: "arrow.triangle.2.circlepath"
        default: "clock"
        }
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
