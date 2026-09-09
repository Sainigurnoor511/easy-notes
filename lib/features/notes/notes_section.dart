enum NotesSection { notes, archive, trash, reminders, label }

extension NotesSectionX on NotesSection {
  bool get isTrash => this == NotesSection.trash;
  bool get isArchive => this == NotesSection.archive;
}