// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Real-time offline Word, Character, Sentence, Paragraph, and Reading-Time counter.
struct WordCounterToolView: View {
    let tool: Tool

    @EnvironmentObject private var history: HistoryService

    @State private var text: String = ""
    @State private var copied = false
    @State private var exportURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ToolMetricTile(label: "Words", value: "\(text.wordCount)", accent: true)
                ToolMetricTile(label: "Characters", value: "\(text.characterCount)")
                ToolMetricTile(label: "No Spaces", value: "\(text.charactersWithoutSpacesCount)")
                ToolMetricTile(label: "Sentences", value: "\(text.sentenceCount)")
                ToolMetricTile(label: "Paragraphs", value: "\(text.paragraphCount)")
                ToolMetricTile(
                    label: "Reading Time",
                    value: text.wordCount == 0 ? "0 min" : "~\(text.estimatedReadingMinutes) min"
                )
            }

            ToolSettingsCard(
                title: "Text Workspace",
                subtitle: "Type, paste, or import a plain text file",
                badge: "\(text.wordCount) words"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .font(PKFont.body(.subheadline))
                            .frame(minHeight: 190)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PKColors.border, lineWidth: 1))
                            .accessibilityIdentifier("wordcounter_editor")

                        if text.isEmpty {
                            Text("Start typing or paste your article, caption, or essay here…")
                                .font(PKFont.body(.subheadline))
                                .foregroundStyle(PKColors.textMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            text = """
                            Perkakasku processes documents and images directly inside an isolated mobile studio without forced logins or noisy ads.

                            Measure article word count, sentence structure, and estimated reading speed cleanly in real time.
                            """
                            PKHaptics.selection()
                        } label: {
                            Text("Sample Text")
                        }
                        .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))

                        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                            Button {
                                text = pasted
                                PKHaptics.selection()
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                        }

                        if !text.isEmpty {
                            Button {
                                text = ""
                                exportURL = nil
                                PKHaptics.selection()
                            } label: {
                                Text("Clear")
                            }
                            .buttonStyle(PKPillButtonStyle(variant: .ghost, compact: true))
                        }
                    }

                    FileImportButton(
                        title: "Import .txt File",
                        hint: "Load text directly from Files app",
                        icon: "doc.text",
                        allowedUTIs: [UTType.plainText.identifier, UTType.text.identifier],
                        allowsMultiple: false,
                        compact: true,
                        onError: { errorMessage = $0 }
                    ) { urls in
                        guard let url = urls.first,
                              let data = try? LocalFileManager.shared.read(from: url),
                              let content = String(data: data, encoding: .utf8) else {
                            errorMessage = "Could not decode UTF-8 text from selected file."
                            return
                        }
                        text = content
                        PKHaptics.success()
                    }

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = summaryReport
                            copied = true
                            PKHaptics.success()
                        } label: {
                            Label(copied ? "Copied Report" : "Copy Report", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                        .disabled(text.isEmpty)

                        Button {
                            exportSummary()
                        } label: {
                            Label("Export .TXT", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PKPillButtonStyle(variant: .primary, compact: true))
                        .disabled(text.isEmpty)
                    }
                }
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let exportURL {
                ToolResultCard(
                    title: "Analysis Report Saved",
                    subtitle: "Plain text summary with statistics exported.",
                    fileURL: exportURL,
                    outputBytes: exportURL.fileSize,
                    exportLabel: "Share Report (.txt)"
                )
            }
        }
    }

    private var summaryReport: String {
        """
        Perkakasku Word Analysis
        ------------------------
        Words: \(text.wordCount)
        Characters (with spaces): \(text.characterCount)
        Characters (no spaces): \(text.charactersWithoutSpacesCount)
        Sentences: \(text.sentenceCount)
        Paragraphs: \(text.paragraphCount)
        Estimated Reading Time: \(text.estimatedReadingMinutes) min

        Text:
        \(text)
        """
    }

    private func exportSummary() {
        let name = "word_analysis_\(Int(Date().timeIntervalSince1970)).txt"
        let dest = LocalFileManager.shared.documentsURL(for: name)
        guard let data = summaryReport.data(using: .utf8) else { return }
        do {
            try LocalFileManager.shared.write(data: data, to: dest)
            exportURL = dest
            history.record(
                tool: tool,
                inputFileName: "\(text.wordCount) words",
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
