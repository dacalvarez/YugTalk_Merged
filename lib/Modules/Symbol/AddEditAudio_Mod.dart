import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';

class AddEditAudio extends StatefulWidget {
  final String audioPath;
  final ValueChanged<String> onAudioChanged;

  const AddEditAudio({
    required this.audioPath,
    required this.onAudioChanged,
  });

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

  Future<void> _startRecording() async {
    try {
      _recordedFilePath = 'recorded_audio.${getSupportedFileExtension()}';
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
        widget.onAudioChanged(_recordedFilePath!);
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_recordedFilePath != null) {
        await _player!.setFilePath(_recordedFilePath!);
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
      setState(() {
        _recordedFilePath = result.files.single.path;
        widget.onAudioChanged(_recordedFilePath!);
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _deleteRecording() async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text('Are you sure you want to delete the recorded audio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmDelete == true) {
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
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _confirmCancel() {
    if (_hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Are you sure you want to discard all changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
                Navigator.pop(context);
              },
              child: const Text('Yes'),
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
      title: const Text('Audio'),
      content: Container(
        padding: const EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height * 0.20,
        width: MediaQuery.of(context).size.width * 0.25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_recordedFilePath != null)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey[200],
                child: const Text('Recorded audio data available.'),
              ),
            const SizedBox(height: 10),
            if (_recordedFilePath != null) ...[
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_recordedFilePath != null) {
              widget.onAudioChanged(_recordedFilePath!);
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
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
            child: Text(
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
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordStopButtons() {
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
            onPressed: _isRecording ? _stopRecording : _startRecording,
            child: Text(
              _isRecording ? 'Stop' : 'Record',
              style: const TextStyle(color: Colors.white),
            ),
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
            child: const Text(
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
              child: const Text(
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

void showAddEditAudioDialog(BuildContext context, String wordAudio, ValueChanged<String> onAudioChanged) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddEditAudio(
      audioPath: wordAudio,
      onAudioChanged: onAudioChanged,
    ),
  );
}
