//
//  AboutView.swift
//  Security Center
//
//  Created by Codex on 4/27/26.
//

#if os(macOS)
import SwiftUI

struct LiveAppIconView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var refreshID = UUID()

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .id(refreshID)
            .frame(width: 72, height: 72)
            .onChange(of: colorScheme) { _, _ in
                DispatchQueue.main.async {
                    refreshID = UUID()
                }
            }
    }
}

struct AboutView: View {
    private let developerWebsiteURL = URL(string: "https://georgebabichev.com")
    private let vlcKitSPMURL = URL(string: "https://github.com/tylerjonesio/vlckit-spm")
    private let vlcKitURL = URL(string: "https://github.com/videolan/vlckit")
    private let lgplURL = URL(string: "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html")

    var body: some View {
        VStack(spacing: 18) {
            LiveAppIconView()

            VStack(spacing: 4) {
                Text(appName)
                    .font(.title.weight(.semibold))
                Text("Local camera monitoring for macOS and iOS")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                AboutRow(label: "Version", value: appVersion)
                AboutRow(label: "Build", value: appBuild)
                AboutRow(label: "Developer", value: "George Babichev")
                AboutRow(label: "Copyright", value: "© \(Calendar.current.component(.year, from: Date())) George Babichev")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let devPhoto = NSImage(named: "gbabichev") {
                HStack(spacing: 12) {
                    Image(nsImage: devPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .offset(y: 6)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("George Babichev")
                            .font(.headline)
                        if let developerWebsiteURL {
                            Link("georgebabichev.com", destination: developerWebsiteURL)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Text("Security Center is an open source app for viewing the cameras and streams you add.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Open Source Licenses")
                    .font(.headline)

                Text("This app uses VLCKit through the VLCKitSPM package. VLCKit and libVLC are licensed under the GNU Lesser General Public License 2.1.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    AboutLinkRow(title: "VLCKitSPM Package", url: vlcKitSPMURL)
                    AboutLinkRow(title: "VLCKit Source", url: vlcKitURL)
                    AboutLinkRow(title: "LGPL-2.1 License", url: lgplURL)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(width: 420)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ??
        "Security Center"
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

private struct AboutLinkRow: View {
    let title: String
    let url: URL?

    var body: some View {
        if let url {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Text(title)
                    Image(systemName: "arrow.up.forward")
                        .font(.caption.weight(.semibold))
                }
            }
            .font(.subheadline)
        }
    }
}

struct AboutOverlayView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack {
                ZStack(alignment: .topTrailing) {
                    AboutView()
                        .frame(maxWidth: 420)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(NSColor.windowBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 12)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .accessibilityLabel(Text("Close About"))
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .transition(.opacity)
        .onExitCommand {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isPresented = false
        }
    }
}
#endif
