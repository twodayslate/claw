import SwiftUI
import SwiftData

import BetterSafariView
import SimpleCommon

struct StoryView: View {
    @EnvironmentObject private var storeModel: StoreKitModel
    @EnvironmentObject private var lobstersSession: LobstersSession
    var short_id: String
    var from_newest: NewestStory?
    var commentsURL: URL?
    @Environment(\.didReselect) var didReselect
    @Environment(\.dismiss) private var dismiss
    @StateObject var story = StoryFetcher()
    
    init(_ short_id: String, commentsURL: URL? = nil) {
        self.short_id = short_id
        self.commentsURL = commentsURL
    }
    
    init(_ story: NewestStory) {
        self.from_newest = story
        self.short_id = story.short_id
        self.commentsURL = URL(string: story.comments_url)
    }
    
    var title: String {
        if let story = self.story.story{
            if story.comment_count == 1 {
                return "1 comment"
            }
            return "\(story.comment_count) comments"
        }
        if let story = from_newest {
            if story.comment_count == 1 {
                return "1 comment"
            }
            return "\(story.comment_count) comments"
        }
        return short_id
    }
    
    // https://stackoverflow.com/questions/58093295/swiftui-avoid-recreating-rerendering-view-in-tabview-with-mkmapviewuiviewrepre
    // this webview is recreated everytime a settings changes and is slow af
        
    @State var activeSheet: ActiveSheet?
    
    @Environment(Settings.self) var settings
    
    @Query(ViewedItem.fetchAllDescriptor) var viewedItems: [ViewedItem]
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var scrollViewContentOffset = CGFloat(0)
    @State private var isVoting = false
    @State private var voteError: Error?
    @State private var activeCommentActionID: String?
    @State private var commentComposer: CommentComposerMode?
    @State private var commentPendingDeletion: Comment?
    
    @EnvironmentObject var urlToOpen: ObservableURL
    @EnvironmentObject var observableSheet: ObservableActiveSheet

