import SwiftUI

/// importe que se puede ocultar con el ojo y que cambia de número con animación
struct AmountText: View {
    @Environment(Store.self) private var store
    var value: Double
    var signed = false
    var font: Font = .body
    var color: Color? = nil
    var body: some View {
        Text(store.hideAmounts ? "•••• €" : (signed ? Money.signed(value) : Money.eur(value)))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color ?? .primary)
            .contentTransition(.numericText(value: value))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
    }
}

/// fila de un movimiento, como en la app del banco
struct TxRow: View {
    @Environment(Store.self) private var store
    var tx: Tx
    var showDate = false

    var body: some View {
        let cat = store.category(tx.categoryId)
        HStack(spacing: 14) {
            icon(cat)
            VStack(alignment: .leading, spacing: 3) {
                Text(title(cat)).font(.body.weight(.semibold)).lineLimit(1)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                AmountText(value: shown, signed: tx.type == .income || (tx.type == .adjust && shown > 0),
                           font: .body.weight(.semibold), color: amountColor)
                if tx.excluded { Text("Excluido").font(.caption2).foregroundStyle(.tertiary) }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder private func icon(_ cat: Category?) -> some View {
        switch tx.type {
        case .transfer:
            Image(systemName: "arrow.left.arrow.right").font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44).background(Color.blue.opacity(0.25), in: Circle()).foregroundStyle(.blue)
        case .adjust:
            Image(systemName: "slider.horizontal.3").font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44).background(Color.gray.opacity(0.25), in: Circle()).foregroundStyle(.secondary)
        default:
            IconBubble(icon: cat?.icon ?? "❔", color: cat?.color ?? "#a9b3c2")
        }
    }
    private func title(_ cat: Category?) -> String {
        if !tx.title.isEmpty { return tx.title }
        if tx.type == .transfer { return "\(store.account(tx.accountId)?.name ?? "?") → \(store.account(tx.toAccountId)?.name ?? "?")" }
        return cat?.name ?? tx.type.label
    }
    private var subtitle: String {
        var parts: [String] = []
        if showDate { parts.append(Day.shortLabel(tx.date)) }
        parts.append(tx.time)
        if !tx.note.isEmpty { parts.append(tx.note) } else if tx.type == .transfer { parts.append("Transferencia") } else if let a = store.account(tx.accountId) { parts.append(a.name) }
        return parts.joined(separator: " · ")
    }
    private var shown: Double {
        switch tx.type {
        case .expense: return -tx.amount
        case .income: return tx.amount
        case .adjust: return tx.amount
        case .transfer: return -tx.amount
        }
    }
    private var amountColor: Color {
        switch tx.type {
        case .income: return .income
        case .adjust: return tx.amount >= 0 ? .income : .primary
        case .transfer: return .secondary
        default: return .primary
        }
    }
}

/// barra de progreso redondeada con animación
struct ProgressBar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 8
    @State private var shown = 0.0
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(color.gradient).frame(width: max(height, g.size.width * min(1, max(0, shown))))
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) { shown = value } }
        .onChange(of: value) { _, v in withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { shown = v } }
    }
}

/// cabecera de sección de las tarjetas del inicio
struct SectionHeader: View {
    var title: String
    var action: String? = nil
    var onTap: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let action, let onTap {
                Button(action) { Haptic.tap(); onTap() }.font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 4)
    }
}

/// aparece desde abajo con un pequeño retraso (para las tarjetas del inicio)
struct Appear: ViewModifier {
    var delay: Double
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on || !Look.shared.motion ? 1 : 0)
            .offset(y: on || !Look.shared.motion ? 0 : 24)
            .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(delay)) { on = true } }
    }
}
extension View {
    func appear(_ delay: Double = 0) -> some View { modifier(Appear(delay: delay)) }
}
