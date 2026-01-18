//
//  WHOISToolView.swift
//  NetMonitor
//
//  WHOIS lookup tool using /usr/bin/whois.
//

import SwiftUI

struct WHOISToolView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var domain = ""
    @State private var isRunning = false
    @State private var output = ""
    @State private var errorMessage: String?

    private let runner = ShellCommandRunner()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            inputArea
            Divider()
            outputArea
            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("WHOIS", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("whois_button_close")
        }
        .padding()
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Domain name (e.g., example.com)", text: $domain)
                .textFieldStyle(.roundedBorder)
                .onSubmit { runWhois() }
                .disabled(isRunning)
                .accessibilityIdentifier("whois_textfield_domain")

            Button("Lookup") {
                runWhois()
            }
            .buttonStyle(.borderedProminent)
            .disabled(domain.isEmpty || isRunning)
            .accessibilityIdentifier("whois_button_lookup")
        }
        .padding()
    }

    // MARK: - Output Area

    private var outputArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if output.isEmpty && errorMessage == nil && !isRunning {
                    Text("Enter a domain name to lookup registration information")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Looking up \(domain)...")
                    .foregroundStyle(.secondary)
            } else if !output.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("WHOIS data retrieved")
                    .foregroundStyle(.secondary)
            } else if errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Lookup failed")
                    .foregroundStyle(.secondary)
            } else {
                Text("Query domain registration information")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !output.isEmpty && !isRunning {
                Button("Clear") {
                    output = ""
                    errorMessage = nil
                }
                .accessibilityIdentifier("whois_button_clear")
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func runWhois() {
        guard !domain.isEmpty else { return }

        isRunning = true
        output = ""
        errorMessage = nil

        Task {
            do {
                let result = try await runner.run(
                    "/usr/bin/whois",
                    arguments: [domain],
                    timeout: 30
                )

                await MainActor.run {
                    if result.stdout.isEmpty {
                        errorMessage = "No WHOIS data found for \(domain)"
                    } else {
                        output = result.stdout
                    }
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
}

#Preview {
    WHOISToolView()
}
