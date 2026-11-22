// xcode: set sdk=iOS

import SwiftUI

/// Live QR Code studio generating crisp high-res PNG and scalable Vector SVG files on device.
struct QRCodeToolView: View {
    enum PayloadType: String, CaseIterable, Identifiable {
        case textURL = "URL / Text"
        case wifi = "Wi-Fi"
        case vcard = "Contact"

        var id: String { rawValue }
    }

    enum WiFiSecurity: String, CaseIterable, Identifiable {
        case wpa = "WPA/WPA2"
        case wep = "WEP"
        case none = "Open"

        var id: String { rawValue }
        var token: String {
            switch self {
            case .wpa: return "WPA"
            case .wep: return "WEP"
            case .none: return "nopass"
            }
        }
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var payloadType: PayloadType = .textURL
    @State private var textInput: String = "https://perkakasku.cloud"

    // Wi-Fi fields
    @State private var wifiSSID: String = ""
    @State private var wifiPassword: String = ""
    @State private var wifiSecurity: WiFiSecurity = .wpa

    // vCard fields
    @State private var contactName: String = ""
    @State private var contactPhone: String = ""
    @State private var contactEmail: String = ""

    @State private var fgColor: Color = Color(red: 0x18 / 255, green: 0x16 / 255, blue: 0x14 / 255)
    @State private var bgColor: Color = .white
    @State private var exportSizePx: Int = 1024

    @State private var exportedURL: URL?
    @State private var exportedSVGURL: URL?
    @State private var errorMessage: String?

    private var effectivePayload: String {
        switch payloadType {
        case .textURL:
            return textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        case .wifi:
            let ssid = wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ssid.isEmpty else { return "" }
            return "WIFI:T:\(wifiSecurity.token);S:\(ssid);P:\(wifiPassword);;"
        case .vcard:
            let name = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return "" }
            return """
            BEGIN:VCARD
            VERSION:3.0
            FN:\(name)
            TEL:\(contactPhone)
            EMAIL:\(contactEmail)
            END:VCARD
            """
        }
    }

    private var previewQRImage: UIImage? {
        guard !effectivePayload.isEmpty else { return nil }
        return imageService.generateQRCode(
            from: effectivePayload,
            size: CGSize(width: 640, height: 640),
            foreground: UIColor(fgColor),
            background: UIColor(bgColor)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ToolSettingsCard(title: "QR Content & Styling") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Type", selection: $payloadType) {
                        ForEach(PayloadType.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch payloadType {
                    case .textURL:
                        TextField("Enter website URL or text…", text: $textInput, axis: .vertical)
                            .lineLimit(2...4)
                            .font(PKFont.mono(.subheadline, weight: .regular))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(11)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("qr_payload_field")

                    case .wifi:
                        TextField("Network Name (SSID)", text: $wifiSSID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(10)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        TextField("Password", text: $wifiPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(10)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        Picker("Security", selection: $wifiSecurity) {
                            ForEach(WiFiSecurity.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                    case .vcard:
                        TextField("Full Name", text: $contactName)
                            .padding(10)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        TextField("Phone Number", text: $contactPhone)
                            .keyboardType(.phonePad)
                            .padding(10)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        TextField("Email Address", text: $contactEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 16) {
                        ColorPicker("Code Ink", selection: $fgColor, supportsOpacity: false)
                            .font(PKFont.body(.caption, weight: .semibold))
                        ColorPicker("Backdrop", selection: $bgColor, supportsOpacity: false)
                            .font(PKFont.body(.caption, weight: .semibold))
                    }

                    Picker("PNG Resolution", selection: $exportSizePx) {
                        Text("512 px").tag(512)
                        Text("1024 px").tag(1024)
                        Text("2048 px").tag(2048)
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Live QR Code Canvas
            ToolSettingsCard(title: "Live Preview", badge: "ECC Level Q") {
                VStack(spacing: 14) {
                    if let qr = previewQRImage {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 210, height: 210)
                            .padding(14)
                            .background(bgColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(PKColors.border, lineWidth: 1)
                            )
                            .frame(maxWidth: .infinity)
                    } else {
                        EmptyStateView(
                            icon: "qrcode",
                            title: "Enter QR payload above",
                            subtitle: "Your QR code renders live as you type."
                        )
                    }

                    HStack(spacing: 10) {
                        PrimaryButton(title: "Export PNG", icon: "photo") {
                            generatePNG()
                        }
                        .accessibilityIdentifier("qr_export_button")

                        PrimaryButton(title: "Vector SVG", icon: "curlybraces", variant: .ink) {
                            generateSVG()
                        }
                    }
                    .disabled(effectivePayload.isEmpty)
                }
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let exportedURL {
                ToolResultCard(
                    title: "QR PNG Saved",
                    subtitle: "Ready for print or digital sharing.",
                    fileURL: exportedURL,
                    outputBytes: exportedURL.fileSize,
                    metrics: [
                        ("Resolution", "\(exportSizePx) × \(exportSizePx) px"),
                        ("Payload", "\(effectivePayload.count) chars"),
                    ],
                    exportLabel: "Share QR PNG",
                    imageToSave: previewQRImage
                )
            }

            if let exportedSVGURL {
                ToolResultCard(
                    title: "Vector SVG Saved",
                    subtitle: "Lossless scalable SVG for graphic design tools.",
                    fileURL: exportedSVGURL,
                    outputBytes: exportedSVGURL.fileSize,
                    metrics: [
                        ("Format", "Vector SVG"),
                        ("Size", exportedSVGURL.formattedSize),
                    ],
                    exportLabel: "Share Vector SVG"
                )
            }
        }
    }

    private func generatePNG() {
        let size = CGSize(width: exportSizePx, height: exportSizePx)
        guard let img = imageService.generateQRCode(
            from: effectivePayload,
            size: size,
            foreground: UIColor(fgColor),
            background: UIColor(bgColor)
        ), let pngData = img.pngData() else {
            errorMessage = "Could not render QR PNG."
            PKHaptics.error()
            return
        }

        let name = "qrcode_\(exportSizePx)px_\(Int(Date().timeIntervalSince1970)).png"
        let dest = LocalFileManager.shared.documentsURL(for: name)
        do {
            try LocalFileManager.shared.write(data: pngData, to: dest)
            exportedURL = dest
            history.record(
                tool: tool,
                inputFileName: payloadType.rawValue,
                outputFileName: name,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(pngData.count)
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }
    }

    private func generateSVG() {
        let fgHex = UIColor(fgColor).hexString
        let bgHex = UIColor(bgColor).hexString
        guard let svg = imageService.generateQRCodeSVG(
            from: effectivePayload,
            sizePx: exportSizePx,
            marginModules: 2,
            foregroundHex: fgHex,
            backgroundHex: bgHex
        ), let data = svg.data(using: .utf8) else {
            errorMessage = "Could not render SVG vector."
            PKHaptics.error()
            return
        }

        let name = "qrcode_vector_\(Int(Date().timeIntervalSince1970)).svg"
        let dest = LocalFileManager.shared.documentsURL(for: name)
        do {
            try LocalFileManager.shared.write(data: data, to: dest)
            exportedSVGURL = dest
            history.record(
                tool: tool,
                inputFileName: payloadType.rawValue,
                outputFileName: name,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(data.count)
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }
    }
}

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}
