import SwiftUI
import SwiftData

extension View {
    /// Swipe-to-delete on a library row. Starter movements have no action, so
    /// the swipe never appears; custom ones ask before removing.
    ///
    /// Not `role: .destructive` and not a full-swipe: both tell the List to
    /// remove the row itself, and then our confirm-and-delete hits the same
    /// index again — which is the UICollectionView crash "attempt to delete
    /// item N from section which only contains N items".
    @ViewBuilder
    func swipeToDeleteCustomExercise(_ exercise: Exercise, pending: Binding<Exercise?>) -> some View {
        if exercise.isCustom {
            swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    pending.wrappedValue = exercise
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        } else {
            self
        }
    }

    func deleteCustomExerciseDialog(
        pending: Binding<Exercise?>,
        onDeleted: @escaping (UUID) -> Void = { _ in }
    ) -> some View {
        modifier(DeleteCustomExerciseDialog(exercise: pending, onDeleted: onDeleted))
    }
}

private struct DeleteCustomExerciseDialog: ViewModifier {
    @Environment(\.modelContext) private var context
    @Binding var exercise: Exercise?
    var onDeleted: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: isPresented,
                titleVisibility: .visible
            ) {
                Button("Delete Exercise", role: .destructive) {
                    confirmDelete()
                }
            } message: {
                Text("It will be removed from any routines. Logged workouts keep the name.")
            }
    }

    private func confirmDelete() {
        guard let doomed = exercise else { return }
        let id = doomed.id
        // Clear first so the dialog and the still-visible row aren't holding a
        // model we're about to delete, then wait a turn so the List can finish
        // closing the swipe before the data changes.
        exercise = nil
        onDeleted(id)
        Task { @MainActor in
            await Task.yield()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                doomed.deleteFromLibrary(in: context)
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { exercise != nil },
            set: { if !$0 { exercise = nil } }
        )
    }

    private var title: String {
        if let name = exercise?.name, !name.isEmpty {
            "Delete \(name)?"
        } else {
            "Delete this exercise?"
        }
    }
}
