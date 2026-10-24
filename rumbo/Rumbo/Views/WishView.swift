import SwiftUI
import PhotosUI

let wishPink = Color(hex: "#ff7eb6")

enum WishText {
    static func priority(_ p: Int) -> String { ["Algún día", "Me gustaría", "Lo quiero ya"][max(0, min(2, p))] }
    static func color(_ p: Int) -> Color { [Color.secondary, Color(hex: "#7ac8ff"), wishPink][max(0, min(2, p))] }
}

/// Lista de deseos: cosas que te quieres comprar más adelante
struct WishView: View {
    @Environment(Store.self) private var store
    @State private var showBought = false
    @State private var sort = 0
    @State private var editing: Wish? = nil
    @State private var adding = false
    @State private var pendingDelete: Wish? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !pending.isEmpty { summary.appear(0) }
                    Picker("", selection: $showBought.animation(.snappy)) {
                        Text("Pendientes").tag(false)
                        Text("Comprados").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if list.isEmpty {
                        EmptyCard(icon: showBought ? "bag.fill" : "gift.fill", title: showBought ? "Nada comprado todavía" : "Sin deseos", text: "")
                    }
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, w in
                        Button { editing = w } label: { WishRow(wish: w) }
                            .buttonStyle(PressableStyle())
                            .contextMenu { menu(w) }
                            .appear(Double(i) * 0.02)
                    }
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Deseos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Ordenar", selection: $sort.animation(.snappy)) {
                            Label("Prioridad", systemImage: "flag").tag(0)
                            Label("Más baratos", systemImage: "arrow.up").tag(1)
                            Label("Más caros", systemImage: "arrow.down").tag(2)
                            Label("Recientes", systemImage: "clock").tag(3)
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { WishEditor(original: nil) }
            .sheet(item: $editing) { WishEditor(original: $0) }
            .confirmationDialog("¿Seguro que quieres eliminarlo?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible, presenting: pendingDelete) { w in
                Button("Eliminar", role: .destructive) { Haptic.heavy(); withAnimation { store.s.wishes.removeAll { $0.id == w.id } } }
                Button("Cancelar", role: .cancel) {}
            } message: { w in Text(w.title) }
        }
    }

    private var pending: [Wish] { store.s.wishes.filter { $0.bought == nil } }

    private var list: [Wish] {
        if showBought { return store.s.wishes.filter { $0.bought != nil }.sorted { ($0.bought ?? .distantPast) > ($1.bought ?? .distantPast) } }
        let l = pending
        switch sort {
        case 1: return l.sorted { ($0.price ?? .infinity) < ($1.price ?? .infinity) }
        case 2: return l.sorted { ($0.price ?? -1) > ($1.price ?? -1) }
        case 3: return l.sorted { $0.created > $1.created }
        default: return l.sorted { $0.priority != $1.priority ? $0.priority > $1.priority : $0.created > $1.created }
        }
    }

    private var summary: some View {
        let total = pending.compactMap(\.price).reduce(0, +)
        let saved = pending.map(\.saved).reduce(0, +)
        let spent = store.s.wishes.filter { $0.bought != nil }.compactMap(\.price).reduce(0, +)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Todo lo que quieres").font(.caption).foregroundStyle(.secondary)
                    Text(Money.eur(total)).font(.system(size: 30, weight: .bold, design: .rounded)).contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(pending.count) cosa\(pending.count == 1 ? "" : "s")").font(.subheadline.weight(.semibold))
                    if spent > 0 { Text("Comprado: \(Money.eur(spent))").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if saved > 0 && total > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: min(1, saved / total)).tint(wishPink)
                    Text("Ahorrado \(Money.eur(saved))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    @ViewBuilder private func menu(_ w: Wish) -> some View {
        if w.bought == nil {
            Button { Haptic.success(); mark(w, bought: true) } label: { Label("Lo he comprado", systemImage: "bag.fill") }
        } else {
            Button { mark(w, bought: false) } label: { Label("Volver a pendientes", systemImage: "arrow.uturn.backward") }
        }
        if let u = URL(string: w.link), !w.link.isEmpty {
            Link(destination: u) { Label("Abrir enlace", systemImage: "safari") }
        }
        Button(role: .destructive) { pendingDelete = w } label: { Label("Eliminar", systemImage: "trash") }
    }

    private func mark(_ w: Wish, bought: Bool) {
        guard let i = store.s.wishes.firstIndex(where: { $0.id == w.id }) else { return }
        withAnimation(.snappy) { store.s.wishes[i].bought = bought ? Date() : nil }
    }
}

