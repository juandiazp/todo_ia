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

      // Listener en tiempo real mejorado
      FirebaseFirestore.instance
          .collection('notes')
          .doc(_currentNote!.id)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            final updatedNote = NoteModel.fromMap(snapshot.data()!, snapshot.id);
            _currentNote = updatedNote;
            
            // Actualizamos la checklist local solo si recibimos datos nuevos de la IA
            // o si no estamos editando manualmente en este momento
            if (_isProcessingIA) {
              _checklist = List.from(updatedNote.checklist);
              _isProcessingIA = false; 
            }
          });
        }
      });
    }
  }

  void _updateChangeStatus() {
    final bool textChanged = _titleController.text != (_currentNote?.title ?? '') ||
                             _contentController.text != (_currentNote?.content ?? '');
    if (textChanged != _hasChanges) {
      setState(() => _hasChanges = textChanged);
    }
  }

  void _saveNote() async {
    if (_titleController.text.isEmpty) return;
    final isNewNote = _currentNote == null;
    final noteData = NoteModel(
      id: _currentNote?.id ?? '',
      title: _titleController.text,
      content: _contentController.text,
      checklist: _checklist,
      aiSummary: _currentNote?.aiSummary ?? '',
    );

    if (isNewNote) {
      await _service.addNote(noteData);
      if (mounted) Navigator.pop(context);
    } else {
      await _service.updateNote(noteData);
      setState(() {
        _currentNote = noteData;
        _hasChanges = false;
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
              if (_currentNote != null) {
                await _service.deleteNote(_currentNote!.id);
                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _summarizeNote() async {
    if (_currentNote == null) return;
    setState(() => _isProcessingIA = true);
    
    // Al ser un proceso asíncrono en n8n, el listener de Firestore 
    // se encargará de apagar el _isProcessingIA cuando detecte el cambio.
    await _aiService.processNoteIA(_currentNote!.id, _contentController.text, 'summarize');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ Generando resumen...'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _generateChecklist() async {
    if (_currentNote == null) return;
    setState(() => _isProcessingIA = true);
    
    await _aiService.processNoteIA(_currentNote!.id, _contentController.text, 'checklist');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📝 Creando checklist...'), duration: Duration(seconds: 2)),
      );
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              maxLines: null, 
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
                  ElevatedButton.icon(
                    onPressed: _isProcessingIA ? null : _generateChecklist,
                    icon: const Icon(Icons.checklist_rtl_rounded, size: 18),
                    label: const Text("Hacer Checklist"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      foregroundColor: Colors.green,
                    ),
                  ),
                ],
              ),

            if (_isProcessingIA) 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15), 
                child: Column(
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 5),
                    Text("La IA está trabajando...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )
              ),

            // Mostrar el resumen si existe (Se actualizará automáticamente gracias al Stream)
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
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: _checklist.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Checkbox(
                        value: _checklist[i]['checked'],
                        onChanged: (val) {
                          setState(() {
                            _checklist[i]['checked'] = val;
                            _hasChanges = true;
                          });
                        },
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: _checklist[i]['text'],
                          maxLines: null, 
                          decoration: const InputDecoration(
                            hintText: "Tarea...", 
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            _checklist[i]['text'] = val;
                            if (!_hasChanges) setState(() => _hasChanges = true);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _checklist.removeAt(i);
                            _hasChanges = true;
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }
}