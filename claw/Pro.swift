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
    @State var isLoading = false
    @State var error: Error?

    var body: some View {
        GeometryReader { reader in
            ScrollView {
                VStack(spacing: 32) {
                    HStack {
                        Spacer()
                        Grid {
                            row(image: "paintbrush.fill", heading: "Accent Colors", subheading: "Unlock unlimited accent colors and personalize the app with a color picker!")
                            row(image: "list.bullet.indent", heading: "Comment Indent Colors", subheading: "Easily distinguish comment depths with customizable indent colors.")
                            row(image: "cup.and.saucer", heading: "Future Features", subheading: "Support indie development and help prioritize future features and development.")
                        }
                        .frame(maxWidth: max(reader.size.width/2, 400))
                        Spacer()
                    }
                    .font(.headline)
                    HStack {
                        Text("Although this application is open source and you can compile/run it for free, I just wanted to say a big 'thank you' for your awesome support! Your enthusiasm and backing mean the world to me. It's your support that keeps me going and excited about what I do. With your help, I can keep improving and adding cool stuff to make your experience even better. You're a key part of this journey, and I'm thrilled to have you on board. Thanks for being awesome!")
                            .font(.callout)
                            .italic()
                    }
                    Group {
                        Text("Payment will be charged to your Apple ID account at the confirmation of purchase. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase. ") + privacyAndTerms()
                    }
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .tint(Color(UIColor.secondaryLabel).opacity(0.7))
                    .padding()
                }
                .padding()
                .padding(.bottom, buttonSize.height + 32)
                .background {
                    Color(UIColor.systemBackground)
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
            .mask {
                let position = (buttonSize.height + 16) / reader.size.height
                let endPositon = (buttonSize.height + 32) / reader.size.height
                LinearGradient(stops: [.init(color: .clear, location: position), .init(color: .white, location: endPositon)], startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                VStack {
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
                                                Text("2 months free!")
                                                    .minimumScaleFactor(0.8)
                                                    .multilineTextAlignment(.center)
                                                    .padding()
                                                    .background {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .foregroundColor(.yellow)
                                                    }
                                                    .offset(y: -26)
                                                    .foregroundColor(.white)
                                                    .frame(height: 32)
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
                .saveSize(in: $buttonSize)
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
                    Text("Subscribe ").bold() + Text("for \(product.displayPrice)")
                    HStack {
                        Spacer()
                        Text(unit == .month ? "monthly" : "yearly")
                            .font(.footnote)
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
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
        GridRow(alignment: .top) {
            Image(systemName: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 64, maxHeight: 64)
                .foregroundColor(.accentColor)
                .padding(.trailing)
            VStack {
                HStack {
                    Text(heading)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.accentColor)
                        .font(.title)
                    Spacer()
                }
                HStack {
                    Text(subheading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .padding(.bottom)
    }
}

#if DEBUG
struct ProPreview: PreviewProvider {
    static var previews: some View {
        Pro()
    }
}
#endif