struct WishThumb: View {
    let wish: Wish
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(WishText.color(wish.priority).opacity(0.15))
            if let d = wish.photo, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let u = URL(string: wish.imageURL), !wish.imageURL.isEmpty {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { icon }
            } else { icon }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    private var icon: some View {
        Image(systemName: "gift.fill").font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(WishText.color(wish.priority))
    }
}

struct WishRow: View {
    let wish: Wish
    var body: some View {
        HStack(spacing: 14) {
            WishThumb(wish: wish)
            VStack(alignment: .leading, spacing: 5) {
                Text(wish.title).font(.headline).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let p = wish.price { Text(Money.eur(p)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary) }
                    if let b = wish.bought {
                        Text(b.formatted(.dateTime.day().month(.abbreviated).year())).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(WishText.priority(wish.priority)).font(.caption.weight(.semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(WishText.color(wish.priority).opacity(0.18), in: Capsule())
                            .foregroundStyle(WishText.color(wish.priority))
                    }
                }
                if wish.bought == nil, let pr = wish.progress, wish.saved > 0 {
                    ProgressView(value: pr).tint(wishPink)
                }
            }
            Spacer(minLength: 0)
            if wish.bought != nil { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Color.income) }
        }
        .card(12)
    }
}

/// tarjeta de Hoy: lo próximo que quieres
struct WishMini: View {
    @Environment(Store.self) private var store
    var body: some View {
        let l = store.s.wishes.filter { $0.bought == nil }.sorted { $0.priority != $1.priority ? $0.priority > $1.priority : $0.created > $1.created }
        if !l.isEmpty {
            Button { Router.shared.open("deseos") } label: {
                VStack(alignment: .leading, spacing: 10) {
                    CardTitle(title: "Deseos", icon: "gift.fill", color: wishPink, subtitle: Money.eur(l.compactMap(\.price).reduce(0, +)))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(l.prefix(8)) { w in
                                VStack(alignment: .leading, spacing: 4) {
                                    WishThumb(wish: w, size: 76)
                                    Text(w.title).font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                                    if let p = w.price { Text(Money.eur(p)).font(.caption2).foregroundStyle(.secondary) }
                                }
                                .frame(width: 76)
                            }
                        }
                    }
                }
                .card()
            }
            .buttonStyle(PressableStyle())
        }
    }
}

