import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/firebase_service.dart';
import 'edit_note_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onThemeToggle;

  const HomeScreen({super.key, required this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    final FirebaseService _service = FirebaseService();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Notas con IA'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: onThemeToggle,
            tooltip: 'Cambiar tema',
          ),
        ],
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: _service.getNotes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error al cargar'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            return const Center(child: Text('No hay notas aún. ¡Crea una!'));
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              
              // Widget para deslizar y eliminar
              return Dismissible(
                key: Key(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _service.deleteNote(note.id);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.aiSummary.isNotEmpty 
                              ? '✨ IA: ${note.aiSummary}' 
                              : note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Contador de Checklist
                        if (note.checklist.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "Tareas: ${note.checklist.where((item) => item['checked'] == true).length}/${note.checklist.length}",
                              style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditNoteScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}