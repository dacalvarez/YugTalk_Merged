import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gtext/gtext.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class PopupFormMod extends StatefulWidget {
  final String boardID;
  final String symbolID;

  const PopupFormMod({Key? key, required this.boardID, required this.symbolID}) : super(key: key);

  @override
  _PopupFormModState createState() => _PopupFormModState();
}

class _PopupFormModState extends State<PopupFormMod> {
  final FlutterTts flutterTts = FlutterTts();
  final AudioPlayer audioPlayer = AudioPlayer();
  VideoPlayerController? _videoPlayerController;
  String wordName = '';
  String wordDesc = '';
  String wordAudio = '';
  String wordVideo = '';
  String wordImage = '';
  String wordCategory = '';
  double _volume = 1.0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchWordData();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _fetchWordData() async {
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('board')
          .doc(widget.boardID)
          .collection('words')
          .doc(widget.symbolID)
          .get();

      if (documentSnapshot.exists) {
        setState(() {
          wordName = documentSnapshot['wordName'];
          wordDesc = documentSnapshot['wordDesc'];
          wordAudio = documentSnapshot['wordAudio'];
          wordVideo = documentSnapshot['wordVideo'];
          wordImage = documentSnapshot['wordImage'];
          wordCategory = documentSnapshot['wordCategory'];

          if (wordVideo.isNotEmpty) {
            _videoPlayerController = VideoPlayerController.network(wordVideo)
              ..initialize().then((_) {
                setState(() {});
              }).catchError((_) {
                setState(() {
                  _videoPlayerController = null;
                });
              })
              ..addListener(() {
                if (_videoPlayerController!.value.position ==
                    _videoPlayerController!.value.duration) {
                  setState(() {});
                }
              });
          }
        });
      }
    } catch (e) {
      print('Error fetching word data: $e');
    }
  }

  Future<void> _playAudio() async {
    if (wordAudio.isNotEmpty) {
      try {
        await audioPlayer.setUrl(wordAudio);
        audioPlayer.play();
      } catch (e) {
        await flutterTts.speak(wordName);
      }
    } else {
      await flutterTts.speak(wordName);
    }
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'nouns':
        return const Color(0xffffb33f);
      case 'pronouns':
        return const Color(0xffffe682);
      case 'verbs':
        return const Color(0xff9ee281);
      case 'adjectives':
        return const Color(0xff69c8ff);
      case 'prepositions':
        return const Color(0xffff8cd2);
      case 'social words':
        return const Color(0xffff8cd2);
      case 'questions':
        return const Color(0xffa77dff);
      case 'negations':
        return const Color(0xffff5150);
      case 'important words':
        return const Color(0xffff5150);
      case 'adverbs':
        return const Color(0xffc19b84);
      case 'conjunctions':
        return const Color(0xffffffff);
      case 'determiners':
        return const Color(0xff464646);
      default:
        return Colors.grey;
    }
  }

  Color _getTextColorForCategory(String category) {
    return category.toLowerCase() == 'determiners' ? Colors.black: Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = _getColorForCategory(wordCategory);
    Color textColor = _getTextColorForCategory(wordCategory);
    bool hasVideo = wordVideo.isNotEmpty && _videoPlayerController != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      backgroundColor: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Container(
          width: hasVideo 
              ? MediaQuery.of(context).size.width * 0.80
              : MediaQuery.of(context).size.width * 0.70,
          height: hasVideo 
              ? MediaQuery.of(context).size.height * 0.80
              : MediaQuery.of(context).size.height * 0.80,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 10),
              _buildTopRow(),
              const SizedBox(height: 20),
              _buildBottomContainer(textColor, hasVideo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    bool hasVideo = wordVideo.isNotEmpty && _videoPlayerController != null;
    if (hasVideo) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildVideoContainer(),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              _buildSymbolContainer(isLarge: false),
              const SizedBox(height: 10),
              _buildSpeakerContainer(isLarge: false),
            ],
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSymbolContainer(isLarge: true),
          const SizedBox(width: 20),
          _buildSpeakerContainer(isLarge: true),
        ],
      );
    }
  }

  Widget _buildVideoContainer() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      height: MediaQuery.of(context).size.height * 0.35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        children: [
          GestureDetector(
            child: VideoPlayer(_videoPlayerController!),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildSymbolContainer({required bool isLarge}) {
    double size = isLarge 
        ? MediaQuery.of(context).size.height * 0.35 
        : MediaQuery.of(context).size.height * 0.17;
    
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: wordImage.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Image.network(
                wordImage,
                fit: BoxFit.cover,
                headers: const {
                  "Content-Type": "image/jpeg",
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return const Center(
                    child: Text(
                      'Error loading image',
                      style: TextStyle(color: Colors.black),
                    ),
                  );
                },
              ),
            )
          : const Center(
              child: Text(
                'Symbol Container',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
    );
  }

  Widget _buildSpeakerContainer({required bool isLarge}) {
    double size = isLarge 
        ? MediaQuery.of(context).size.height * 0.35 
        : MediaQuery.of(context).size.height * 0.17;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: IconButton(
        icon: Icon(Icons.volume_up, color: Colors.black, size: isLarge ? 120 : 55),
        onPressed: _playAudio,
      ),
    );
  }

  Widget _buildBottomContainer(Color textColor, bool hasVideo) {
    return Container(
      width: hasVideo ? double.infinity : MediaQuery.of(context).size.width * 0.6,
      height: MediaQuery.of(context).size.height * 0.25,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wordName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 24, // Increased font size
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                wordDesc.isNotEmpty ? wordDesc : 'No description for this symbol',
                style: TextStyle(
                  fontStyle: wordDesc.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  color: Colors.black,
                  fontSize: 18, // Increased font size
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    bool isVideoFinished = _videoPlayerController!.value.position == _videoPlayerController!.value.duration;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          VideoProgressIndicator(_videoPlayerController!, allowScrubbing: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isVideoFinished ? Icons.replay : (_videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isVideoFinished) {
                          _videoPlayerController!.seekTo(Duration.zero);
                          _videoPlayerController!.play();
                        } else {
                          _videoPlayerController!.value.isPlaying
                              ? _videoPlayerController!.pause()
                              : _videoPlayerController!.play();
                        }
                      });
                    },
                  ),
                  const Icon(
                    Icons.volume_up,
                    color: Colors.white,
                  ),
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() {
                          _volume = value;
                          _videoPlayerController!.setVolume(_volume);
                        });
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: PopupMenuButton<double>(
                  initialValue: _playbackSpeed,
                  onSelected: (speed) {
                    setState(() {
                      _playbackSpeed = speed;
                      _videoPlayerController!.setPlaybackSpeed(speed);
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 0.5,
                      child: Text("0.5x"),
                    ),
                    const PopupMenuItem(
                      value: 0.75,
                      child: Text("0.75x"),
                    ),
                    const PopupMenuItem(
                      value: 1.0,
                      child: Text("1.0x (Normal)"),
                    ),
                    const PopupMenuItem(
                      value: 1.25,
                      child: Text("1.25x"),
                    ),
                    const PopupMenuItem(
                      value: 1.5,
                      child: Text("1.5x"),
                    ),
                  ],
                  child: const Icon(
                    Icons.speed,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}