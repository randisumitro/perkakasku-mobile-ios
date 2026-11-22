// xcode: set sdk=iOS

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Local PDF AES encryption workbench using PDFKit write options.
struct PDFPasswordView: View {
    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 0
    @State private var userPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var ownerPassword: String = ""
    @State private var showPasswords = false

    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var verifiedEncrypted: Bool = false
    @State private var errorMessage: String?

    private var validationError: String? {
        if userPassword.isEmpty { return "Enter an open password." }
        if userPassword.count < 4 { return "Password must be at least 4 characters." }
        if userPassword != confirmPassword { return "Passwords do not match." }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF to Lock" : "Choose Another PDF",
                hint: "Encrypt locally with Apple PDFKit — passwords stay on your iPhone",
                icon: "lock.doc.fill",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                selectedURL = url
                pageCount = pdfService.pageCount(url: url)
                outputURL = nil
                verifiedEncrypted = false
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Password Protection",
                    badge: pageCount > 0 ? "\(pageCount) pages" : nil
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: "\(selectedURL.formattedSize) · \(pageCount) pages",
                            icon: "doc.fill"
                        ) {
                            self.selectedURL = nil
                            outputURL = nil
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Document Open Password")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            passwordInput("Minimum 4 characters", text: $userPassword)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            passwordInput("Re-enter password", text: $confirmPassword)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Permissions / Owner Password (Optional)")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            passwordInput("Leave blank to match open password", text: $ownerPassword)
                        }

                        Toggle("Show passwords", isOn: $showPasswords)
                            .font(PKFont.body(.subheadline))

                        if let validationError, !userPassword.isEmpty || !confirmPassword.isEmpty {
                            Text(validationError)
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.error)
                        }

                        PrimaryButton(
                            title: "Encrypt & Lock PDF",
                            icon: "lock.fill",
                            isLoading: isProcessing
                        ) {
                            protectPDF()
                        }
                        .disabled(validationError != nil)
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Encrypting PDF locally…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL {
                ToolResultCard(
                    title: "PDF Encrypted",
                    subtitle: verifiedEncrypted
                        ? "Verified locked on disk: opening this PDF now prompts for your password."
                        : "Encrypted PDF saved.",
                    fileURL: outputURL,
                    originalBytes: selectedURL?.fileSize,
                    outputBytes: outputURL.fileSize,
                    metrics: [
                        ("Encryption", verifiedEncrypted ? "Verified" : "Protected"),
                        ("Pages", "\(pageCount)"),
                    ],
                    exportLabel: "Export Protected PDF"
                )
            }
        }
    }

    @ViewBuilder
    private func passwordInput(_ placeholder: String, text: Binding<String>) -> some View {
        Group {
            if showPasswords {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .font(PKFont.mono(.subheadline, weight: .medium))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .padding(11)
        .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PKColors.border, lineWidth: 1))
    }

    private func protectPDF() {
        guard let url = selectedURL else { return }
        if let err = validationError {
            errorMessage = err
            PKHaptics.error()
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "_locked", ext: "pdf")
        do {
            let protected = try pdfService.protect(
                url: url,
                userPassword: userPassword,
                ownerPassword: ownerPassword.isEmpty ? nil : ownerPassword,
                outputName: outName
            )
            verifiedEncrypted = PDFDocument(url: protected)?.isEncrypted ?? false
            outputURL = protected

            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: protected.lastPathComponent,
                outputURL: protected,
                status: .completed,
                fileSize: protected.fileSize
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
