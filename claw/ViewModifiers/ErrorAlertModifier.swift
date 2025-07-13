//
//  ErrorAlertModifier.swift
//  claw
//
//  Created by Zachary Gorak on 7/13/25.
//

import SwiftUI

struct ErrorAlertModifier: ViewModifier {

    @Binding var error: Error?

    var titleKey: LocalizedStringKey

    var message: String?

    init(_ titleKey: LocalizedStringKey, error: Binding<Error?>, message: String? = nil) {
        self.titleKey = titleKey
        self._error = error
        self.message = message
    }

    func body(content: Content) -> some View {
        content
            .alert(titleKey, isPresented: .constant(error != nil)) {
                Button("Okay") {
                    error = nil
                }
            } message: {
                if let error = error {
                    let text = Text(error.localizedDescription).fontDesign(.monospaced)
                    if let message, !message.isEmpty {
                        return text + Text("\n\n\(message)")
                    } else {
                        return text
                    }
                } else if let message {
                    return Text(message)
                }
                return Text("")
            }
    }
}

extension View {
    func errorAlert(_ titleKey: LocalizedStringKey = "Error!", error: Binding<Error?>, message: String? = "Please try again. If this issue persists please contact support.") -> some View {
        self.modifier(ErrorAlertModifier(titleKey, error: error, message: message))
    }
}

#Preview {
    @Previewable @State var error: Error? = nil
    @Previewable @State var message: String?

    VStack {
        Button("Show Error") {
            error = URLError(.badServerResponse)
        }
        TextField("Message", text: .init(get: {
            message ?? ""
        }, set: { value in
            if value.isEmpty {
                message = nil
            } else {
                message = value
            }
        }))
        Text("\(message)")
    }
    .errorAlert("Error", error: $error, message: message)
}
