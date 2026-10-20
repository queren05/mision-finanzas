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

    /// importe total de un ticket o factura (la línea con «total», o el número más alto con decimales)
    static func total(in text: String) -> Double? {
        let num = try! NSRegularExpression(pattern: "(\\d{1,3}(?:[.\\s]\\d{3})*|\\d+)[,.](\\d{2})(?!\\d)")
        func values(_ line: String) -> [Double] {
            num.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { m in
                guard let a = Range(m.range(at: 1), in: line), let b = Range(m.range(at: 2), in: line) else { return nil }
                return Double(line[a].filter(\.isNumber) + "." + line[b])
            }
        }
        let lines = text.components(separatedBy: .newlines)
        for (i, l) in lines.enumerated() {
            let low = l.lowercased()
            guard low.contains("total"), !low.contains("subtotal"), !low.contains("base") else { continue }
            if let v = values(l).last { return v }
            if i + 1 < lines.count, let v = values(lines[i + 1]).first { return v }
        }
        return lines.flatMap(values).max()
    }

    /// primera fecha dd/mm/aaaa (o dd-mm-aa) del texto, como yyyy-MM-dd
    static func date(in text: String) -> String? {
        let re = try! NSRegularExpression(pattern: "\\b(\\d{1,2})[/.-](\\d{1,2})[/.-](\\d{4}|\\d{2})\\b")
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let d = Range(m.range(at: 1), in: text).flatMap({ Int(text[$0]) }), let mo = Range(m.range(at: 2), in: text).flatMap({ Int(text[$0]) }),
                  var y = Range(m.range(at: 3), in: text).flatMap({ Int(text[$0]) }) else { continue }
            if y < 100 { y += 2000 }
            guard (1...31).contains(d), (1...12).contains(mo), (2000...2100).contains(y) else { continue }
            return String(format: "%04d-%02d-%02d", y, mo, d)
        }
        return nil
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
