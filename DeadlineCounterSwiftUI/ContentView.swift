import SwiftUI

struct ContentView: View {
    @StateObject private var api = DeadlineAPI()
    
    @StateObject private var connectivity = ConnectivityMonitor()
    @Environment(\.scenePhase) private var scenePhase

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingCompleted = false
    @State private var showingForm = false
    @State private var editingDeadline: Deadline?
    @State private var showingErrorAlert = false

    private let categories = [
        "All", "Study", "Work", "Personal", "Health", "Other"
    ]

    private var filteredDeadlines: [Deadline] {
        api.deadlines.filter { deadline in
            let matchesSearch =
                searchText.isEmpty ||
                deadline.title.localizedCaseInsensitiveContains(
                    searchText
                )

            let matchesCategory =
                selectedCategory == "All" ||
                deadline.category == selectedCategory

            let matchesStatus =
                deadline.isCompleted == showingCompleted

            return matchesSearch &&
                matchesCategory &&
                matchesStatus
        }
    }

    private var activeCount: Int {
        api.deadlines.filter { !$0.isCompleted }.count
    }

    private var completedCount: Int {
        api.deadlines.filter { $0.isCompleted }.count
    }

    private var nextDeadline: Deadline? {
        api.deadlines
            .filter { !$0.isCompleted && $0.dueDate >= Date() }
            .min { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    summaryCards

                    if let next = nextDeadline {
                        nextDeadlineCard(next)
                    }

                    deadlineSection
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Deadline Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingDeadline = nil
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Add deadline")
                }
            }
            .task {
                await api.loadAllData()
            }
            .refreshable {
                await api.loadAllData()
            }
            .onChange(of: connectivity.isConnected) { wasConnected, isConnected in
                guard isConnected && !wasConnected else { return }

                Task {
                    await api.loadAllData()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                guard newPhase == .active && oldPhase != .active else { return }

                Task {
                    await api.loadAllData()
                }
            }
            .sheet(isPresented: $showingForm) {
                DeadlineFormView(
                    deadline: editingDeadline,
                    onSave: { deadline in
                        if editingDeadline != nil {
                            await api.updateDeadline(deadline)
                        } else {
                            await api.addDeadline(deadline)
                        }
                    }
                )
            }
            .onChange(of: api.errorMessage) { _, message in
                showingErrorAlert = message != nil
            }
            .onChange(of: showingErrorAlert) { _, isPresented in
                if !isPresented && api.errorMessage != nil {
                    Task { @MainActor in
                        api.errorMessage = nil
                    }
                }
            }
            .alert(
                "Something went wrong",
                isPresented: $showingErrorAlert,
                presenting: api.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stay on track")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text("Keep every important date under control.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(
                api.syncStatus,
                systemImage: api.isSyncing ? "arrow.triangle.2.circlepath" :
                    (api.syncStatus == "All changes synced" ? "checkmark.icloud" : "icloud")
            )
            .font(.caption)
            .foregroundStyle(api.syncStatus == "All changes synced" ? Color.secondary : Color.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Active",
                count: activeCount,
                icon: "calendar",
                tint: .blue
            )

            summaryCard(
                title: "Completed",
                count: completedCount,
                icon: "checkmark.circle.fill",
                tint: .green
            )
        }
    }

    private func summaryCard(
        title: String,
        count: Int,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)

            Text("\(count)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func nextDeadlineCard(
        _ deadline: Deadline
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("NEXT DEADLINE", systemImage: "clock")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(deadline.title)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(deadline.countdownText)
                .font(.headline)
                .foregroundStyle(
                    deadline.isOverdue ? .red : .blue
                )

            Text(
                deadline.dueDate.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    Color.blue.opacity(0.25),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your deadlines")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Spacer()

                Button(showingCompleted ? "Show active" : "Show completed") {
                    showingCompleted.toggle()
                }
                .font(.caption.weight(.semibold))
            }

            TextField("Search deadlines", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category
                                        ? Color.accentColor
                                        : Color(uiColor: .secondarySystemGroupedBackground)
                                )
                                .foregroundStyle(
                                    selectedCategory == category
                                        ? Color.white
                                        : Color.primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if api.isLoading && api.deadlines.isEmpty {
                ProgressView("Loading deadlines...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if filteredDeadlines.isEmpty {
                ContentUnavailableView(
                    "No deadlines found",
                    systemImage: "calendar",
                    description: Text(
                        showingCompleted
                            ? "Completed deadlines will appear here."
                            : "Add a deadline to get started."
                    )
                )
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredDeadlines) { deadline in
                        deadlineRow(deadline)
                    }
                }
            }
        }
    }

    private func deadlineRow(
        _ deadline: Deadline
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(
                    systemName: deadline.isCompleted
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title2)
                .foregroundStyle(
                    deadline.isCompleted ? .green : .secondary
                )
                .onTapGesture {
                    Task {
                        var updated = deadline
                        updated.isCompleted.toggle()
                        await api.updateDeadline(updated)
                    }
                }
                .accessibilityLabel(
                    deadline.isCompleted
                        ? "Mark as incomplete"
                        : "Mark as completed"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(deadline.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .strikethrough(deadline.isCompleted)

                    Text(deadline.category)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(
                        deadline.dueDate.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if deadline.isUrgent && !deadline.isCompleted {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Urgent")
                }
            }

            HStack {
                Label(
                    deadline.countdownText,
                    systemImage: "clock"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    deadline.isOverdue ? .red :
                        (deadline.isCompleted ? .green : .blue)
                )

                Spacer()

                Button {
                    editingDeadline = deadline
                    showingForm = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit deadline")

                Button(role: .destructive) {
                    Task {
                        await api.deleteDeadline(deadline)
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete deadline")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
