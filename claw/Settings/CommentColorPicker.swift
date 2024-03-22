//
//  CommentColorPicker.swift
//  claw
//
//  Created by Zachary Gorak on 9/10/23.
//

import SwiftUI
import SimpleCommon

struct RedactedCommentColorPickerPreview: View {
    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                HierarchyList(data: [CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder).addChild(CommentStructure(comment: Comment.placeholder))))))))], header: { comment in
                    HStack {
                        Text(comment.comment.commenting_user)
                        Spacer()
                        Text("\(Image(systemName: "arrow.up")) \(comment.comment.score)").foregroundColor(.gray)
                    }
                    .foregroundColor(.gray)
                    .redacted(reason: .placeholder)
                }, rowContent: { comment in
                    Text(comment.comment.comment)
                        .redacted(reason: .placeholder)
                })
                .disabled(true)
            }
        }
    }
}

struct CommentColorPicker: View {
    @EnvironmentObject var settings: Settings

    @State var customColorOne: Color = Color(UIColor.tintColor).opacity(1.0)
    @State var customColorTwo: Color = Color(UIColor.tintColor).opacity(0.9)
    @State var customColorThree: Color = Color(UIColor.tintColor).opacity(0.8)
    @State var customColorFour: Color = Color(UIColor.tintColor).opacity(0.7)
    @State var customColorFive: Color = Color(UIColor.tintColor).opacity(0.6)
    @State var customColorSix: Color = Color(UIColor.tintColor).opacity(0.5)
    @State var customColorSeven: Color = Color(UIColor.tintColor).opacity(0.4)
    @StateObject var storeModel = StoreKitModel.pro

    var body: some View {
        GeometryReader { reader in
            List {
                Section {
                    colorRows1()
                    colorRows2()

                    ZStack(alignment: .leading) {
                        customRow
                            .disabled(!storeModel.owned)
                            .blur(radius: storeModel.owned ? 0.0 : 5.0)
                        if !storeModel.owned {
                            NavigationLink(destination: Pro()) {
                                HStack {
                                    Spacer()
                                    Text("Unlock Custom Colors")
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                        .shadow(color: Color(UIColor.systemBackground), radius: 3.0)
                                    Spacer()
                                }

                            }
                        }
                    }
                } header: {
                    Color.clear.padding(.top, reader.size.height/3)
                }
            }
            .listStyle(GroupedListStyle())
            .overlay(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("Preview")
                        .font(.footnote)
                        .foregroundColor(Color.gray)
                    preview(reader: reader)
                        .background(Color(UIColor.systemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(UIColor.opaqueSeparator), lineWidth: 2)
                        }
                        .mask {
                            RoundedRectangle(cornerRadius: 8)
                        }
                }
                .frame(maxHeight: reader.size.height / 3)
                .padding()
            }
        }
        .onAppear {
            switch settings.commentColorScheme {
            case let .custom(one, two, three, four, five, six, seven):
                customColorOne = Color(one)
                customColorTwo = Color(two)
                customColorThree = Color(three)
                customColorFour = Color(four)
                customColorFive = Color(five)
                customColorSix = Color(six)
                customColorSeven = Color(seven)
            default:
                break
            }
        }
        .onChange(of: customColorOne) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .onChange(of: customColorTwo) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .onChange(of: customColorThree) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .onChange(of: customColorFour) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .onChange(of: customColorFive) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .onChange(of: customColorSix) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .onChange(of: customColorSeven) { _ in
            Task {
                onlySaveIfCustom()
            }
        }
        .navigationTitle("Comment Colors")
    }

    var customRow: some View {
        Button {
            saveCustom()
        } label: {
            HStack {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .opacity(isCustomSelected ? 1.0 : 0)
                VStack(alignment: .leading) {
                    Text("Custom")
                        .font(.callout)
                    HStack {
                        ColorPicker("Custom Color #1", selection: $customColorOne)
                            .labelsHidden()
                        ColorPicker("Custom Color #2", selection: $customColorTwo)
                            .labelsHidden()
                        ColorPicker("Custom Color #3", selection: $customColorThree)
                            .labelsHidden()
                        ColorPicker("Custom Color #4", selection: $customColorFour)
                            .labelsHidden()
                        ColorPicker("Custom Color #5", selection: $customColorFive)
                            .labelsHidden()
                        ColorPicker("Custom Color #6", selection: $customColorSix)
                            .labelsHidden()
                        ColorPicker("Custom Color #7", selection: $customColorSeven)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    func preview(reader: GeometryProxy) -> some View {
        RedactedCommentColorPickerPreview()
    }

    @ViewBuilder
    func colorRows1() -> some View {
        colorSchemeRow(.default)
        colorSchemeRow(.label)
        colorSchemeRow(.red)
        colorSchemeRow(.blue)
        colorSchemeRow(.green)
        colorSchemeRow(.gray)
    }

    @ViewBuilder
    func colorRows2() -> some View {
        colorSchemeRow(.yellow)
        colorSchemeRow(.teal)
        colorSchemeRow(.orange)
        colorSchemeRow(.purple)
        colorSchemeRow(.indigo)
        colorSchemeRow(.mint)
    }

    func onlySaveIfCustom() {
        if isCustomSelected {
            saveCustom()
        }
    }

    func saveCustom() {
        settings.commentColorScheme = .custom(UIColor(customColorOne), UIColor(customColorTwo), UIColor(customColorThree), UIColor(customColorFour), UIColor(customColorFive), UIColor(customColorSix), UIColor(customColorSeven))
        try? settings.managedObjectContext?.save()
    }

    var isCustomSelected: Bool {
        switch settings.commentColorScheme {
        case .custom(_, _, _, _, _, _, _):
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    func colorSchemeRow(_ scheme: Settings.CommentColorScheme) -> some View {
        Button {
            settings.commentColorScheme = scheme
        } label: {
            HStack {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .opacity(settings.commentColorScheme == scheme ? 1.0 : 0)
                VStack(alignment: .leading) {
                    Text(scheme.name)
                        .font(.callout)
                    HStack {
                        colorRow(colors: scheme.colors)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func colorRow(colors: [Color]) -> some View {
        ForEach(Array(zip(colors.indices, colors)), id: \.0) { index, color in
            ColorPicker("Color #\(index)", selection: .constant(color))
                .overlay {
                    Circle().strokeBorder(color, lineWidth: 3)
                }
                .labelsHidden()
                .disabled(true)
        }
    }
}

#if DEBUG
struct CommentColorPickerPreview: PreviewProvider {
    static var previews: some View {
        CommentColorPicker()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
            .environmentObject(ObservableURL())
    }
}
#endif
