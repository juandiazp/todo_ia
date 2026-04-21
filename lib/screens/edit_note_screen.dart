import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditNoteScreen extends StatefulWidget {
  final NoteModel? note;
  const EditNoteScreen({super.key, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final FirebaseService _service = FirebaseService();
  List<Map<String, dynamic>> _checklist = [];
  
  bool _hasChanges = false;
  NoteModel? _currentNote; 

  final AIService _aiService = AIService();
  bool _isProcessingIA = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    if (_currentNote != null) {
      _titleController.text = _currentNote!.title;
      _contentController.text = _currentNote!.content;
      _checklist = List.from(_currentNote!.checklist);

      // Escuchar cambios de Firestore en tiempo real
      FirebaseFirestore.instance
          .collection('notes')
          .doc(_currentNote!.id)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            final updatedNote = NoteModel.fromMap(snapshot.data()!, snapshot.id);
            _currentNote = updatedNote;
            if (_isProcessingIA) {
              _checklist = List.from(updatedNote.checklist);
              _isProcessingIA = false; 
            }
          });
        }
      });
    }
  }



  // --- CLAVE 2: Comparar contra la nota actualizada, no contra la original ---
  void _updateChangeStatus() {
    final bool textChanged = _titleController.text != (_currentNote?.title ?? '') ||
                             _contentController.text != (_currentNote?.content ?? '');
    
    // Si el texto cambió, o si activamos _hasChanges manualmente (checklist)
    if (textChanged != _hasChanges) {
      setState(() => _hasChanges = textChanged);
    }
  }

  void _saveNote() async {
    if (_titleController.text.isEmpty) return;

    // --- CLAVE 3: Determinar si es creación o edición ---
    final isNewNote = _currentNote == null;

    final noteData = NoteModel(
      id: _currentNote?.id ?? '', // Si es nueva, va vacío; si no, lleva su ID
      title: _titleController.text,
      content: _contentController.text,
      checklist: _checklist,
      aiSummary: _currentNote?.aiSummary ?? '',
    );

    if (isNewNote) {
      // Si es nueva, la creamos y regresamos al Home para evitar duplicados
      await _service.addNote(noteData);
      if (mounted) Navigator.pop(context);
    } else {
      // Si ya existe, actualizamos y reseteamos el estado
      await _service.updateNote(noteData);
      setState(() {
        _currentNote = noteData; // Actualizamos nuestra referencia local
        _hasChanges = false;    // La palomita desaparece porque ya no hay cambios
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados'), duration: Duration(milliseconds: 800)),
        );
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar nota?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              // --- CLAVE 4: Cerramos el diálogo y luego la pantalla ---
              if (_currentNote != null) {
                await _service.deleteNote(_currentNote!.id);
                if (mounted) {
                  Navigator.of(context).pop(); // Cierra el diálogo
                  Navigator.of(context).pop(); // Regresa al Home
                }
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Función para Resumir
  void _summarizeNote() async {
    if (_currentNote == null) return;
    setState(() => _isProcessingIA = true);
    
    await _aiService.processNoteIA(
      _currentNote!.id, 
      _contentController.text, 
      'summarize'
    );

    setState(() => _isProcessingIA = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✨ IA trabajando en el resumen...'))
    );
  }

  // Función para Checklist
  void _generateChecklist() async {
    if (_currentNote == null) return;
    setState(() => _isProcessingIA = true);
    
    await _aiService.processNoteIA(
      _currentNote!.id, 
      _contentController.text, 
      'checklist'
    );

    setState(() => _isProcessingIA = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📝 IA generando tu lista de tareas...'))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentNote == null ? 'Nueva Nota' : 'Editar Nota'),
        actions: [
          if (_currentNote == null || _hasChanges)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _saveNote,
            ),
          
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDelete();
            },
            itemBuilder: (context) => [
              if (_currentNote != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar nota'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Título', border: InputBorder.none),
              onChanged: (_) => _updateChangeStatus(), 
            ),
            const Divider(),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Detalles para la IA...', border: InputBorder.none),
              onChanged: (_) => _updateChangeStatus(), 
            ),
            

            const SizedBox(height: 10),
if (_currentNote != null)
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      ElevatedButton.icon(
        onPressed: _isProcessingIA ? null : _summarizeNote,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text("Resumir"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.withOpacity(0.1),
          foregroundColor: Colors.blue,
        ),
      ),
      // ElevatedButton.icon(
      //   onPressed: _isProcessingIA ? null : _generateChecklist,
      //   icon: const Icon(Icons.checklist_rtl_rounded, size: 18),
      //   label: const Text("Hacer Checklist"),
      //   style: ElevatedButton.styleFrom(
      //     backgroundColor: Colors.green.withOpacity(0.1),
      //     foregroundColor: Colors.green,
      //   ),
      // ),
    ],
  ),

if (_isProcessingIA) 
  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator()),

// Mostrar el resumen si existe
if (_currentNote != null && _currentNote!.aiSummary.isNotEmpty)
  Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.amber.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [Icon(Icons.auto_awesome, size: 16, color: Colors.amber), SizedBox(width: 8), Text("Resumen IA", style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 5),
        Text(_currentNote!.aiSummary, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
      ],
    ),
  ),
            


            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Checklist", style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_box_rounded, color: Colors.deepPurple),
                  onPressed: () {
                    setState(() {
                      _checklist.add({"text": "", "checked": false});
                      _hasChanges = true; // Activa la palomita al añadir items
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _checklist.length,
                itemBuilder: (context, i) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: _checklist[i]['checked'],
                      onChanged: (val) {
                        setState(() {
                          _checklist[i]['checked'] = val;
                          _hasChanges = true; // Activa la palomita al marcar tareas
                        });
                      },
                    ),
                    title: TextFormField(
                      initialValue: _checklist[i]['text'],
                      decoration: const InputDecoration(hintText: "Tarea...", border: InputBorder.none),
                      onChanged: (val) {
                        _checklist[i]['text'] = val;
                        // Forzamos el estado de cambios manualmente para el checklist
                        if (!_hasChanges) setState(() => _hasChanges = true);
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _checklist.removeAt(i);
                          _hasChanges = true; // Activa la palomita al borrar items
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}