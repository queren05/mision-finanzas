import SwiftUI

struct SettingsView: View {
    @AppStorage("tema") private var theme = Theme.auto
    @AppStorage("energia") private var energy = EnergyUnit.kcal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var asked = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    LabeledContent("Fuente", value: HealthKitSource.shared.name)
                    Button {
                        Task {
                            try? await HealthKitSource.shared.requestAuthorization()
                            asked += 1
                        }
                    } label: {
                        Label("Revisar permisos", systemImage: "checkmark.shield")
                    }
                    Button {
                        if let url = URL(string: "x-apple-health://") { openURL(url) }
                    } label: {
                        Label("Abrir Salud", systemImage: "heart.text.square")
                    }
                }
                Section("Unidades") {
                    Picker("Energía", selection: $energy) {
                        Text("Kilocalorías").tag(EnergyUnit.kcal)
                        Text("Kilojulios").tag(EnergyUnit.kJ)
                    }
                }
                Section("Aspecto") {
                    Picker("Tema", selection: $theme) {
                        ForEach(Theme.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: asked)
        }
    }
}

#Preview {
    SettingsView().fontDesign(.rounded).preferredColorScheme(.dark)
}
