import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:gtext/gtext.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';

class AddEditAudio extends StatefulWidget {
  final String audioPath;
  final ValueChanged<String> onAudioChanged;
  final String? boardId;
  final String? symbolId;

  const AddEditAudio({
    Key? key,
    required this.audioPath,
    required this.onAudioChanged,
    required this.boardId,
    required this.symbolId,
  }) : super(key: key);

  @override
  _AddEditAudioState createState() => _AddEditAudioState();
}

class _AddEditAudioState extends State<AddEditAudio> {
  FlutterSoundRecorder? _recorder;
  AudioPlayer? _player;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;
  bool _hasUnsavedChanges = false;
  late Timer _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = AudioPlayer();
    _initializeRecorder();
    if (widget.audioPath.isNotEmpty) {
      _recordedFilePath = widget.audioPath;
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // No need for microphone permissions on desktop platforms
      } else {
        if (await Permission.microphone.request().isGranted) {
          // Microphone permission granted
        } else {
          _showError('Microphone permission denied.');
          return;
        }
      }
      await _recorder!.openRecorder();
    } catch (e) {
      _showError('Failed to initialize recorder: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GText(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      Directory cacheDir = await getTemporaryDirectory();
      String cachePath = cacheDir.path;
      _recordedFilePath = '$cachePath/recorded_audio.${getSupportedFileExtension()}';
      await _recorder!.startRecorder(
        toFile: _recordedFilePath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _startTimer();
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder!.stopRecorder();
      _stopTimer();
      setState(() {
        _isRecording = false;
      });

      if (_recordedFilePath != null) {
        final downloadUrl = await _uploadAudioToFirebase(_recordedFilePath!);
        if (downloadUrl.isNotEmpty) {
          widget.onAudioChanged(downloadUrl);
          setState(() {
            _hasUnsavedChanges = true;
          });
        }
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_recordedFilePath != null) {
        if (_recordedFilePath!.startsWith('http')) {
          // It's a URL, likely from Firestore
          await _player!.setUrl(_recordedFilePath!);
        } else {
          // It's a local file path
          await _player!.setFilePath(_recordedFilePath!);
        }

        await _player!.play();
        setState(() {
          _isPlaying = true;
        });

        _player!.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      } else {
        // If _recordedFilePath is null, try to fetch from Firestore
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('board')
              .doc(widget.boardId)
              .collection('words')
              .doc(widget.symbolId)
              .get();

          if (doc.exists && doc.data() != null) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String? audioUrl = data['wordAudio'] as String?;

            if (audioUrl != null && audioUrl.isNotEmpty) {
              await _player!.setUrl(audioUrl);
              await _player!.play();
              setState(() {
                _isPlaying = true;
                _recordedFilePath = audioUrl;
              });

              _player!.playerStateStream.listen((state) {
                if (state.processingState == ProcessingState.completed) {
                  setState(() {
                    _isPlaying = false;
                  });
                }
              });
            } else {
              _showError('No audio file available');
            }
          } else {
            _showError('No audio file available');
          }
        } catch (firestoreError) {
          _showError('Failed to fetch audio from Firestore: $firestoreError');
        }
      }
    } catch (e) {
      _showError('Failed to play recording: $e');
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _player!.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      _showError('Failed to stop playing: $e');
    }
  }

  Future<void> _uploadAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      final filePath = result.files.single.path;
      if (filePath != null) {
        final downloadUrl = await _uploadAudioToFirebase(filePath);
        if (downloadUrl.isNotEmpty) {
          setState(() {
            _recordedFilePath = downloadUrl;
            widget.onAudioChanged(_recordedFilePath!);
            _hasUnsavedChanges = true;
          });
        }
      }
    }
  }

  Future<void> _deleteRecording() async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: GText('Delete recording?'),
        content: GText('Are you sure you want to delete the recorded audio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: GText('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: GText('Yes'),
          ),
        ],
      ),
    );
    if (confirmDelete == true) {
      if (_recordedFilePath != null && _recordedFilePath!.startsWith('https://')) {
        try {
          // Delete from Firebase Storage
          final ref = FirebaseStorage.instance.refFromURL(_recordedFilePath!);
          await ref.delete();

          // Update Firestore only if boardId and symbolId are not null
          if (widget.boardId != null && widget.symbolId != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('board')
                  .doc(widget.boardId)
                  .collection('words')
                  .doc(widget.symbolId)
                  .update({'wordAudio': ''});
            } catch (firestoreError) {
              print('Failed to update Firestore: $firestoreError');
              // If the document doesn't exist, we can ignore this error
              if (firestoreError is! FirebaseException || firestoreError.code != 'not-found') {
                throw firestoreError;  // Re-throw if it's not a 'not-found' error
              }
            }
          }

          _showSuccessMessage('Audio deleted successfully');
        } catch (e) {
          _showError('Failed to delete audio: $e');
          return;
        }
      }
      setState(() {
        _recordedFilePath = null;
        widget.onAudioChanged('');
        _hasUnsavedChanges = true;
      });
    }
  }


  String getSupportedFileExtension() {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'aac'; // Use .aac on mobile platforms
    } else {
      return 'wav'; // Use .wav on other platforms for better compatibility
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GText(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<String> _uploadAudioToFirebase(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }
      final fileName = filePath.split('/').last;
      final destination = 'media/audio/$fileName';
      final ref = FirebaseStorage.instance.ref(destination);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with the new audio URL
      await FirebaseFirestore.instance
          .collection('board')
          .doc(widget.boardId)
          .collection('words')
          .doc(widget.symbolId)
          .update({'wordAudio': downloadUrl});

      widget.onAudioChanged(downloadUrl);  // Use the callback here

      return downloadUrl;
    } catch (e) {
      _showError('Failed to upload audio: $e');
      return '';
    }
  }

  void _confirmCancel() {
    if (_hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: GText('Discard changes?'),
          content: GText('Are you sure you want to discard all changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: GText('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
                Navigator.pop(context);
              },
              child: GText('Yes'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
        if (_recordDuration >= 10) {
          _stopRecording();
        }
      });
    });
  }

  void _stopTimer() {
    _timer.cancel();
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _player!.dispose();
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: GText('Audio'),
      content: Container(
        padding: const EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height * 0.20,
        width: MediaQuery.of(context).size.width * 0.25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRecording)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey[200],
                child: GText('Recording in progress...'),
              )
            else if (_recordedFilePath != null)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey[200],
                child: GText('Recorded audio data available.'),
              ),
            const SizedBox(height: 10),
            if (_isRecording) ...[
              _buildRecordStopButtons(),
            ] else if (_recordedFilePath != null) ...[
              _buildPlayButton(),
              const SizedBox(height: 10),
              _buildDeleteButton(),
            ] else ...[
              _buildRecordStopButtons(),
              const SizedBox(height: 10),
              _buildUploadButton(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _confirmCancel,
          child: GText('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_recordedFilePath != null) {
              widget.onAudioChanged(_recordedFilePath!);
            }
            Navigator.pop(context);
          },
          child: GText('Save'),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isPlaying ? _stopPlaying : _playRecording,
            child: GText(
              _isPlaying ? 'Stop' : 'Play',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _deleteRecording,
            child: GText(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordStopButtons() {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red[700] : Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isRecording ? _stopRecording : _startRecording,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                GText(
                  _isRecording ? 'Recording' : 'Record',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (_isRecording)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: GText(
                      'Press to stop recording',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isRecording)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: GText(
              'Recording time: ${_recordDuration}s',
              style: TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _uploadAudio,
            child: GText(
              'Upload',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        if (_recordedFilePath != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _deleteRecording,
              child: GText(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

void showAddEditAudioDialog(BuildContext context, String wordAudio, ValueChanged<String> onAudioChanged, {required String boardId, required String symbolId}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddEditAudio(
      audioPath: wordAudio,
      onAudioChanged: onAudioChanged,
      boardId: boardId,
      symbolId: symbolId,
    ),
  );
}
