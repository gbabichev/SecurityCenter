import SwiftUI

#if os(macOS)

struct GridSettingsPane: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var editor: GridSettingsEditorRequest?
    @State private var gridToDelete: GridLayout?

    var body: some View {
        VStack(spacing: 0) {
            GridPictureSettings(style: $viewModel.gridPictureStyle)
            Divider()
            GridSettingsHeader(count: viewModel.grids.count) {
                editor = GridSettingsEditorRequest(grid: nil)
            }
            Divider()
            List(viewModel.grids) { grid in
                GridSettingsRow(
                    grid: grid,
                    canDelete: viewModel.grids.count > 1,
                    onEdit: { editor = GridSettingsEditorRequest(grid: grid) },
                    onDelete: { gridToDelete = grid }
                )
            }
            .listStyle(.inset)
        }
        .sheet(item: $editor) { request in
            NavigationStack {
                GridSettingsEditor(viewModel: viewModel, existingGrid: request.grid)
            }
        }
        .alert(item: $gridToDelete) { grid in
            Alert(
                title: Text("Delete Grid?"),
                message: Text("Delete “\(grid.title)” and its camera assignments? Your cameras are kept."),
                primaryButton: .destructive(Text("Delete Grid")) { viewModel.deleteGrid(grid) },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct GridPictureSettings: View {
    @Binding var style: GridPictureStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Picture shape for all grids", selection: $style) {
                ForEach(GridPictureStyle.allCases) { Text($0.title).tag($0) }
            }
            Text(style.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GridSettingsEditorRequest: Identifiable {
    let id = UUID()
    let grid: GridLayout?
}

private struct GridSettingsHeader: View {
    let count: Int
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text("\(count) grids").foregroundStyle(.secondary)
            Spacer()
            Button("Add Grid…", systemImage: "plus", action: onAdd)
        }
        .padding()
    }
}

private struct GridSettingsRow: View {
    let grid: GridLayout
    let canDelete: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(grid.title).fontWeight(.medium)
                    Text("\(grid.columns) columns × \(grid.rows) rows · \(grid.maxItems) slots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onEdit)
            Button("Edit…", systemImage: "pencil", action: onEdit)
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .help("Edit grid")
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .disabled(!canDelete)
                .help(canDelete ? "Delete grid" : "Keep at least one grid. Use Reset Grids in Configuration to start over.")
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Edit Grid…", action: onEdit)
            Button("Delete Grid", role: .destructive, action: onDelete)
                .disabled(!canDelete)
        }
    }
}

#endif

struct GridSettingsEditor: View {
    @ObservedObject var viewModel: AppViewModel
    let existingGrid: GridLayout?
    var onSave: ((GridLayout) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var draft = GridLayout(columns: 2, rows: 2)
    @State private var assignments: [CameraConfig.ID?] = Array(repeating: nil, count: 4)
    @State private var didLoad = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Grid Layout") {
                    TextField("Name", text: $draft.name, prompt: Text("Optional"))
                    Stepper("Columns: \(draft.columns)", value: $draft.columns, in: 1...6)
                    Stepper("Rows: \(draft.rows)", value: $draft.rows, in: 1...6)
                }
                GridAssignmentFields(cameras: viewModel.cameras, columns: draft.columns, assignments: $assignments)
            }
            .formStyle(.grouped)
            Divider()
            GridSettingsEditorActions(isNew: existingGrid == nil, onCancel: { dismiss() }) {
                let savedGrid: GridLayout
                if let existingGrid {
                    savedGrid = viewModel.updateGrid(existingGrid, name: draft.name, columns: draft.columns, rows: draft.rows)
                } else {
                    savedGrid = viewModel.addGrid(name: draft.name, columns: draft.columns, rows: draft.rows)
                }
                let validCameraIDs = Set(viewModel.cameras.map(\.id))
                viewModel.gridAssignments[savedGrid.id] = assignments.map { id in
                    id.flatMap { validCameraIDs.contains($0) ? $0 : nil }
                }
                onSave?(savedGrid)
                dismiss()
            }
        }
        .navigationTitle(existingGrid == nil ? "New Grid" : "Edit Grid")
#if os(macOS)
        .frame(width: 520, height: 480)
#endif
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let existingGrid {
                draft = existingGrid
                assignments = (0..<existingGrid.maxItems).map { viewModel.gridCameraID(layout: existingGrid, index: $0) }
            }
        }
        .onChange(of: draft.maxItems) { _, count in
            assignments = Array(assignments.prefix(count))
            if assignments.count < count {
                assignments.append(contentsOf: Array(repeating: nil, count: count - assignments.count))
            }
        }
    }
}

private struct GridAssignmentFields: View {
    let cameras: [CameraConfig]
    let columns: Int
    @Binding var assignments: [CameraConfig.ID?]

    var body: some View {
        Section {
            // A slot's position is its identity, even when its assigned camera changes.
            ForEach(assignments.indices, id: \.self) { index in
                Picker("Row \(index / columns + 1), column \(index % columns + 1)", selection: $assignments[index]) {
                    Text("Empty").tag(Optional<CameraConfig.ID>.none)
                    ForEach(cameras) { camera in
                        Text(camera.displayName).tag(Optional(camera.id))
                    }
                }
            }
        } header: {
            Text("Camera Assignments")
        } footer: {
            Text("Slots run left to right, then top to bottom. Making the grid smaller removes extra slots when you save.")
        }
    }
}

private struct GridSettingsEditorActions: View {
    let isNew: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button(isNew ? "Create" : "Save", action: onSave).keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}