/// crear o cambiar un deseo
struct WishEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Wish?
    @State private var w = Wish(title: "")
    @State private var priceText = ""
    @State private var savedText = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var loading = false
    @State private var askDelete = false
    @State private var filledFrom = ""
    @State private var userPhoto = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            WishThumb(wish: w, size: 72)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.fill").font(.caption2).foregroundStyle(.white)
                                        .padding(5).background(.black.opacity(0.55), in: Circle()).padding(4)
                                }
                        }
                        .buttonStyle(.plain)
                        TextField("Qué quieres", text: $w.title, axis: .vertical).font(.headline)
                    }
                    if w.photo != nil || !w.imageURL.isEmpty {
                        Button("Quitar la foto", role: .destructive) { w.photo = nil; w.imageURL = ""; userPhoto = true }
                    }
                }
                Section {
                    HStack {
                        Text("Precio")
                        TextField("0,00", text: $priceText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("€").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Ahorrado")
                        TextField("0,00", text: $savedText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("€").foregroundStyle(.secondary)
                    }
                    Picker("Prioridad", selection: $w.priority) {
                        ForEach([2, 1, 0], id: \.self) { Text(WishText.priority($0)).tag($0) }
                    }
                }
                Section {
                    HStack {
                        TextField("Enlace de la tienda", text: $w.link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        if loading { ProgressView() } else if !w.link.isEmpty {
                            Button { Task { await fill() } } label: { Image(systemName: "arrow.down.circle.fill") }
                        }
                        Button {
                            if let s = UIPasteboard.general.string { w.link = s.trimmingCharacters(in: .whitespacesAndNewlines); Task { await fill() } }
                        } label: { Image(systemName: "doc.on.clipboard") }
                    }
                    .buttonStyle(.borderless)
                    if let u = URL(string: w.link), !w.link.isEmpty, u.scheme != nil {
                        Link(destination: u) { Label("Abrir", systemImage: "safari") }
                    }
                }
                Section("Nota") {
                    TextField("Talla, color, dónde está más barato…", text: $w.note, axis: .vertical).lineLimit(2...8)
                }
                if original != nil {
                    Section {
                        if w.bought == nil {
                            Button { Haptic.success(); w.bought = Date(); save() } label: { Label("Lo he comprado", systemImage: "bag.fill") }
                        } else {
                            Button { w.bought = nil; save() } label: { Label("Volver a pendientes", systemImage: "arrow.uturn.backward") }
                        }
                        Button("Eliminar", role: .destructive) { askDelete = true }
                    }
                }
            }
            .navigationTitle(original == nil ? "Nuevo deseo" : "Deseo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(w.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let o = original {
                    w = o
                    filledFrom = o.link.trimmingCharacters(in: .whitespacesAndNewlines)
                    userPhoto = o.photo != nil
                    priceText = o.price.map(Money.num) ?? ""
                    savedText = o.saved > 0 ? Money.num(o.saved) : ""
                }
            }
            .task(id: w.link) {
                // al pegar o escribir el enlace se rellena solo (foto, nombre y precio)
                let link = w.link.trimmingCharacters(in: .whitespacesAndNewlines)
                guard link.hasPrefix("http"), link != filledFrom else { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                await fill()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        w.photo = WishEditor.thumb(img); w.imageURL = ""; userPhoto = true
                    }
                }
            }
            .confirmationDialog("¿Seguro que quieres eliminarlo?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    Haptic.heavy()
                    store.s.wishes.removeAll { $0.id == w.id }
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            } message: { Text(w.title) }
        }
    }

    private func save() {
        w.title = w.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.title.isEmpty else { return }
        w.price = Money.parse(priceText)
        w.saved = Money.parse(savedText) ?? 0
        if let i = store.s.wishes.firstIndex(where: { $0.id == w.id }) { store.s.wishes[i] = w } else { store.s.wishes.append(w) }
        Haptic.tap()
        dismiss()
    }

    /// rellena nombre, foto y precio con lo que diga la página de la tienda
    private func fill() async {
        let link = w.link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: link), u.scheme?.hasPrefix("http") == true else { return }
        filledFrom = link
        loading = true
        defer { loading = false }
        guard let info = await LinkInfo.fetch(u) else { return }
        if w.title.trimmingCharacters(in: .whitespaces).isEmpty, let t = info.title { w.title = t }
        if priceText.isEmpty, let p = info.price { priceText = Money.num(p) }
        // la foto del producto: siempre la del enlace nuevo, salvo que hayas puesto una tuya
        if !userPhoto {
            for img in info.images {
                var req = URLRequest(url: img, timeoutInterval: 15)
                req.setValue(LinkInfo.mobileUA, forHTTPHeaderField: "User-Agent")
                req.setValue(u.absoluteString, forHTTPHeaderField: "Referer")
                if let (d, _) = try? await URLSession.shared.data(for: req), let ui = UIImage(data: d), ui.size.width >= 80 {
                    w.photo = WishEditor.thumb(ui); w.imageURL = ""
                    break
                }
            }
        }
    }

    static func thumb(_ img: UIImage) -> Data? {
        let side: CGFloat = 400
        let k = min(1, side / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * k, height: img.size.height * k)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
    }
}

