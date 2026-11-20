import SwiftUI
import UIKit

/// fotos ya descargadas, en memoria: al volver a verlas salen al instante y no parpadean
enum CacheImagenes {
    static let memoria: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.totalCostLimit = 120 * 1024 * 1024
        return c
    }()

    static func cargar(_ url: URL) async -> UIImage? {
        if let i = memoria.object(forKey: url as NSURL) { return i }
        var r = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        r.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (d, resp) = try? await URLSession.shared.data(for: r),
              ((resp as? HTTPURLResponse)?.statusCode ?? 200) < 400,
              let img = UIImage(data: d) else { return nil }
        // se reduce para no gastar memoria con fotos enormes
        let lado: CGFloat = 1400
        let k = min(1, lado / max(img.size.width, img.size.height))
        let lista: UIImage
        if k < 1 {
            let tam = CGSize(width: img.size.width * k, height: img.size.height * k)
            let f = UIGraphicsImageRendererFormat(); f.scale = 1
            lista = UIGraphicsImageRenderer(size: tam, format: f).image { _ in img.draw(in: CGRect(origin: .zero, size: tam)) }
        } else {
            lista = await img.byPreparingForDisplay() ?? img
        }
        memoria.setObject(lista, forKey: url as NSURL, cost: Int(lista.size.width * lista.size.height * 4))
        return lista
    }
}

/// imagen de internet con memoria (en lugar de AsyncImage, que vuelve a cargar y parpadea)
struct ImagenRemota<Hueco: View>: View {
    let url: URL?
    var ajuste: ContentMode = .fill
    @ViewBuilder var hueco: () -> Hueco
    @State private var img: UIImage?
    @State private var cargada: URL?

    init(url: URL?, ajuste: ContentMode = .fill, @ViewBuilder hueco: @escaping () -> Hueco) {
        self.url = url
        self.ajuste = ajuste
        self.hueco = hueco
        let ya = url.flatMap { CacheImagenes.memoria.object(forKey: $0 as NSURL) }
        _img = State(initialValue: ya)
        _cargada = State(initialValue: ya == nil ? nil : url)
    }

    var body: some View {
        ZStack {
            if let img, cargada == url {
                Image(uiImage: img).resizable().aspectRatio(contentMode: ajuste).transition(.opacity)
            } else {
                hueco()
            }
        }
        .task(id: url) {
            guard let url, cargada != url else { return }
            if let i = await CacheImagenes.cargar(url), !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) { img = i; cargada = url }
            }
        }
    }
}
