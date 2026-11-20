// FILE: CelebrationView.swift
import SwiftUI

struct CelebrationView: View {
    let duration: TimeInterval
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: appeared)

                Text("Session complete")
                    .font(.title2.bold())

                Text("You focused for \(Formatters.long(duration)).")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.top, 6)
            }
            .padding(36)
            .frame(maxWidth: 340)
            .glassEffect(in: .rect(cornerRadius: 32))
            .scaleEffect(appeared ? 1 : 0.75)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    appeared = true
                }
            }
        }
    }
}
