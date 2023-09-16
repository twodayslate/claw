//
//  Pro.swift
//  redgifs
//
//  Created by Zachary Gorak on 6/18/23.
//

import SwiftUI
import StoreKit

struct Pro: View {
    @StateObject var model = StoreKitModel.pro
    @Environment(\.dismiss) var dismiss

    @State var buttonSize: CGSize = .zero
    @State var pickerSize: CGSize = .zero
    @State var isLoading = false
    @State var error: Error?

    var iconSize: CGFloat = 48.0

    var body: some View {
        GeometryReader { reader in
            let maxWidth = max(reader.size.width/2, 400)
            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 32) {
                        HStack {
                            Spacer()
                            Grid {
                                row(heading: "Accent Colors", subheading: "Unlock unlimited accent colors and personalize the app with a color picker!") {
                                    ColorPicker("Accent Color", selection: .constant(Color(UIColor.tintColor)))
                                        .labelsHidden()
                                        .saveSize(in: $pickerSize)
                                        .scaleEffect(iconSize/pickerSize.width)
                                        .disabled(true)
                                        .frame(maxWidth: iconSize, maxHeight: iconSize)
                                        .clipped()
                                }
                                indentColorRow
                                row(image: "cup.and.saucer", heading: "Future Features", subheading: "Support indie development and help prioritize future features and development.")
                            }
                            Spacer()
                        }
                        .font(.headline)
                        developerMessage
                        reviews
                        Group {
                            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase. ") + privacyAndTerms()
                        }
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .tint(Color(UIColor.secondaryLabel).opacity(0.7))
                        subscribeBar
                            .hidden()
                    }
                    .padding()
                    .background {
                        Color(UIColor.systemBackground)
                    }
                    .frame(maxWidth: maxWidth)
                    Spacer(minLength: 0)
                }
            }
            .background(alignment: .top) {
                VStack {
                    Image("me")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128)
                    HStack {
                        Text("Thank you so much for the support!")
                            .italic()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer()
                    Divider()
                        .ignoresSafeArea()
                    subscribeBar
                    .saveSize(in: $buttonSize)
                }
            }
        }
        .navigationTitle("Support to Unlock")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        error = nil
                        try await model.restore()
                    }
                } label: {
                    Text("Restore")
                }
            }
        }
        .alert("Failed to purchase!", isPresented: .init(get: { error != nil }, set: { _ in error = nil }), actions: {}, message: {
            if let error {
                Text(error.localizedDescription)
            }
        })
    }

    @ViewBuilder
    var reviews: some View {
        let titles = [
            "Excellent!",
            "Beautiful!",
            "Amazing!"
        ].shuffled()

        let authors = [
            "George",
            "Jason",
            "Susan"
        ].shuffled()

        let texts = [
            "This app makes lobsters a joy to use on my phone. It's super smooth. Love dark mode.",
            "So much better than hacker news - glad there is finally a native application.",
            "This community is amazing. Full of great people and excellent content."
        ].shuffled()

        ZStack {
            // left
            review(title: titles[0], author: authors[0], text: texts[0])
                .offset(x: -100)
                .scaleEffect(0.9)
                .opacity(0.7)	
                .blur(radius: 2)
            // right
            review(title: titles[1], author: authors[1], text: texts[1])
                .offset(x: 100)
                .scaleEffect(0.9)
                .opacity(0.8)
                .blur(radius: 2)

            // top
            review(title: titles[2], author: authors[2], text: texts[2])

        }
    }

    func review(title: String, author: String, text: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                ForEach(Array((0..<5)), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                Spacer(minLength: 0)
            }
            Text(title)
                .font(.subheadline)
                .bold()
            Text(text)
                .font(.footnote)
            HStack {
                Spacer(minLength: 0)
                Text("- \(author)")
                    .font(.caption2)
                    .italic()
                    .opacity(0.8)
            }
        }
        .padding()
        .frame(width: 250, height: 130)
        .background(.regularMaterial)
        .mask {
            RoundedRectangle(cornerRadius: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(UIColor.opaqueSeparator), lineWidth: 1)
        }
    }

    var developerMessage: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "message")
                Text("Message from the Developer")
            }
            .padding(.bottom, 2)
            Text("Although this application is open source and you can compile/run it for free, I just wanted to say a big 'thank you' for your awesome support! Your enthusiasm and backing mean the world to me. It's your support that keeps me going and excited about what I do. With your help, I can keep improving and adding cool stuff to make your experience even better. You're a key part of this journey, and I'm thrilled to have you on board. Thanks for being awesome!")
                .font(.subheadline)
                .opacity(0.9)
                .italic()
                .padding(.leading, 12)
                .background(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(.accentColor.opacity(0.6))
                        .frame(width: 4)
                }
        }
    }

    var subscribeBar: some View {
        VStack {
            HStack {
                Text("Subscribe")
                    .font(.title3)
                    .bold()
                    .foregroundColor(Color(UIColor.label).opacity(0.8))
                Spacer()
            }
            .padding(.leading)
            HStack {
                Spacer()
                Grid {
                    GridRow {
                        subscribeButton(.month)
                            .saveSize(in: $buttonSize)
                        VStack {
                            subscribeButton(.year)
                                .overlay(alignment: .top) {
                                    HStack {
                                        Spacer()
                                        Text("Best Value!")
                                            .minimumScaleFactor(0.7)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                            .background {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .foregroundColor(.yellow)
                                            }
                                            .offset(y: -26)
                                            .foregroundColor(Color.black.opacity(0.8))
                                            .frame(height: iconSize/2)

                                        Spacer()
                                    }
                                }
                        }
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    func privacyAndTerms() -> Text {
        Text("By using our services you agree to and have read our ") +
        Text("[Privacy Policy](https://zac.gorak.us/ios/privacy)")
            .underline() +
        Text(" and ") +
        Text("[Terms of Use](https://zac.gorak.us/ios/terms)")
            .underline() +
        Text(".")
    }

    @ViewBuilder
    func subscribeButton(_ unit: Product.SubscriptionPeriod.Unit) -> some View {
        if let product = model.products?.first(where: { $0.subscription?.subscriptionPeriod.unit == unit }) {
            Button {
                Task {
                    error = nil
                    isLoading = true
                    do {
                        let transaction = try await model.purchase(product)
                        if transaction == nil {
                            self.error = SKError(.unknown)
                        }
                    } catch {
                        self.error = error
                    }
                    isLoading = false
                    if model.owned {
                        dismiss()
                    }
                }
            } label: {
                VStack {
                    Text("\(product.displayPrice)")
                        .font(.headline)
                    HStack {
                        Spacer()
                        Text(unit == .month ? "monthly" : "yearly")
                            .italic()
                            .font(.caption)
                            .opacity(unit == .month ? 0.7 : 0.9)
                        Spacer()
                    }
                }
                .foregroundColor(unit == .month ? Color.accentColor : .white)
                .padding()
                .overlay {
                    if unit == .month {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .background(unit == .month ? Color.clear : Color.accentColor)
                .cornerRadius(8)
            }
            .disabled(isLoading)
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(isLoading ? 1.0 : 0.0)
            }
        } else {
            VStack {
                Text("Subscribe for -")
                HStack {
                    Text("yearly")
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(8)
            .redacted(reason: .placeholder)
        }
    }

    func row(image: String, heading: String, subheading: String) -> some View {
        row(heading: heading, subheading: subheading) {
            rowImage(systemName: image)
        }
    }

    func row(heading: String, subheading: String, @ViewBuilder _ builder: () -> some View) -> some View{
        GridRow(alignment: .top) {
            builder()
                .padding(.trailing)
            VStack {
                HStack {
                    Text(heading)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.accentColor)
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                HStack {
                    Text(subheading)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .padding(.bottom)
    }

    func rowImage(systemName: String) -> some View{
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: iconSize, maxHeight: iconSize)
            .foregroundColor(.accentColor)
    }

    var indentColorRow: some View {
        row(heading: "Comment Indent Colors", subheading: "Easily distinguish comment depths with customizable indent colors.") {
            rowImage(systemName: "list.bullet.indent")
                .opacity(0.0)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(UIColor.opaqueSeparator), lineWidth: 2)
                        .overlay {
                            HStack(spacing: 4) {
                                let colors = Settings.CommentColorScheme.default.colors
                                ForEach(Array(zip(colors.indices, colors)), id: \.0) { index, color in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color)
                                        .frame(width: 2)
                                        .padding(.top, CGFloat(index * 2))
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(width: iconSize - 12, height: iconSize - 12)
                            .clipped()
                            //.offset(x: 4)
                        }
                        .background(.regularMaterial)
                    .mask {
                        RoundedRectangle(cornerRadius: 8)
                    }
                    //.padding()
                    //.clipped()
                    //padding(2)
                    .frame(maxWidth: iconSize)

                    .mask {
                        RoundedRectangle(cornerRadius: 8)
                    }
                    .overlay {

                    }
                }
        }
    }
}

#if DEBUG
struct ProPreview: PreviewProvider {
    static var previews: some View {
        Pro()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
            .environmentObject(ObservableURL())
    }
}
#endif
