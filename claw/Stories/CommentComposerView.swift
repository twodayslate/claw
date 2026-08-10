//
//  CommentComposerView.swift
//  claw
//

import SwiftUI

enum CommentComposerMode: Identifiable {
    case new
    case reply(Comment)
    case edit(Comment)

    var id: String {
        switch self {
        case .new: return "new"
        case .reply(let comment): return "reply-\(comment.short_id)"
        case .edit(let comment): return "edit-\(comment.short_id)"
        }
    }

    var title: String {
        switch self {
        case .new: return "Add Comment"
        case .reply(let comment): return "Reply to ~\(comment.commenting_user)"
        case .edit: return "Edit Comment"
        }
    }
}

struct CommentComposerView: View {
    @EnvironmentObject private var session: LobstersSession
    @Environment(\.dismiss) private var dismiss

    let mode: CommentComposerMode
    let storyID: String
    let commentsURL: URL?
    let didSubmit: () async -> Void

    @State private var text = ""
    @State private var isLoadingDraft = false
    @State private var isSubmitting = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Posts through the Lobsters webpage using your third-party Claw login.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isLoadingDraft {
                    ProgressView("Loading comment…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Comment")
                }
            }
            .padding()
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(submitLabel) {
                            submit()
                        }
                        .disabled(isLoadingDraft || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .task {
                await loadDraftIfNeeded()
            }
            .errorAlert(error: $error)
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private var submitLabel: String {
        if case .edit = mode {
            return "Update"
        }
        return "Post"
    }

    private func loadDraftIfNeeded() async {
        guard case .edit(let comment) = mode, text.isEmpty else {
            return
        }
        isLoadingDraft = true
        defer { isLoadingDraft = false }
        do {
            text = try await session.commentDraft(
                commentID: comment.short_id,
                storyID: storyID,
                commentsURL: commentsURL
            )
        } catch {
            self.error = error
        }
    }

    private func submit() {
        guard !isSubmitting else {
            return
        }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                let parentID: String?
                let editingID: String?
                switch mode {
                case .new:
                    parentID = nil
                    editingID = nil
                case .reply(let comment):
                    parentID = comment.short_id
                    editingID = nil
                case .edit(let comment):
                    parentID = nil
                    editingID = comment.short_id
                }

                try await session.submitComment(
                    text,
                    storyID: storyID,
                    parentCommentID: parentID,
                    editingCommentID: editingID,
                    commentsURL: commentsURL
                )
                await didSubmit()
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                self.error = error
            }
        }
    }
}
