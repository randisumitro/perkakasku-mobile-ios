// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Native JSON Formatter, Minifier, Key Sorter, Schema Validator & Line Diff comparator.
struct JSONFormatterToolView: View {
    enum WorkspaceTab: String, CaseIterable, Identifiable {
        case format = "Format & Validate"
        case diff = "Compare / Diff"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var history: HistoryService

    @State private var activeTab: WorkspaceTab = .format
    @State private var inputJSON: String = ""
    @State private var compareJSON: String = ""
    @State private var formattedOutput: String = ""
    @State private var stats: JSONStats?
    @State private var diffLines: [DiffLine] = []

    @State private var indentSpaces: Int = 2
    @State private var sortKeys: Bool = false
    @State private var statusBanner: String?
    @State private var errorMessage: String?
    @State private var exportURL: URL?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Mode", selection: $activeTab) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if activeTab == .format {
                formatSection
            } else {
                diffSection
            }
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ToolSettingsCard(title: "JSON Input", subtitle: "Paste, type, or import a .json file") {
                VStack(alignment: .leading, spacing: 10) {
                    TextEditor(text: $inputJSON)
                        .font(PKFont.mono(.footnote, weight: .regular))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .frame(minHeight: 170)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PKColors.border, lineWidth: 1))
                        .accessibilityIdentifier("json_input_editor")

