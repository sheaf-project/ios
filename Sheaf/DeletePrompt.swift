import SwiftUI

struct DeletePrompt {
    let title: String
    let message: String
    let action: String
}

extension View {
    func deleteAlert<T>(_ prompt: DeletePrompt, isPresented: Binding<Bool>, presenting item: T?, action: @escaping (T) -> Void) -> some View {
        alert(prompt.title, isPresented: isPresented, presenting: item) { x in
            Button(prompt.action, role: .destructive) { action(x) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(prompt.message)
        }
    }

    func deleteAlert(_ prompt: DeletePrompt, isPresented: Binding<Bool>, action: @escaping () -> Void) -> some View {
        alert(prompt.title, isPresented: isPresented) {
            Button(prompt.action, role: .destructive, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(prompt.message)
        }
    }
}
