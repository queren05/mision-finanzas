import SwiftUI
import PhotosUI

/// 4. Kit de marca: le das tu información, Claude crea tus colores, tipografías y tono, y genera contenido con tu estilo
struct BrandView: View {
    @Environment(Store.self) private var store
    @State private var editingInfo = false
    @State private var refItems: [PhotosPickerItem] = []
    @State private var refImages: [Data] = []
    @State private var pieceType = "post"
    @State private var topic = ""
    @State private var openPiece: BrandPiece? = nil
    @State private var pendingDelete: BrandPiece? = nil
    @State private var askDelete = false

    private let types: [(String, String, String)] = [("post", "Post para redes", "camera.fill"), ("email", "Email / newsletter", "envelope.fill"),
                                                     ("web", "Web / landing", "globe"), ("propuesta", "Propuesta", "doc.text.fill")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    flow.appear(0)
                    if let k = store.s.kit { kitCard(k).appear(0.05); generator(k).appear(0.1); pieces(k).appear(0.15) }
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kit de marca")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsButton() } }
            .sheet(isPresented: $editingInfo) { BrandInfoEditor() }
            .sheet(item: $openPiece) { PieceView(piece: $0) }
            .onChange(of: refItems) { _, items in
                Task {
                    var out: [Data] = []
                    for i in items { if let d = try? await i.loadTransferable(type: Data.self), let img = UIImage(data: d) { out.append(Extract.jpeg(img, maxSide: 1000)) } }
                    withAnimation { refImages = out }
                }
            }
            .confirmationDialog("¿Seguro que quieres eliminar este contenido?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { p in
                Button("Eliminar", role: .destructive) { Haptic.heavy(); withAnimation { store.s.pieces.removeAll { $0.id == p.id } } }
            } message: { p in Text(p.title) }
        }
    }

    // MARK: tu información → Claude → tu kit

    private var flow: some View {
        let i = store.s.brandInfo
        let rows: [(String, String, String, Bool)] = [
            ("building.2.fill", "Sobre la empresa", "Misión, visión, valores", !i.about.isEmpty),
            ("text.quote", "Ejemplos de textos", "Posts, emails, landings", !i.samples.isEmpty),
            ("photo.on.rectangle", "Referencias visuales", "Logo, capturas, estilo", !i.visual.isEmpty || !refImages.isEmpty),
            ("person.crop.circle", "Cliente ideal", "Perfil, problemas, objetivos", !i.audience.isEmpty),
            ("shippingbox.fill", "Oferta y servicios", "Beneficios, diferenciadores", !i.offer.isEmpty),
            ("nosign", "Lo que evitamos", "Tonos, palabras, estilos", !i.avoid.isEmpty),
        ]
        let filled = rows.filter { $0.3 }.count
        return VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Tu información", icon: "tray.full.fill", subtitle: "\(filled) de 6 apartados")
            Button { editingInfo = true } label: {
                VStack(spacing: 8) {
                    ForEach(rows, id: \.1) { r in
                        HStack(spacing: 12) {
                            Image(systemName: r.0).frame(width: 24).foregroundStyle(r.3 ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(r.1).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(r.2).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: r.3 ? "checkmark.circle.fill" : "circle").foregroundStyle(r.3 ? Color.income : .secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            HStack {
                PhotosPicker(selection: $refItems, maxSelectionCount: 4, matching: .images) {
                    Label(refImages.isEmpty ? "Añadir referencias" : "\(refImages.count) imágenes", systemImage: "photo.badge.plus").font(.subheadline.weight(.semibold))
                }
                Spacer()
                AIButton(title: store.s.kit == nil ? "Crear mi kit" : "Rehacer kit", key: "kit", icon: "wand.and.stars") { await store.makeKit(images: refImages) }
                    .disabled(filled < 2)
                    .opacity(filled < 2 ? 0.5 : 1)
            }
            if filled < 2 { Text("Rellena al menos dos apartados para que Claude cree tu kit.").font(.caption).foregroundStyle(.secondary) }
        }
        .card()
    }

    private func kitCard(_ k: BrandKit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TU KIT DE MARCA").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                Text(k.name).font(brandFont(k.headingFont, 30).weight(.bold))
                if !k.tagline.isEmpty { Text(k.tagline).font(brandFont(k.bodyFont, 16)).foregroundStyle(.secondary) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Colores").font(.subheadline.weight(.bold))
                HStack(spacing: 8) {
                    ForEach(Array(k.colors.enumerated()), id: \.offset) { i, c in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: c.hex)).frame(height: 54)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.15)))
                            Text(c.hex.uppercased()).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        .onTapGesture { UIPasteboard.general.string = c.hex; Haptic.success() }
                        .appear(Double(i) * 0.06)
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tipografías").font(.subheadline.weight(.bold))
                    HStack(alignment: .firstTextBaseline) { Text("Aa").font(brandFont(k.headingFont, 28).weight(.bold)); Text("Títulos").font(.caption).foregroundStyle(.secondary) }
                    HStack(alignment: .firstTextBaseline) { Text("Aa").font(brandFont(k.bodyFont, 22)); Text("Texto").font(.caption).foregroundStyle(.secondary) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Elementos").font(.subheadline.weight(.bold))
                    Text("Botón principal").font(.caption.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(hex: k.colors.first?.hex ?? "#b39cff"), in: Capsule()).foregroundStyle(.white)
                    Text("Botón secundario").font(.caption.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 7)
                        .overlay(Capsule().strokeBorder(Color(hex: k.colors.first?.hex ?? "#b39cff"), lineWidth: 1.5))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Tono de voz").font(.subheadline.weight(.bold))
                Bullets(items: k.tone, color: Color(hex: k.colors.dropFirst().first?.hex ?? "#ff9f7a"), icon: "checkmark")
            }
            if !k.visual.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reglas visuales").font(.subheadline.weight(.bold))
                    Bullets(items: k.visual, color: .secondary)
                }
            }
        }
        .card(20)
    }

    // MARK: genera cualquier contenido

    private func generator(_ k: BrandKit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Genera cualquier contenido", icon: "square.and.pencil")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(types, id: \.0) { t in
                    Button { Haptic.select(); withAnimation(.spring) { pieceType = t.0 } } label: {
                        Label(t.1, systemImage: t.2).font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(pieceType == t.0 ? Color.black : Color.primary)
                            .background(pieceType == t.0 ? Color.accentColor : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            TextField("¿Sobre qué? (p. ej. «automatiza tu negocio con IA»)", text: $topic, axis: .vertical).lineLimit(1...3)
                .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack {
                Spacer()
                AIButton(title: "Generar", key: "piece", icon: "wand.and.stars") {
                    let t = topic.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { Haptic.warning(); return }
                    await store.makePiece(type: pieceType, topic: t)
                    if store.error == nil { topic = ""; openPiece = store.s.pieces.first }
                }
            }
        }
        .card()
    }

    @ViewBuilder private func pieces(_ k: BrandKit) -> some View {
        if !store.s.pieces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(title: "Tu contenido", icon: "tray.full", color: .secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.s.pieces) { p in
                            Button { openPiece = p } label: { PieceCard(piece: p, kit: k).frame(width: 220) }
                                .buttonStyle(PressableStyle())
                                .contextMenu {
                                    Button { UIPasteboard.general.string = p.title + "\n\n" + p.text; Haptic.success() } label: { Label("Copiar", systemImage: "doc.on.doc") }
                                    Button(role: .destructive) { pendingDelete = p; askDelete = true } label: { Label("Eliminar", systemImage: "trash") }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .card()
        }
    }
}

func brandFont(_ name: String, _ size: CGFloat) -> Font {
    switch name {
    case "serif": return .system(size: size, design: .serif)
    case "rounded": return .system(size: size, design: .rounded)
    case "monospaced": return .system(size: size, design: .monospaced)
    default: return .system(size: size)
    }
}

/// tarjeta de una pieza con los colores de la marca (como una miniatura de post o web)
struct PieceCard: View {
    var piece: BrandPiece
    var kit: BrandKit
    var body: some View {
        let dark = Color(hex: kit.colors.count > 2 ? kit.colors[2].hex : "#16151c")
        let accent = Color(hex: kit.colors.dropFirst().first?.hex ?? kit.colors.first?.hex ?? "#b39cff")
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kit.name).font(.caption2.weight(.heavy)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(label).font(.caption2.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 3).background(accent, in: Capsule()).foregroundStyle(.black)
            }
            Text(piece.title).font(brandFont(kit.headingFont, 17).weight(.heavy)).foregroundStyle(.white).lineLimit(3)
            Text(piece.text).font(brandFont(kit.bodyFont, 11)).foregroundStyle(.white.opacity(0.75)).lineLimit(4)
            Spacer(minLength: 0)
            Capsule().fill(accent).frame(width: 70, height: 6)
        }
        .padding(14)
        .frame(height: 190)
        .background(LinearGradient(colors: [dark, dark.opacity(0.75), accent.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    private var label: String {
        switch piece.type {
        case "post": "Post"
        case "email": "Email"
        case "web": "Web"
        default: "Propuesta"
        }
    }
}

struct PieceView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var piece: BrandPiece
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let k = store.s.kit { PieceCard(piece: piece, kit: k) }
                    Text(piece.title).font(.title3.weight(.bold)).textSelection(.enabled)
                    Text(piece.text).textSelection(.enabled)
                }
                .padding(16)
            }
            .navigationTitle(piece.topic).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: piece.title + "\n\n" + piece.text) { Image(systemName: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { UIPasteboard.general.string = piece.title + "\n\n" + piece.text; Haptic.success() } label: { Label("Copiar texto", systemImage: "doc.on.doc") }
                }
            }
        }
    }
}

struct BrandInfoEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                field("Sobre la empresa", "Qué hacéis, misión, visión y valores", $store.s.brandInfo.about)
                field("Ejemplos de textos", "Pega posts, emails o textos de tu web que te gusten", $store.s.brandInfo.samples)
                field("Referencias visuales", "Cómo es tu logo, estilos o marcas que te gustan (y añade imágenes desde la pantalla anterior)", $store.s.brandInfo.visual)
                field("Cliente ideal", "Quién es, qué problemas tiene, qué quiere conseguir", $store.s.brandInfo.audience)
                field("Oferta y servicios", "Qué vendes, beneficios, qué te diferencia", $store.s.brandInfo.offer)
                field("Lo que evitamos", "Tonos, palabras o estilos que no van contigo", $store.s.brandInfo.avoid)
            }
            .navigationTitle("Tu información").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { Haptic.success(); dismiss() }.bold() } }
        }
    }
    private func field(_ t: String, _ hint: String, _ b: Binding<String>) -> some View {
        Section(t) { TextField(hint, text: b, axis: .vertical).lineLimit(3...10) }
    }
}
