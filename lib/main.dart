import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MineApp());
}

class MineApp extends StatelessWidget {
  const MineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mine-app',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101114),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5576),
          surface: Color(0xFF1B1C20),
        ),
        useMaterial3: true,
      ),
      home: const PhotoEditorScreen(),
    );
  }
}

enum PhotoFilter { original, grey, sepia, bright, invert }

const _filterLabels = ['Original', 'Grey', 'Sepia', 'Bright', 'Invert'];
const _accent = Color(0xFFFF5576);

Uint8List _applyFilter(List<Object> arguments) {
  final bytes = arguments[0] as Uint8List;
  final filter = PhotoFilter.values[arguments[1] as int];
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('The selected image could not be decoded.');
  }

  var processed = decoded;
  switch (filter) {
    case PhotoFilter.original:
      break;
    case PhotoFilter.grey:
      processed = img.grayscale(processed);
    case PhotoFilter.sepia:
      processed = img.sepia(processed);
    case PhotoFilter.bright:
      processed = img.adjustColor(processed, brightness: 1.2);
    case PhotoFilter.invert:
      processed = img.invert(processed);
  }

  return Uint8List.fromList(img.encodePng(processed));
}

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _originalBytes;
  Uint8List? _editedBytes;
  PhotoFilter _selectedFilter = PhotoFilter.original;
  bool _processing = false;
  bool _saving = false;
  int _renderRequest = 0;

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _originalBytes = bytes;
        _editedBytes = bytes;
        _selectedFilter = PhotoFilter.original;
      });
      await _selectFilter(PhotoFilter.original);
    } catch (error) {
      _showMessage('Could not open that photo.');
    }
  }

  Future<void> _selectFilter(PhotoFilter filter) async {
    final source = _originalBytes;
    if (source == null) return;

    final request = ++_renderRequest;
    setState(() {
      _selectedFilter = filter;
      _processing = true;
    });

    try {
      final result = await compute(_applyFilter, [source, filter.index]);
      if (!mounted || request != _renderRequest) return;
      setState(() => _editedBytes = result);
    } catch (error) {
      if (mounted && request == _renderRequest) {
        _showMessage('Could not apply this filter.');
      }
    } finally {
      if (mounted && request == _renderRequest) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _saveImage() async {
    final bytes = _editedBytes;
    if (bytes == null || _saving || _processing) return;

    setState(() => _saving = true);
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/mine_app_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      final saved = await GallerySaver.saveImage(
        file.path,
        albumName: 'mine-app',
      );
      if (mounted) {
        _showMessage(saved == true ? 'Saved to your gallery' : 'Could not save photo');
      }
    } catch (error) {
      _showMessage('Could not save photo');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _editedBytes != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCanvas()),
            _buildFilterStrip(),
            _buildBottomBar(hasImage),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'mine.app',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Choose photo',
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    final bytes = _editedBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          color: const Color(0xFF1B1C20),
          child: bytes == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFF26272C),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.landscape_outlined,
                          size: 36,
                          color: Color(0xFFB8B8C0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Choose a photo to start',
                        style: TextStyle(
                          color: Color(0xFFB8B8C0),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Open gallery'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes, fit: BoxFit.contain),
                    if (_processing)
                      const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterStrip() {
    final source = _originalBytes;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: PhotoFilter.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = PhotoFilter.values[index];
          final selected = filter == _selectedFilter;
          return SizedBox(
            width: 68,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: source == null ? null : () => _selectFilter(filter),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _accent : const Color(0xFF34353B),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: source == null
                          ? const ColoredBox(color: Color(0xFF25262B))
                          : ColorFiltered(
                              colorFilter: _previewFilter(filter),
                              child: Image.memory(source, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _filterLabels[index],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white : const Color(0xFF9A9AA3),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  ColorFilter _previewFilter(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.original:
        return const ColorFilter.mode(Colors.white, BlendMode.modulate);
      case PhotoFilter.grey:
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case PhotoFilter.sepia:
        return const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case PhotoFilter.bright:
        return const ColorFilter.matrix(<double>[
          1.2, 0, 0, 0, 0,
          0, 1.2, 0, 0, 0,
          0, 0, 1.2, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case PhotoFilter.invert:
        return const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  Widget _buildBottomBar(bool hasImage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: hasImage && !_saving && !_processing ? _saveImage : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined, size: 20),
          label: Text(_saving ? 'Saving' : 'Save to gallery'),
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF35363B),
            disabledForegroundColor: const Color(0xFF888890),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}