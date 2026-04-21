class NoteModel {
  String id;
  String title;
  String content;
  List<Map<String, dynamic>> checklist;
  String aiSummary;

  NoteModel({
    this.id = '',
    required this.title,
    required this.content,
    required this.checklist,
    this.aiSummary = '',
  });

  // Convertir de Firestore (Map) a objeto de Dart
  factory NoteModel.fromMap(Map<String, dynamic> data, String id) {
    return NoteModel(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      checklist: List<Map<String, dynamic>>.from(data['checklist'] ?? []),
      aiSummary: data['ai_summary'] ?? '',
    );
  }

  // Convertir de objeto de Dart a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'checklist': checklist,
      'ai_summary': aiSummary,
    };
  }
}