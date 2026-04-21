import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';

class FirebaseService {
  // Referencia a la colección en Firestore
  final CollectionReference _notesCollection = 
      FirebaseFirestore.instance.collection('notes');

  // 1. CREAR una nueva nota
  Future<void> addNote(NoteModel note) async {
    try {
      await _notesCollection.add(note.toMap());
    } catch (e) {
      print("Error al añadir nota: $e");
    }
  }

  // 2. LEER las notas en tiempo real (Stream)
  // Esto es genial porque si n8n actualiza la nota, Flutter lo muestra solo
  Stream<List<NoteModel>> getNotes() {
    return _notesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return NoteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // 3. ACTUALIZAR una nota (útil para el checklist)
  Future<void> updateNote(NoteModel note) async {
    await _notesCollection.doc(note.id).update(note.toMap());
  }

  // 4. ELIMINAR una nota
  Future<void> deleteNote(String id) async {
    await _notesCollection.doc(id).delete();
  }
}