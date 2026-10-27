import SwiftUI

struct CameraBackdrop: View {
    let image: PlatformImage

    var body: some View {
        GeometryReader { geometry in
#if os(iOS)
            let content = Image(uiImage: image)
#else
            let content = Image(nsImage: image)
#endif
            content
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width + 80, height: geometry.size.height + 80)
                .blur(radius: 30, opaque: true)
                .overlay(Color.black.opacity(0.35))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