/// lee el título, las fotos y el precio de una página de producto
enum LinkInfo {
    struct Info { var title: String?; var images: [URL] = []; var price: Double? }

    static let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    static func fetch(_ url: URL) async -> Info? {
        var best: Info? = nil
        // algunas tiendas solo dan la foto a la versión de ordenador
        for ua in [mobileUA, desktopUA] {
            guard let html = await page(url, ua) else { continue }
            let i = parse(html, base: url)
            if best == nil || (best!.images.isEmpty && !i.images.isEmpty) {
                var m = i
                if m.title == nil { m.title = best?.title }
                if m.price == nil { m.price = best?.price }
                best = m
            }
            if !(best?.images.isEmpty ?? true) { break }
        }
        return best
    }

    private static func page(_ url: URL, _ ua: String) async -> String? {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("es-ES,es;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (d, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return String(decoding: d.prefix(3_000_000), as: UTF8.self)
    }

    static func parse(_ html: String, base: URL) -> Info {
        var info = Info()
        info.title = (meta(html, "og:title") ?? meta(html, "twitter:title") ?? tag(html, "title")).map(clean)
        if let t = info.title, t.count > 90 { info.title = String(t.prefix(90)) }
        // fotos, de la más fiable a la menos
        var cands: [String] = []
        for k in ["og:image:secure_url", "og:image", "twitter:image", "twitter:image:src", "product:image"] { if let v = meta(html, k) { cands.append(v) } }
        cands += all(html, #"data-old-hires="([^"]+)""#)                       // Amazon
        cands += all(html, #""hiRes"\s*:\s*"([^"]+)""#)                         // Amazon
        cands += all(html, #""large"\s*:\s*"(https:[^"]+)""#)                   // Amazon
        cands += all(html, #"<link[^>]+rel=["']image_src["'][^>]*href=["']([^"']+)["']"#)
        cands += all(html, #""image"\s*:\s*"([^"]+\.(?:jpe?g|png|webp)[^"]*)""#) // JSON-LD
        cands += all(html, #""image"\s*:\s*\[\s*"([^"]+)""#)                    // JSON-LD con lista
        cands += all(html, #"itemprop=["']image["'][^>]*(?:content|src)=["']([^"']+)["']"#)
        var seen = Set<String>()
        for c in cands {
            let s = clean(c).replacingOccurrences(of: "\\/", with: "/")
            guard !s.isEmpty, !seen.contains(s), let u = URL(string: s.hasPrefix("//") ? "https:" + s : s, relativeTo: base)?.absoluteURL else { continue }
            seen.insert(s)
            info.images.append(u)
            if info.images.count >= 6 { break }
        }
        let p = meta(html, "product:price:amount") ?? meta(html, "og:price:amount")
            ?? first(html, #""price"\s*:\s*"?([0-9]+(?:[.,][0-9]{1,2})?)"#)
            ?? first(html, #"itemprop="price"[^>]*content="([0-9.,]+)""#)
            ?? first(html, #"class="a-offscreen">([0-9.,]+)\s*€"#)
        if let p { info.price = Money.parse(p) }
        return info
    }

    private static func meta(_ html: String, _ name: String) -> String? {
        let n = NSRegularExpression.escapedPattern(for: name)
        return first(html, #"<meta[^>]+(?:property|name|itemprop)=["']"# + n + #"["'][^>]*content=["']([^"']+)["']"#)
            ?? first(html, #"<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name|itemprop)=["']"# + n + #"["']"#)
    }
    private static func tag(_ html: String, _ t: String) -> String? { first(html, "<\(t)[^>]*>([^<]+)</\(t)>") }
    private static func first(_ s: String, _ pattern: String) -> String? { all(s, pattern).first }
    private static func all(_ s: String, _ pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).prefix(4).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
            return String(s[r])
        }
    }
    private static func clean(_ s: String) -> String {
        var t = s
        for (a, b) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&nbsp;", " "), ("\\u0026", "&")] { t = t.replacingOccurrences(of: a, with: b) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
