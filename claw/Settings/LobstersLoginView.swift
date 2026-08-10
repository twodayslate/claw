//
//  LobstersLoginView.swift
//  claw
//

import SwiftUI
import WebKit

struct LobstersLoginView: View {
    @EnvironmentObject private var session: LobstersSession
    @EnvironmentObject private var storeModel: StoreKitModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BETA")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text("Third-Party Lobsters Login")
                        .font(.headline)
                    Text("Claw is an unofficial third-party app and is not operated by Lobsters. The Lobsters webpage below manages your login. Claw never stores your password; it securely stores the resulting session cookie in Keychain so it can keep you signed in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Divider()
                RetainedLobstersWebView(webView: session.webView)
            }
            .navigationTitle("Lobsters Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard storeModel.owned else {
                    dismiss()
                    return
                }
                session.beginLogin()
            }
            .onChange(of: storeModel.owned) { _, owned in
                if !owned {
                    dismiss()
                }
            }
            .onChange(of: session.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismiss()
                }
            }
            .onDisappear {
                session.endLoginPresentation()
            }
        }
    }
}

struct LobstersStorySubmissionView: View {
    @EnvironmentObject private var session: LobstersSession
    @EnvironmentObject private var storeModel: StoreKitModel
    @Environment(\.dismiss) private var dismiss
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("This is the Lobsters story submission webpage. Your submission is sent directly by Lobsters using Claw's third-party beta login.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                Divider()
                RetainedLobstersWebView(webView: session.webView)
            }
            .navigationTitle("Submit to Lobsters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                guard storeModel.owned else {
                    dismiss()
                    return
                }
                do {
                    try session.beginStorySubmission()
                } catch {
                    self.error = error
                }
            }
            .onChange(of: storeModel.owned) { _, owned in
                if !owned {
                    dismiss()
                }
            }
            .errorAlert(error: $error)
            .onDisappear {
                session.endStorySubmissionPresentation()
            }
        }
    }
}

struct RetainedLobstersWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
