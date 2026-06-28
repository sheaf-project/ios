import SwiftUI
import UIKit
import ImageIO

enum ImageCropShape {
    case circle
    case roundedRect(cornerRadius: CGFloat)
}

/// Generalised image cropper used by avatar and banner uploads.
///
/// Mirrors the Android `ImageCropDialog`: pinch zoom (allowed below cover so
/// the whole image can be letterboxed with transparent margins), drag pan,
/// rotation via two-finger twist / quarter-turn buttons / fine slider, and a
/// PNG export at 1024px on the longest edge so on-screen framing is exactly
/// what gets saved.
struct ImageCropperView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceImage: UIImage
    let aspectRatio: CGFloat
    let cropShape: ImageCropShape
    let title: String
    let onConfirm: (Data) -> Void

    private let outputLongestPx: CGFloat = 1024

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero

    // Last on-screen crop position, used by export so the saved image
    // matches what the user framed. Updated whenever the viewport changes.
    @State private var cropBounds: CGRect = .zero
    @State private var lastViewport: CGSize = .zero
    @State private var didInitialFit = false

    init(sourceImage: UIImage,
         aspectRatio: CGFloat,
         cropShape: ImageCropShape,
         title: String,
         onConfirm: @escaping (Data) -> Void) {
        self.sourceImage = sourceImage
        self.aspectRatio = aspectRatio
        self.cropShape = cropShape
        self.title = title
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    cropArea(viewport: proxy.size)
                }
                controlsBar
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        if let data = exportPNG() {
                            onConfirm(data)
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: Crop area

    @ViewBuilder
    private func cropArea(viewport: CGSize) -> some View {
        let crop = cropRect(in: viewport)
        let rendered = renderedSize(in: viewport)

        ZStack {
            Color.black

            // Image: explicit frame from our own fit calculation, centred in
            // the ZStack and then offset/rotated/scaled by the user.
            Image(uiImage: sourceImage)
                .resizable()
                .frame(width: rendered.width, height: rendered.height)
                .scaleEffect(scale)
                .rotationEffect(rotation)
                .offset(offset)

            cropMask(viewport: viewport, crop: crop)
                .allowsHitTesting(false)
            cropOutline(crop: crop)
                .allowsHitTesting(false)
        }
        .frame(width: viewport.width, height: viewport.height)
        .contentShape(Rectangle())
        .gesture(combinedGesture)
        .onAppear {
            updateForViewport(viewport)
        }
        .onChange(of: viewport.width) { _, _ in updateForViewport(viewport) }
        .onChange(of: viewport.height) { _, _ in updateForViewport(viewport) }
    }

    private func updateForViewport(_ viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        lastViewport = viewport
        let crop = cropRect(in: viewport)
        cropBounds = crop
        if !didInitialFit {
            fitToCover(viewport: viewport, crop: crop)
            didInitialFit = true
        }
    }

    // MARK: Controls

    private var controlsBar: some View {
        HStack(spacing: 16) {
            Button {
                rotation = snappedQuarter(rotation, direction: -1)
                lastRotation = rotation
            } label: {
                Image(systemName: "rotate.left")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Slider(
                value: Binding(
                    get: { rotation.degrees },
                    set: {
                        rotation = .degrees($0)
                        lastRotation = rotation
                    }
                ),
                in: -180...180
            )
            .tint(.white)

            Button {
                rotation = snappedQuarter(rotation, direction: 1)
                lastRotation = rotation
            } label: {
                Image(systemName: "rotate.right")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    private func cropMask(viewport: CGSize, crop: CGRect) -> some View {
        let path = Path { p in
            p.addRect(CGRect(origin: .zero, size: viewport))
            switch cropShape {
            case .circle:
                p.addEllipse(in: crop)
            case .roundedRect(let r):
                p.addRoundedRect(in: crop, cornerSize: CGSize(width: r, height: r))
            }
        }
        return path
            .fill(style: FillStyle(eoFill: true, antialiased: true))
            .foregroundColor(.black.opacity(0.6))
    }

    @ViewBuilder
    private func cropOutline(crop: CGRect) -> some View {
        switch cropShape {
        case .circle:
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: crop.width, height: crop.height)
                .position(x: crop.midX, y: crop.midY)
        case .roundedRect(let r):
            RoundedRectangle(cornerRadius: r)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: crop.width, height: crop.height)
                .position(x: crop.midX, y: crop.midY)
        }
    }

    // MARK: Gestures

    private var combinedGesture: some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }

        let magnify = MagnificationGesture()
            .onChanged { value in
                let proposed = lastScale * value
                scale = clampScale(proposed)
            }
            .onEnded { _ in
                lastScale = scale
            }

        let rotate = RotationGesture()
            .onChanged { value in
                rotation = lastRotation + value
            }
            .onEnded { _ in
                lastRotation = rotation
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }

    // MARK: Geometry

    private func cropRect(in viewport: CGSize) -> CGRect {
        guard viewport.width > 0, viewport.height > 0 else { return .zero }
        let maxW = viewport.width * 0.92
        let maxH = viewport.height * 0.70
        var w = maxW
        var h = w / aspectRatio
        if h > maxH {
            h = maxH
            w = h * aspectRatio
        }
        let x = (viewport.width - w) / 2
        let y = (viewport.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// scaledToFit dimensions of the source image inside the viewport, used
    /// for both the on-screen Image frame and the export transform so both
    /// stay in sync.
    private func renderedSize(in viewport: CGSize) -> CGSize {
        let imgW = sourceImage.size.width
        let imgH = sourceImage.size.height
        guard imgW > 0, imgH > 0, viewport.width > 0, viewport.height > 0 else {
            return .zero
        }
        let fit = min(viewport.width / imgW, viewport.height / imgH)
        return CGSize(width: imgW * fit, height: imgH * fit)
    }

    private func fitToCover(viewport: CGSize, crop: CGRect) {
        let rendered = renderedSize(in: viewport)
        guard rendered.width > 0, rendered.height > 0 else { return }
        let coverScale = max(crop.width / rendered.width, crop.height / rendered.height)
        scale = coverScale
        lastScale = coverScale
        offset = .zero
        lastOffset = .zero
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        // We allow shrinking below cover so the user can letterbox; clamp to a
        // floor and ceiling that still keep the image usable.
        let minScale: CGFloat = 0.2
        let maxScale: CGFloat = 8
        return max(minScale, min(maxScale, value))
    }

    private func snappedQuarter(_ current: Angle, direction: Int) -> Angle {
        // Match the web/Android nudge so landing on a multiple still advances.
        let nudge = Double(direction) * 1.0
        let target = current.degrees + Double(direction) * 90 + nudge
        let snapped = (target / 90.0).rounded() * 90.0
        let normalised = snapped.truncatingRemainder(dividingBy: 360)
        return .degrees(normalised > 180 ? normalised - 360 : (normalised < -180 ? normalised + 360 : normalised))
    }

    // MARK: Export

    /// Renders the cropped image at 1024px on the longest edge using a single
    /// forward CGAffineTransform that mirrors the on-screen framing.
    private func exportPNG() -> Data? {
        let viewport = lastViewport
        let crop = cropBounds
        guard viewport.width > 0, viewport.height > 0,
              crop.width > 0, crop.height > 0,
              sourceImage.cgImage != nil else { return nil }

        let rendered = renderedSize(in: viewport)
        guard rendered.width > 0, rendered.height > 0 else { return nil }

        // Compute output dimensions sized to the crop aspect, capped at 1024.
        let cropAR = crop.width / crop.height
        let outW: CGFloat
        let outH: CGFloat
        if cropAR >= 1 {
            outW = outputLongestPx
            outH = outputLongestPx / cropAR
        } else {
            outH = outputLongestPx
            outW = outputLongestPx * cropAR
        }
        let outputSize = CGSize(width: outW.rounded(), height: outH.rounded())

        UIGraphicsBeginImageContextWithOptions(outputSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Map crop rectangle in viewport space onto the output canvas:
        //   1. scaleBy(scaleToOutput): viewport pixels -> output pixels
        //   2. translateBy(-crop.origin): crop's top-left lands at canvas (0,0)
        //   3. translateBy(imageCenter): origin moves to the on-screen image
        //      centre (viewport centre + user offset)
        //   4. rotate(rotation) + scaleBy(scale): user transforms
        //   5. draw image centred on origin at its scaledToFit rendered size
        let scaleToOutput = outputSize.width / crop.width
        ctx.scaleBy(x: scaleToOutput, y: scaleToOutput)
        ctx.translateBy(x: -crop.origin.x, y: -crop.origin.y)
        ctx.translateBy(
            x: viewport.width / 2 + offset.width,
            y: viewport.height / 2 + offset.height
        )
        ctx.scaleBy(x: scale, y: scale)
        ctx.rotate(by: CGFloat(rotation.radians))

        UIGraphicsPushContext(ctx)
        sourceImage.draw(in: CGRect(
            x: -rendered.width / 2,
            y: -rendered.height / 2,
            width: rendered.width,
            height: rendered.height
        ))
        UIGraphicsPopContext()

        guard let img = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return img.pngData()
    }
}

// MARK: - Helpers

extension UIImage {
    /// Decodes image data, honouring EXIF orientation, and downsamples to a
    /// reasonable working size for the cropper.
    static func decodeForCrop(data: Data, maxDimension: CGFloat = 2048) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }
}
