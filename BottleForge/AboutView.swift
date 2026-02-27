//
//  AboutView.swift
//  BottleForge
//
//  Created by Radim Vesely on 15.04.2025.
//

import SwiftUI
import AppKit

struct AboutView: View {
    @State private var isAnimating = false

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            ParticleField(isAnimating: $isAnimating)
                .opacity(0.28)

            VStack(spacing: 0) {
                Spacer(minLength: 18)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.65), .blue.opacity(0.58)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 124, height: 124)
                        .blur(radius: 18)
                        .scaleEffect(isAnimating ? 1.12 : 1.0)

                    Image("about_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.45), radius: 18, x: 0, y: 8)
                        .scaleEffect(isAnimating ? 1.0 : 0.92)
                }
                .padding(.bottom, 26)

                Text("BottleForge")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.74)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("v\(version) (\(build))")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                Text("Wine Environment Manager for macOS")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                Text("Manage CrossOver and CXPatcher bottles, diagnostics, game tweaks, and config generation in one place.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)

                Divider()
                    .padding(.vertical, 26)
                    .padding(.horizontal, 60)

                VStack(spacing: 14) {
                    InfoRow(icon: "person.fill", title: "Created by", value: "Alien4042x")
                    InfoRow(icon: "doc.text.fill", title: "License", value: "MPL 2.0")
                    InfoRow(icon: "shippingbox.fill", title: "Features", value: "Diagnostics • Winetricks • Game Config")
                }
                .padding(.horizontal, 40)

                Spacer()

                HStack(spacing: 14) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/alien4042x/BottleForge") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("GitHub", systemImage: "link")
                            .frame(width: 122)
                    }
                    .buttonStyle(.bordered)

                    Button("License") {
                        if let url = URL(string: "https://www.mozilla.org/MPL/2.0/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 122)

                    Button("Close") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(width: 122)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.bottom, 26)
            }
        }
        .frame(width: 540, height: 640)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28))
        .cornerRadius(10)
    }
}

private struct ParticleField: View {
    @Binding var isAnimating: Bool
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: particle.position.x + (isAnimating ? particle.driftX : -particle.driftX),
                            y: particle.position.y + (isAnimating ? particle.driftY : -particle.driftY)
                        )
                        .blur(radius: particle.blur)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                particles = generateParticles(in: geometry.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) -> [Particle] {
        (0..<32).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...8),
                color: [Color.cyan.opacity(0.6), Color.blue.opacity(0.55), Color.white.opacity(0.35)].randomElement()!,
                blur: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.20...0.60),
                driftX: CGFloat.random(in: -8...8),
                driftY: CGFloat.random(in: -8...8)
            )
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var blur: CGFloat
    var opacity: Double
    var driftX: CGFloat
    var driftY: CGFloat
}

func showCustomAboutWindow() {
    let aboutView = AboutView()
    let hostingController = NSHostingController(rootView: aboutView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = "About BottleForge"
    window.setContentSize(NSSize(width: 540, height: 640))
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)
}