    var body: some View {
        ScrollViewReader { scrollReader in
            
            SimpleScrollView(contentOffset: $scrollViewContentOffset) {
                VStack(alignment: .leading, spacing: 0) {
                    if let story = story.story {
                        StoryHeaderView<Story>(
                            story: story,
                            isUpvoted: canVote ? story.user_upvoted : nil,
                            isVoting: isVoting,
                            voteAction: {
                                toggleStoryVote(currentState: story.user_upvoted)
                            }
                        )
                        .id(0)
                        .environmentObject(urlToOpen)
                        .environmentObject(observableSheet)
                    }
                    else if let story = from_newest  {
                        StoryHeaderView<NewestStory>(story: story).id(0).environmentObject(urlToOpen)
                            .environmentObject(observableSheet)
                    } else {
                        StoryHeaderView<NewestStory>(story: NewestStory.placeholder).id(0).redacted(reason: .placeholder).allowsHitTesting(false)
                    }
                    Divider()
                    if canAddComment {
                        Button {
                            commentComposer = .new
                        } label: {
                            Label("Add Comment", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                    if let my_story = story.story {
                        if  my_story.comments.count > 0 {
                            HierarchyList(data: my_story.sorted_comments, header: { comment in
                                HStack(alignment: .center) {
                                    SGNavigationLink(destination: UserView(comment.comment.commenting_user), withChevron: false) {
                                        Text(comment.comment.commenting_user)
                                            .foregroundColor(story.story?.submitter_user == comment.comment.commenting_user && story.story?.user_is_author == true ? .blue : .gray)
                                    }
                                    Spacer()
                                    commentVoteButton(comment.comment)
                                }
                            }, rowContent: { comment in
                                VStack(alignment: .leading, spacing: 8.0) {
                                    let html = HTMLView(html: comment.comment.comment.trimmingCharacters(in: .whitespacesAndNewlines))
                                    HStack {
                                        html
                                        Spacer(minLength: 0) // need this cause there is a Vstack with center alignment somewhere
                                    }
                                    ForEach(html.links, id: \.self) { link in
                                        URLView(link: link).environmentObject(urlToOpen)
                                    }
                                    if canInteract {
                                        commentActions(comment.comment)
                                    }
                                }
                            }).padding([.bottom])
                        } else {
                            HStack {
                                Spacer()
                                Text("No comments").foregroundColor(.gray)
                                Spacer()
                            }.padding()
                        }
                    } else if let story = self.from_newest {
                        if story.comment_count > 0 {
                            LazyVStack(alignment: .leading) {
                                ForEach(1..<(story.comment_count+1)) { count in
                                    VStack(alignment: .leading) {
                                        HStack(alignment: .center) {
                                            SGNavigationLink(destination: UserView(story.submitter_user), withChevron: false) {
                                                Text(String(repeating: " ", count: Int.random(in: 3..<8))).foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Text("\(Image(systemName: "arrow.up")) \(count)").foregroundColor(.gray)
                                        }
                                        Text(String(repeating: " ", count: Int.random(in: 24..<164)))
                                        if count < story.comment_count {
                                            Divider()
                                        }
                                    }.redacted(reason: .placeholder).disabled(true)
                                }
                            }.padding()
                        } else {
                            HStack {
                                Spacer()
                                Text("No comments").foregroundColor(.gray)
                                Spacer()
                            }.padding()
                        }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }.padding()
                    }
                }
            }
            .navigationBarTitle(self.title, displayMode: .inline)
            .onReceive(didReselect) { _ in
                DispatchQueue.main.async {
                    if scrollViewContentOffset > 0 {
                        withAnimation {
                            scrollReader.scrollTo(0)
                        }
                    } else {
                        dismiss()
                    }
                }
            }
            .task {
                if storeModel.owned {
                    lobstersSession.prepareStory(
                        shortID: short_id,
                        commentsURL: commentsURL
                    )
                }
                self.story.short_id = self.short_id
                self.story.pageURL = self.commentsURL
                do {
                    try await self.story.load()
                } catch {
                    print("error", error)
                }
                let contains = viewedItems.contains { element in
                    element.short_id == story.short_id && element.isStory
                }
                if !contains {
                    let newViewedItem = ViewedItem(short_id: story.short_id!, isStory: true, isComment: false)
                    modelContext.insert(newViewedItem)
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await self.story.load()
                    } catch {
                        // no-op
                    }
                }.value
            }
        } // scrollviewreader
        .safariView(item: $urlToOpen.url,
        content:
        { url in
            SafariView(
                url: url,
                configuration: SafariView.Configuration(
                    entersReaderIfAvailable: settings.readerModeEnabled,
                    barCollapsingEnabled: true
                )
            )
            .preferredControlAccentColor(settings.accentColor)
            .dismissButtonStyle(.close)
        })
        .errorAlert(error: $voteError)
        .sheet(item: $commentComposer) { mode in
            CommentComposerView(
                mode: mode,
                storyID: short_id,
                commentsURL: commentsURL,
                didSubmit: {
                    try? await story.load()
                }
            )
            .environmentObject(lobstersSession)
        }
        .confirmationDialog(
            "Delete this comment?",
            isPresented: Binding(
                get: { commentPendingDeletion != nil },
                set: { if !$0 { commentPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Comment", role: .destructive) {
                if let comment = commentPendingDeletion {
                    deleteComment(comment)
                }
            }
            Button("Cancel", role: .cancel) {
                commentPendingDeletion = nil
            }
        } message: {
            Text("This uses the delete control on the Lobsters webpage.")
        }
    }

    private var canVote: Bool {
        storeModel.owned && lobstersSession.isAuthenticated
    }

    private var canInteract: Bool {
        canVote
    }

    private var canAddComment: Bool {
        canInteract && story.story?.can_comment == true
    }

    @ViewBuilder
    private func commentVoteButton(_ comment: Comment) -> some View {
        if canVote && comment.can_vote == true {
            Button {
                toggleCommentVote(comment)
            } label: {
                if activeCommentActionID == comment.short_id {
                    ProgressView()
                } else {
                    Label(
                        comment.displayedScore,
                        systemImage: "arrow.up"
                    )
                    .foregroundStyle(comment.user_upvoted == true ? Color.accentColor : Color.gray)
                }
            }
            .buttonStyle(.plain)
            .disabled(activeCommentActionID != nil || lobstersSession.activeAction != nil)
            .accessibilityLabel(comment.user_upvoted == true ? "Remove comment upvote" : "Upvote comment")
        } else {
            Text("\(Image(systemName: "arrow.up")) \(comment.displayedScore)")
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private func commentActions(_ comment: Comment) -> some View {
        HStack(spacing: 16) {
            if comment.can_reply == true {
                Button("Reply") {
                    commentComposer = .reply(comment)
                }
            }
            if comment.can_edit == true {
                Button("Edit") {
                    commentComposer = .edit(comment)
                }
            }
            if comment.can_delete == true {
                Button("Delete", role: .destructive) {
                    commentPendingDeletion = comment
                }
            }
        }
        .font(.caption)
        .disabled(lobstersSession.activeAction != nil)
    }

    private func toggleStoryVote(currentState: Bool) {
        guard canVote, !isVoting else {
            return
        }

        let desiredState = !currentState
        setOptimisticStoryVote(desiredState)
        isVoting = true
        Task {
            defer {
                isVoting = false
            }
            do {
                try await lobstersSession.setStoryUpvoted(
                    desiredState,
                    shortID: short_id,
                    commentsURL: commentsURL
                )
            } catch is CancellationError {
                setOptimisticStoryVote(currentState)
                return
            } catch {
                setOptimisticStoryVote(currentState)
                voteError = error
            }
        }
    }

    private func toggleCommentVote(_ comment: Comment) {
        guard canVote, comment.can_vote == true, activeCommentActionID == nil else {
            return
        }
        let currentState = comment.user_upvoted == true
        let desiredState = !currentState
        setOptimisticCommentVote(comment.short_id, upvoted: desiredState)
        activeCommentActionID = comment.short_id
        Task {
            defer { activeCommentActionID = nil }
            do {
                try await lobstersSession.setCommentUpvoted(
                    desiredState,
                    commentID: comment.short_id,
                    storyID: short_id,
                    commentsURL: commentsURL
                )
            } catch is CancellationError {
                setOptimisticCommentVote(comment.short_id, upvoted: currentState)
                return
            } catch {
                setOptimisticCommentVote(comment.short_id, upvoted: currentState)
                voteError = error
            }
        }
    }

    private func setOptimisticStoryVote(_ upvoted: Bool) {
        guard var updatedStory = story.story,
              updatedStory.user_upvoted != upvoted else {
            return
        }
        if updatedStory.score_is_hidden != true {
            updatedStory.score += upvoted ? 1 : -1
        }
        updatedStory.user_upvoted = upvoted
        story.story = updatedStory
    }

    private func setOptimisticCommentVote(_ commentID: String, upvoted: Bool) {
        guard var updatedStory = story.story,
              let index = updatedStory.comments.firstIndex(where: {
                  $0.short_id == commentID
              }),
              updatedStory.comments[index].user_upvoted != upvoted else {
            return
        }
        if updatedStory.comments[index].score_is_hidden != true {
            updatedStory.comments[index].score += upvoted ? 1 : -1
        }
        updatedStory.comments[index].user_upvoted = upvoted
        story.story = updatedStory
    }

    private func deleteComment(_ comment: Comment) {
        activeCommentActionID = comment.short_id
        commentPendingDeletion = nil
        Task {
            defer { activeCommentActionID = nil }
            do {
                try await lobstersSession.deleteComment(
                    commentID: comment.short_id,
                    storyID: short_id,
                    commentsURL: commentsURL
                )
                try await story.load()
            } catch is CancellationError {
                return
            } catch {
                voteError = error
            }
        }
    }
}
