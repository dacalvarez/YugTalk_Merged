import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_compress/video_compress.dart';
import 'package:file_selector/file_selector.dart';

class AddEditVideo extends StatefulWidget {
  final String wordVideo;
  final ValueChanged<String> onVideoChanged;

  const AddEditVideo({
    required this.wordVideo,
    required this.onVideoChanged,
  });

  @override
  _AddEditVideoState createState() => _AddEditVideoState();
}

class _AddEditVideoState extends State<AddEditVideo> {
  late String _currentVideo;
  bool _isLoading = false;
  Subscription? _subscription;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.wordVideo;
    VideoCompress.setLogLevel(0); // Initialize the video_compress plugin
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      var file;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final typeGroup = XTypeGroup(label: 'videos', extensions: ['mov', 'mp4']);
        file = await openFile(acceptedTypeGroups: [typeGroup]);
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: source);
        file = pickedFile != null ? File(pickedFile.path) : null;
      }

      if (file == null) {
        return;
      }

      final videoFile = File(file.path);
      final videoDuration = await _getVideoDuration(videoFile);
      if (videoDuration > const Duration(seconds: 5)) {
        _showErrorDialog('The selected video exceeds the 5-second limit.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      File? processedVideo = await _compressVideo(videoFile);

      setState(() {
        _currentVideo = processedVideo?.path ?? file.path;
        print("Current video path after compression: $_currentVideo");
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  Future<Duration> _getVideoDuration(File videoFile) async {
    final info = await VideoCompress.getMediaInfo(videoFile.path);
    return Duration(milliseconds: info.duration!.toInt());
  }

  Future<File?> _compressVideo(File videoFile) async {
    try {
      print("Compressing video: ${videoFile.path}");
      _subscription = VideoCompress.compressProgress$.subscribe((progress) {
        setState(() {
          _isLoading = true;
        });
        if (progress == 100) {
          _subscription?.unsubscribe();
        }
      });

      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24,
        duration: 5,
      );

      print("Compressed video path: ${info?.file?.path}");
      return info?.file;
    } catch (e) {
      print("Error compressing video: $e");
      _subscription?.unsubscribe();
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteVideo() {
    setState(() {
      _currentVideo = '';
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogHeight = screenHeight * 0.35;
    final dialogWidth = screenWidth * 0.35;

    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text('Select Video'),
        content: SizedBox(
          height: dialogHeight,
          width: dialogWidth,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: Center(
                    child: _currentVideo.isEmpty
                        ? const Text('No video selected')
                        : const Text('Video uploaded. Long press the word to view.'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _pickVideo(ImageSource.gallery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Gallery', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _pickVideo(ImageSource.camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Camera', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              if (_currentVideo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _deleteVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onVideoChanged(_currentVideo);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

void showAddEditVideoDialog(BuildContext context, String wordVideo, ValueChanged<String> onVideoChanged) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (context) => AddEditVideo(wordVideo: wordVideo, onVideoChanged: onVideoChanged),
  );
}
