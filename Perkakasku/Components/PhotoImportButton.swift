import SwiftUI
import PhotosUI
import UIKit

struct PhotoImportButton: View {
    var title: String = "Choose from Photos"
    var hint: String = "Select JPG, PNG, or HEIC images from your Photo Library"
    var maxSelectionCount: Int = 10
    var compact: Bool = false
    var onImport: ([UIImage]) -> Void

    @State private var showingPicker = false
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var isLoading = false

    var body: some View {
        Button {
            PKHaptics.impact(.light)
            showingPicker = true
        } label: {
            if compact {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().tint(PKColors.brand) }
                    else { Image(systemName: "photo.on.rectangle.angled") }
                    Text(isLoading ? "Loading…" : title)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                            .fill(PKColors.surface)
                            .frame(width: 50, height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                                    .strokeBorder(PKColors.border, lineWidth: 1)
                            )
                        if isLoading {
                            ProgressView().tint(PKColors.brand)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(PKColors.brand)
                        }
                    }

                    VStack(spacing: 3) {
                        Text(isLoading ? "Loading Photos…" : title)
                            .font(PKFont.display(.headline, weight: .bold))
                            .foregroundStyle(PKColors.textPrimary)
                        Text(hint)
                            .font(PKFont.body(.caption))
                            .foregroundStyle(PKColors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                        .foregroundStyle(PKColors.borderStrong)
                )
            }
        }
        .buttonStyle(PKPressButtonStyle())
        .disabled(isLoading)
        .accessibilityIdentifier("photoImportButton")
        .photosPicker(
            isPresented: $showingPicker,
            selection: $photoSelections,
            maxSelectionCount: maxSelectionCount,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photoSelections) { _, newItems in
            guard !newItems.isEmpty else { return }
            loadImages(from: newItems)
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        isLoading = true
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run {
                isLoading = false
                photoSelections = []
                if !images.isEmpty {
                    PKHaptics.impact(.light)
                    onImport(images)
                }
            }
        }
    }
}
