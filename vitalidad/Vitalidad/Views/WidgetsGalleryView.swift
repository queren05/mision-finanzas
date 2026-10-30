import SwiftUI

/// Cómo se ven los widgets con tus datos de ahora y si el resumen llega al servidor de casa.
struct WidgetsGalleryView: View {
    @Environment(HealthStore.self) private var store

    var body: some View {
        let d = store.widgetData()
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if !Launch.demo { status }
                title("Tu día")
                HStack(spacing: Space.l) {
                    box(d, small: true) { VWDaySmall(d: d) }
                    box(d, small: true) { VWAdviceSmall(d: d) }
                }
                box(d) { VWDayMedium(d: d) }
                title("Pasos y datos")
                HStack(spacing: Space.l) {
                    box(d, small: true) { VWStepsSmall(d: d) }
                    box(d, small: true) { VWDataSmall(d: d) }
                }
                box(d) { VWDataMedium(d: d) }
                title("Grande")
                box(d, height: 354) { VWDayLarge(d: d) }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var status: some View {
        HStack(spacing: Space.m) {
            Image(systemName: store.widgetFailed ? "xmark.icloud.fill" : store.widgetSent != nil ? "checkmark.icloud.fill" : "icloud.fill")
                .font(.title2)
                .foregroundStyle(store.widgetFailed ? Palette.attention : store.widgetSent != nil ? Palette.good : .secondary)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text("Servidor de casa").font(.subheadline.weight(.semibold))
                Text(store.widgetFailed ? "No llega · ¿Tailscale encendido?" : store.widgetSent.map { "Enviado a las \(Fmt.clock($0))" } ?? "Sin enviar todavía")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Enviar") { Task { await store.pushWidget() } }.secondaryButton()
        }
        .card(padding: Space.l)
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.headline).padding(.top, Space.xs)
    }

    private func box<C: View>(_ d: WidgetData, small: Bool = false, height: CGFloat = 158, @ViewBuilder _ c: () -> C) -> some View {
        c()
            .foregroundStyle(.white)
            .fontDesign(.rounded)
            .padding(16)
            .frame(width: small ? 158 : nil, height: small ? 158 : height)
            .frame(maxWidth: small ? nil : .infinity)
            .background(WBackground(mood: d.mood), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}
