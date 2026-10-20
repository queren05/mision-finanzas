import SwiftUI
import PDFKit
import Vision
import VisionKit

/// Saca el texto de PDFs y fotos (en el propio iPhone, sin internet)
enum Extract {
    static var filesDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func url(_ name: String) -> URL { filesDir.appendingPathComponent(name) }

    static func store(_ data: Data, ext: String) -> String {
        let name = UUID().uuidString + "." + ext
        try? data.write(to: url(name), options: .atomic)
        return name
    }

    /// texto de un PDF; si es escaneado (sin texto), lo lee con OCR página a página
    static func pdfText(_ data: Data) async -> String {
        guard let doc = PDFDocument(data: data) else { return "" }
        var out = ""
        for i in 0..<doc.pageCount { out += (doc.page(at: i)?.string ?? "") + "\n" }
        if out.trimmingCharacters(in: .whitespacesAndNewlines).count > 40 { return out }
        var ocr = ""
        for i in 0..<min(doc.pageCount, 15) {
            guard let page = doc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let img = page.thumbnail(of: CGSize(width: box.width * scale, height: box.height * scale), for: .mediaBox)
            if let cg = img.cgImage { ocr += await text(in: cg) + "\n" }
        }
        return ocr
    }

    /// texto de una imagen con Vision (español e inglés)
    static func text(in image: CGImage) async -> String {
        await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { r, _ in
                let lines = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            req.recognitionLevel = .accurate
            req.recognitionLanguages = ["es-ES", "en-US"]
            req.usesLanguageCorrection = true
            do { try VNImageRequestHandler(cgImage: image).perform([req]) } catch { cont.resume(returning: "") }
        }
    }

    static func imageText(_ data: Data) async -> String {
        guard let ui = UIImage(data: data), let cg = ui.cgImage else { return "" }
        return await text(in: cg)
    }

    /// junta varias páginas escaneadas en un PDF
    static func pdf(from images: [UIImage]) -> Data {
        let doc = PDFDocument()
        for (i, img) in images.enumerated() { if let p = PDFPage(image: img) { doc.insert(p, at: i) } }
        return doc.dataRepresentation() ?? Data()
    }

    /// foto reducida para guardarla y mandarla (lado mayor 1600 px)
    static func jpeg(_ img: UIImage, maxSide: CGFloat = 1600) -> Data {
        let s = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * s, height: img.size.height * s)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

/// escáner de documentos de la cámara (el del sistema)
struct DocScanner: UIViewControllerRepresentable {
    var done: ([UIImage]) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    final class Coord: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(done: @escaping ([UIImage]) -> Void) { self.done = done }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }); c.dismiss(animated: true)
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { done([]); c.dismiss(animated: true) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) { done([]); c.dismiss(animated: true) }
    }
}
