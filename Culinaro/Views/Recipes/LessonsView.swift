import SwiftUI

struct LessonsView: View {
    @EnvironmentObject private var store: LessonStore
    @State private var editingLesson: Lesson?

    private var lessons: [Lesson] {
        store.lessons.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        List(lessons) { lesson in
            NavigationLink { CookModeView(item: lesson) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title).fontWeight(.semibold)
                        Text("\(lesson.steps.count) Schritte").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if lesson.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.delete(lesson) } label: { Label("Löschen", systemImage: "trash") }
                Button { editingLesson = lesson } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button { withAnimation { store.togglePin(lesson) } } label: {
                    Label(lesson.isPinned ? "Lösen" : "Anpinnen", systemImage: lesson.isPinned ? "pin.slash" : "pin")
                }.tint(.orange)
            }
            .contextMenu {
                Button { editingLesson = lesson } label: { Label("Bearbeiten", systemImage: "pencil") }
                Button { store.togglePin(lesson) } label: { Label(lesson.isPinned ? "Lösen" : "Anpinnen", systemImage: "pin") }
                if let pdf = PDFExporter.export(lesson) {
                    ShareLink(item: pdf, preview: SharePreview(lesson.title, image: Image(systemName: "doc.richtext"))) {
                        Label("Als PDF teilen", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { store.delete(lesson) } label: { Label("Löschen", systemImage: "trash") }
            }
        }
        .overlay { if lessons.isEmpty { ContentUnavailableView("Noch keine Lektionen", systemImage: "graduationcap") } }
        .navigationTitle("Lektionen")
        .navigationSubtitle("\(store.lessons.count) erstellt")
        .refreshable { await store.syncFromCloud() }
        .sheet(item: $editingLesson) { AddItemView(editingLesson: $0) }
    }
}