                    HStack(spacing: 8) {
                        Button("Load Sample") {
                            inputJSON = #"{"project":"Perkakasku","version":2,"local":true,"tools":["compress-pdf","ocr","qr-code"],"theme":{"light":"alabaster","dark":"espresso"}}"#
                            errorMessage = nil
                            statusBanner = nil
                            PKHaptics.selection()
                        }
                        .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))

                        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                            Button("Paste") {
                                inputJSON = pasted
                                PKHaptics.selection()
                            }
                            .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                        }

                        if !inputJSON.isEmpty {
                            Button("Clear") {
                                inputJSON = ""
                                formattedOutput = ""
                                stats = nil
                                statusBanner = nil
                                errorMessage = nil
                                exportURL = nil
                            }
                            .buttonStyle(PKPillButtonStyle(variant: .ghost, compact: true))
                        }
                    }

                    FileImportButton(
                        title: "Import .json File",
                        hint: "Load JSON file directly from Files",
                        icon: "curlybraces",
                        allowedUTIs: [UTType.json.identifier, UTType.plainText.identifier],
                        allowsMultiple: false,
                        compact: true,
                        onError: { errorMessage = $0 }
                    ) { urls in
                        guard let url = urls.first,
                              let data = try? LocalFileManager.shared.read(from: url),
                              let str = String(data: data, encoding: .utf8) else {
                            errorMessage = "Could not read JSON file."
                            return
                        }
                        inputJSON = str
                        PKHaptics.selection()
                    }

                    Picker("Indentation", selection: $indentSpaces) {
                        Text("2 Spaces").tag(2)
                        Text("4 Spaces").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Sort object keys alphabetically", isOn: $sortKeys)
                        .font(PKFont.body(.subheadline))

                    HStack(spacing: 8) {
                        PrimaryButton(title: "Beautify", icon: "sparkles") {
                            runProcess(minify: false)
                        }
                        .accessibilityIdentifier("json_beautify_button")

                        PrimaryButton(title: "Minify", icon: "arrow.down.right.and.arrow.up.left", variant: .ink) {
                            runProcess(minify: true)
                        }
                        .accessibilityIdentifier("json_minify_button")
                    }

                    Button {
                        validateOnly()
                    } label: {
                        Label("Validate Syntax Only", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                    .accessibilityIdentifier("json_validate_button")
                }
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    title: "Invalid JSON Syntax",
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if let statusBanner, let stats {
                ToolSettingsCard(title: statusBanner, badge: "VALID JSON") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ToolMetricTile(label: "Keys", value: "\(stats.keyCount)", accent: true)
                            ToolMetricTile(label: "Depth", value: "\(stats.depth)")
                            ToolMetricTile(
                                label: "Output",
                                value: ByteCountFormatter.string(fromByteCount: Int64(stats.outputBytes), countStyle: .file)
                            )
                        }

                        if !formattedOutput.isEmpty {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(formattedOutput)
                                    .font(PKFont.mono(.caption, weight: .regular))
                                    .foregroundStyle(PKColors.textPrimary)
                                    .textSelection(.enabled)
                                    .padding(12)
                            }
                            .frame(maxHeight: 260)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PKColors.border, lineWidth: 1))

                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = formattedOutput
                                    copied = true
                                    PKHaptics.success()
                                } label: {
                                    Label(copied ? "Copied" : "Copy Output", systemImage: copied ? "checkmark" : "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))

                                Button {
                                    saveJSONFile()
                                } label: {
                                    Label("Save .json", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PKPillButtonStyle(variant: .primary, compact: true))
                            }
                        }
                    }
                }
            }

            if let exportURL {
                ToolResultCard(
                    title: "JSON Exported",
                    subtitle: "Clean UTF-8 JSON ready to share.",
                    fileURL: exportURL,
                    outputBytes: exportURL.fileSize,
                    exportLabel: "Share .json"
                )
            }
        }
    }

    private var diffSection: some View {
        ToolSettingsCard(
            title: "Compare Two JSON Payloads",
            subtitle: "Formats both payloads and computes line differences"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Left (Original)")
                    .font(PKFont.body(.caption, weight: .bold))
                    .foregroundStyle(PKColors.textSecondary)
                TextEditor(text: $inputJSON)
                    .font(PKFont.mono(.caption, weight: .regular))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .frame(height: 110)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 8))

                Text("Right (Modified)")
                    .font(PKFont.body(.caption, weight: .bold))
                    .foregroundStyle(PKColors.textSecondary)
                TextEditor(text: $compareJSON)
                    .font(PKFont.mono(.caption, weight: .regular))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .frame(height: 110)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 8))

                PrimaryButton(title: "Compare Formatted JSON", icon: "arrow.left.arrow.right") {
                    runDiff()
                }

                if let errorMessage {
                    ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
                }

                if !diffLines.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(diffLines) { line in
                            HStack(spacing: 6) {
                                Text(diffSymbol(line.kind))
                                    .font(PKFont.mono(.caption2, weight: .bold))
                                    .foregroundStyle(diffColor(line.kind))
                                Text(line.text)
                                    .font(PKFont.mono(.caption2, weight: .regular))
                                    .foregroundStyle(diffColor(line.kind))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(diffBg(line.kind), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(6)
                    .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func diffSymbol(_ kind: DiffLine.Kind) -> String {
        switch kind {
        case .add: return "+"
        case .remove: return "-"
        case .context: return " "
        }
    }

    private func diffColor(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .add: return PKColors.success
        case .remove: return PKColors.error
        case .context: return PKColors.textSecondary
        }
    }

    private func diffBg(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .add: return PKColors.successSoft
        case .remove: return PKColors.errorSoft
        case .context: return Color.clear
        }
    }

    private func runProcess(minify: Bool) {
        errorMessage = nil
        copied = false
        do {
            let result = try inputJSON.processJSON(indent: indentSpaces, sortKeys: sortKeys, minify: minify)
            formattedOutput = result.output
            stats = result.stats
            statusBanner = minify ? "JSON Minified" : "JSON Beautified"
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            stats = nil
            statusBanner = nil
            PKHaptics.error()
        }
    }

    private func validateOnly() {
        errorMessage = nil
        copied = false
        do {
            let result = try inputJSON.processJSON(indent: indentSpaces, sortKeys: sortKeys, minify: false)
            formattedOutput = result.output
            stats = result.stats
            statusBanner = "Syntax Valid — 0 Errors"
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            stats = nil
            statusBanner = nil
            PKHaptics.error()
        }
    }

    private func saveJSONFile() {
        guard let data = formattedOutput.data(using: .utf8) else { return }
        let name = "formatted_\(Int(Date().timeIntervalSince1970)).json"
        let dest = LocalFileManager.shared.documentsURL(for: name)
        do {
            try LocalFileManager.shared.write(data: data, to: dest)
            exportURL = dest
            history.record(
                tool: tool,
                inputFileName: "json_payload.json",
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

    private func runDiff() {
        errorMessage = nil
        do {
            let leftFormatted = try inputJSON.processJSON(indent: 2, sortKeys: true, minify: false).output
            let rightFormatted = try compareJSON.processJSON(indent: 2, sortKeys: true, minify: false).output
            diffLines = String.computeLineDiff(left: leftFormatted, right: rightFormatted)
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }
    }
}
