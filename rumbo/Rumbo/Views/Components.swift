import SwiftUI

/// botón que pide algo a Claude: brillo de color, chispa animada y «pensando…» mientras trabaja
struct AIButton: View {
    @Environment(Store.self) private var store
    var title: String
    var key: String
    var icon: String = "sparkles"
    var action: () async -> Void
    @State private var spin = false

    var body: some View {
        let busy = store.busy.contains(key)
        Button {
            guard !busy else { return }
            Haptic.tap()
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: busy ? "sparkle" : icon)
                    .symbolEffect(.variableColor.iterative, isActive: busy)
                    .rotationEffect(.degrees(busy && spin ? 360 : 0))
                Text(busy ? "Pensando…" : title).contentTransition(.opacity)
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(
                LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7), Color(hex: "#ff9ecf")], startPoint: .leading, endPoint: .trailing),
                in: Capsule())
            .shadow(color: Color.accentColor.opacity(busy ? 0.6 : 0.3), radius: busy ? 14 : 8, y: 3)
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: busy)
        .onChange(of: busy) { _, b in
            if b { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { spin = true } } else { spin = false }
        }
    }
}

/// lista con viñetas de colores
struct Bullets: View {
    var items: [String]
    var color: Color = .accentColor
    var icon: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, t in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let icon { Image(systemName: icon).foregroundStyle(color).font(.subheadline.weight(.bold)) }
                    else { Circle().fill(color).frame(width: 7, height: 7).offset(y: -2) }
                    Text(t).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .appear(Double(i) * 0.05)
            }
        }
    }
}

/// cabecera de tarjeta con icono
struct CardTitle: View {
    var title: String
    var icon: String
    var color: Color = .accentColor
    var subtitle: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
                .frame(width: 34, height: 34).background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }
    }
}

/// «pregúntale lo que quieras»: campo de pregunta y las respuestas con sus fuentes
struct AskBox: View {
    @Environment(Store.self) private var store
    var placeholder: String
    var suggestions: [String]
    var busyKey: String
    var answers: [QA]
    var ask: (String) async -> Void
    @State private var q = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                TextField(placeholder, text: $q, axis: .vertical).focused($focused).lineLimit(1...4).submitLabel(.send)
                    .onSubmit(send)
                if store.busy.contains(busyKey) { ProgressView() }
                else if !q.isEmpty {
                    Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }.transition(.scale)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.spring, value: q.isEmpty)
            if answers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { s in
                            Button { q = s; send() } label: {
                                Text(s).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
            ForEach(answers.prefix(5)) { a in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "person.fill").font(.caption).foregroundStyle(.secondary).frame(width: 18)
                        Text(a.question).font(.subheadline.weight(.semibold))
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle").font(.caption).foregroundStyle(Color.accentColor).frame(width: 18)
                        Text(a.answer).font(.subheadline).textSelection(.enabled)
                    }
                    if !a.sources.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(a.sources, id: \.self) { s in
                                    Label(s, systemImage: "doc.text").font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color.white.opacity(0.08), in: Capsule())
                                }
                            }
                        }
                        .padding(.leading, 26)
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.asymmetric(insertion: .push(from: .top).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private func send() {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !store.busy.contains(busyKey) else { return }
        focused = false; q = ""
        Task { await ask(t) }
    }
}

/// vacío bonito
struct EmptyCard: View {
    var icon: String
    var title: String
    var text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(Color.accentColor)
            Text(title).font(.headline)
            if !text.isEmpty { Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// aparece desde abajo con un pequeño retraso
struct Appear: ViewModifier {
    var delay: Double
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0).offset(y: on ? 0 : 20)
            .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(delay)) { on = true } }
    }
}
extension View {
    func appear(_ delay: Double = 0) -> some View { modifier(Appear(delay: delay)) }
}
