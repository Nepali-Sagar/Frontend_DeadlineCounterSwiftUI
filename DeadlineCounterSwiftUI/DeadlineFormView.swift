import SwiftUI

struct DeadlineFormView: View {
    @Environment(\.dismiss) private var dismiss

    let deadline: Deadline?
    let onSave: (Deadline) async -> Void

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var isUrgent = false
    @State private var category = "Study"
    @State private var isCompleted = false
    @State private var isSaving = false

    private let categories = [
        "Study", "Work", "Personal", "Health", "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Deadline details") {
                    TextField("Title", text: $title)

                    DatePicker(
                        "Due date",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Urgent", isOn: $isUrgent)

                    if deadline != nil {
                        Toggle(
                            "Completed",
                            isOn: $isCompleted
                        )
                    }
                }
            }
            .scrollContentBackground(.automatic)
            .navigationTitle(
                deadline == nil ? "New Deadline" : "Edit Deadline"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveDeadline()
                        }
                    }
                    .disabled(
                        title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty || isSaving
                    )
                }
            }
            .onAppear {
                guard let deadline else { return }

                title = deadline.title
                dueDate = deadline.dueDate
                isUrgent = deadline.isUrgent
                category = deadline.category
                isCompleted = deadline.isCompleted
            }
        }
        .preferredColorScheme(nil)
    }

    private func saveDeadline() async {
        isSaving = true
        defer { isSaving = false }

        let result = Deadline(
            id: deadline?.id ?? UUID().uuidString,
            serverID: deadline?.serverID,
            title: title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            dueDate: dueDate,
            isUrgent: isUrgent,
            category: category,
            isCompleted: isCompleted
        )

        await onSave(result)
        dismiss()
    }
}
