import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:gtext/gtext.dart';
import '../CommBoard/BoardDisplay_Mod.dart';
import 'package:just_audio/just_audio.dart';
import 'Activity Forms/ActivityForms.dart';
import 'Activity Forms/CreatePLS5Form_Widget.dart';

class SpeechAssessmentScreen extends StatefulWidget {
  @override
  _SpeechAssessmentScreenState createState() => _SpeechAssessmentScreenState();
}

class _SpeechAssessmentScreenState extends State<SpeechAssessmentScreen>
    with SingleTickerProviderStateMixin {
  String? selectedBoardId;
  List<String> selectedWords = [];
  double speed = 1.0;
  int repetitions = 1;
  List<String> availableWords = [];
  FlutterTts flutterTts = FlutterTts();
  SpeechToText speech = SpeechToText();
  bool isListening = false;
  int currentWordIndex = 0;
  int correctWords = 0;
  List<Map<String, dynamic>> assessmentResults = [];
  int correctAuditoryComprehension = 0;
  int correctExpressiveCommunication = 0;
  String? userEmail;
  final AudioPlayer audioPlayer = AudioPlayer();
  String assessmentStatus = '';
  Timer? _listenTimer;
  List<Map<String, String>> filteredSymbols = [];
  Map<String, Map<String, dynamic>> scores = {
    'Auditory Comprehension': {
      'rawScore': 0,
      'standardScore': 0,
      'percentileRank': 0,
      'descriptiveRange': ''
    },
    'Expressive Communication': {
      'rawScore': 0,
      'standardScore': 0,
      'percentileRank': 0,
      'descriptiveRange': ''
    },
    'Total Language Score': {
      'standardScore': 0,
      'percentileRank': 0,
      'descriptiveRange': ''
    },
  };
  late AnimationController _animationController;
  late Animation<double> _animation;
  String assessmentType = 'Auditory Comprehension';
  List<Map<String, dynamic>> expressiveQuestions = [
    {"question": "What is your name?", "selected": false},
    {"question": "How old are you?", "selected": false},
    {"question": "Who is your Mommy?", "selected": false},
    {"question": "Who is your Daddy?", "selected": false},
    {"question": "What is your favorite color?", "selected": false},
    {"question": "What is your favorite game?", "selected": false},
    {"question": "What is your favorite food?", "selected": false},
    {"question": "Do you have any brothers or sisters?", "selected": false},
    {"question": "What's your favorite animal?", "selected": false},
    {"question": "Who is your Favorite Toy?", "selected": false},
  ];
  int currentQuestionIndex = 0;
  List<Map<String, dynamic>> expressiveResults = [];
  bool isAssessmentStarted = false;
  List<Map<String, dynamic>> selectedQuestions = [];
  bool isAuditoryComprehensionComplete = false;
  String currentAssessment = '';


  @override
  void initState() {
    super.initState();
    _initializeTts().then((_) => _initializeStt());
    _getCurrentUserEmail();
    expressiveQuestions.shuffle();
    selectedQuestions = [];
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await _resetSpeechRate();
  }

  void _initializeStt() async {
    bool available = await speech.initialize();
    if (!available) {
      print("The user has denied the use of speech recognition.");
    }
  }

  Future<void> _getCurrentUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });
    }
  }

  void _fetchAndFilterSymbols() async {
    if (selectedBoardId == null) return;

    QuerySnapshot symbolsSnapshot = await FirebaseFirestore.instance
        .collection('board')
        .doc(selectedBoardId)
        .collection('words')
        .get();

    List<Map<String, dynamic>> allSymbols = symbolsSnapshot.docs
        .map((doc) => {
      ...doc.data() as Map<String, dynamic>,
      'id': doc.id,
    })
        .toList();

    setState(() {
      filteredSymbols = allSymbols
          .where((symbol) => selectedWords.contains(symbol['wordName']))
          .map((symbol) =>
          symbol.map((key, value) => MapEntry(key, value.toString())))
          .toList();
    });
  }

  void _handleSymbolSelected(Map<String, String> symbol) {
    String word = symbol['word'] ?? '';
    String? audioUrl = symbol['wordAudio'];

    if (audioUrl != null && audioUrl.isNotEmpty) {
      _playAudio(audioUrl);
    } else {
      _speakWord(word);
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      await audioPlayer.setUrl(url);
      await audioPlayer.setSpeed(speed);  // Set the playback speed
      await audioPlayer.play();
      await audioPlayer.playerStateStream.firstWhere(
            (state) => state.processingState == ProcessingState.completed,
      );
    } catch (e) {
      print("Error playing audio: $e");
      await _speakWord(url.split('/').last.split('.').first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAssessmentTypeSelection(),
                  SizedBox(height: 20),
                  if (!isAssessmentStarted) ...[
                    if (assessmentType != 'Expressive Communication') ...[
                      _buildBoardSelection(),
                      SizedBox(height: 20),
                      _buildWordSelection(),
                      SizedBox(height: 20),
                      _buildSpeedSlider(),
                      SizedBox(height: 20),
                      _buildRepetitionsInput(),
                      SizedBox(height: 20),
                      if (selectedBoardId != null) _buildBoardDisplay(),
                      SizedBox(height: 20),
                    ],
                    if (assessmentType == 'Expressive Communication' || assessmentType == 'Both')
                      _buildExpressiveQuestionSelection(),
                    SizedBox(height: 20),
                    _buildStartAssessmentButton(),
                  ] else ...[
                    if (currentAssessment == 'Auditory Comprehension')
                      _buildAuditoryComprehensionAssessment(),
                    if (currentAssessment == 'Expressive Communication')
                      _buildExpressiveCommunicationAssessment(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditoryComprehensionAssessment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GText('Auditory Comprehension Assessment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        _buildAssessmentStatus(),
        SizedBox(height: 10),
        _buildAuditoryResults(),
      ],
    );
  }

  Widget _buildExpressiveCommunicationAssessment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GText('Expressive Communication Assessment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text('Question ${currentQuestionIndex + 1} of ${selectedQuestions.length}:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text(selectedQuestions[currentQuestionIndex]['question'], style: TextStyle(fontSize: 24)),
        SizedBox(height: 20),
        Center(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_animation.value * 0.1),
                child: ElevatedButton(
                  onPressed: _startListeningExpressive,
                  child: Text(isListening ? 'Listening...' : 'Start Speaking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isListening ? Colors.red : Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        _buildExpressiveResults(),
      ],
    );
  }


  void _startListeningExpressive() async {
    bool available = await speech.initialize(
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (status == 'done') {
          _processExpressiveResult(null);
        }
      },
      onError: (error) => print('Speech recognition error: $error'),
    );

    if (available) {
      setState(() => isListening = true);
      speech.listen(
        onResult: (result) => _processExpressiveResult(result),
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 2),
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );

      _animationController.repeat(reverse: true);

      _listenTimer = Timer(Duration(seconds: 10), () {
        if (isListening) {
          speech.stop();
          _processExpressiveResult(null);
        }
      });
    } else {
      print("Speech recognition not available");
      _moveToNextExpressiveQuestion();
    }
  }

  void _moveToNextExpressiveQuestion() {
    if (currentQuestionIndex < selectedQuestions.length) {
      _startExpressiveCommunication();
    } else {
      _finishAssessment();
    }
  }

  Future<void> _speakExpressiveQuestion(String question) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(question);
    return flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _resetSpeechRate() async {
    double adjustedSpeed = speed * 0.5; // Slow down the speed
    await flutterTts.setSpeechRate(adjustedSpeed);
  }

  void _processExpressiveResult(SpeechRecognitionResult? result) {
    _listenTimer?.cancel();
    _animationController.stop();
    _animationController.reset();

    if (!isListening) return;

    setState(() => isListening = false);
    speech.stop();

    String response = '';
    int wordCount = 0;

    if (result != null && result.recognizedWords.isNotEmpty) {
      response = result.recognizedWords;
      wordCount = response.split(' ').where((word) => word.isNotEmpty).length;
    }

    setState(() {
      expressiveResults.add({
        'question': selectedQuestions[currentQuestionIndex]['question'],
        'response': response,
        'wordCount': wordCount,
      });

      currentQuestionIndex++;
    });

    _moveToNextExpressiveQuestion();
  }


  Widget _buildAuditoryResults() {
    return Column(
      children: assessmentResults.map((result) => ListTile(
        title: Text(result['word']),
        subtitle: Text('Spoken: ${result['spoken']}'),
        trailing: Icon(
          result['correct'] ? Icons.check_circle : Icons.cancel,
          color: result['correct'] ? Colors.green : Colors.red,
        ),
      )).toList(),
    );
  }

  Widget _buildExpressiveResults() {
    return Column(
      children: expressiveResults.map((result) => ListTile(
        title: Text(result['question']),
        subtitle: Text('Response: ${result['response']}'),
        trailing: Text('Words: ${result['wordCount']}'),
      )).toList(),
    );
  }

  Widget _buildAssessmentTypeSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GText('Assessment Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: assessmentType,
              items: ['Auditory Comprehension', 'Expressive Communication', 'Both']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: isAssessmentStarted ? null : (String? newValue) {
                setState(() {
                  assessmentType = newValue!;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GText('Select Board',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('board')
                  .where('ownerID', isEqualTo: userEmail)
                  .where('isActivityBoard', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return CircularProgressIndicator(color: Colors.deepPurple);

                List<DropdownMenuItem<String>> boardItems = snapshot.data!.docs
                    .map((doc) => DropdownMenuItem(
                  value: doc.id,
                  child: Text(doc['name'] ?? 'Unnamed Board'),
                ))
                    .toList();

                return DropdownButtonFormField<String>(
                  value: selectedBoardId,
                  items: boardItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedBoardId = newValue;
                      _fetchAvailableWords();
                    });
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: GText('Select a board'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GText('Select Words:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: availableWords.map((word) {
                bool isSelected = selectedWords.contains(word);
                return FilterChip(
                  label: Text(word),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedWords.add(word);
                      } else {
                        selectedWords.remove(word);
                      }
                    });
                    _fetchAndFilterSymbols();
                  },
                  selectedColor: Colors.deepPurple.withOpacity(0.2),
                  checkmarkColor: Colors.deepPurple,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedSlider() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GText('Speed: ${speed.toStringAsFixed(1)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Slider(
              value: speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (value) {
                setState(() {
                  speed = value;
                });
                flutterTts.setSpeechRate(speed);
              },
              activeColor: Colors.deepPurple,
              inactiveColor: Colors.deepPurple.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepetitionsInput() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            GText('Repetitions: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(width: 10),
            Container(
              width: 50,
              child: TextFormField(
                initialValue: repetitions.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    repetitions = int.tryParse(value) ?? 1;
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardDisplay() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GText('Communication Board',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Container(
              height: 300,
              child: BoardDisplay_Mod(
                boardID: selectedBoardId!,
                onSymbolSelected: _handleSymbolSelected,
                selectedSymbols: filteredSymbols,
                language: 'English',
                incrementUsageCount: false,
                translate: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartAssessmentButton() {
    return ElevatedButton(
      onPressed: _startAssessment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
        child: GText('Start Assessment', style: TextStyle(fontSize: 18)),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildAssessmentStatus() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  assessmentStatus == 'Listen...' ? Icons.hearing : Icons.mic,
                  size: 24,
                  color: Colors.deepPurple,
                ),
                SizedBox(width: 10),
                GText(
                  assessmentStatus,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpressiveQuestionSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GText('Select Expressive Communication Questions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            ...expressiveQuestions.map((question) => CheckboxListTile(
              title: Text(question['question']),
              value: question['selected'],
              onChanged: (bool? value) {
                setState(() {
                  question['selected'] = value;
                  // Update selectedQuestions immediately
                  if (value == true) {
                    selectedQuestions.add(question);
                  } else {
                    selectedQuestions.removeWhere((q) => q['question'] == question['question']);
                  }
                });
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _fetchAvailableWords() async {
    if (selectedBoardId == null) return;

    QuerySnapshot wordsSnapshot = await FirebaseFirestore.instance
        .collection('board')
        .doc(selectedBoardId)
        .collection('words')
        .get();

    setState(() {
      availableWords =
          wordsSnapshot.docs.map((doc) => doc['wordName'] as String).toList();
      selectedWords.clear();
      filteredSymbols.clear();
    });
  }

  void _startAssessment() {
    if ((assessmentType == 'Expressive Communication' || assessmentType == 'Both') &&
        selectedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: GText('Please select at least one expressive communication question')),
      );
      return;
    }

    setState(() {
      isAssessmentStarted = true;
      currentWordIndex = 0;
      currentQuestionIndex = 0;
      correctWords = 0;
      assessmentResults.clear();
      expressiveResults.clear();
      correctAuditoryComprehension = 0;
      correctExpressiveCommunication = 0;
      currentAssessment = assessmentType == 'Expressive Communication' ? 'Expressive Communication' : 'Auditory Comprehension';

      // Clear all scores
      scores = {
        'Auditory Comprehension': {
          'rawScore': 0,
          'standardScore': 0,
          'percentileRank': 0,
          'descriptiveRange': ''
        },
        'Expressive Communication': {
          'rawScore': 0,
          'standardScore': 0,
          'percentileRank': 0,
          'descriptiveRange': ''
        },
        'Total Language Score': {
          'standardScore': 0,
          'percentileRank': 0,
          'descriptiveRange': ''
        },
      };
    });

    if (currentAssessment == 'Auditory Comprehension') {
      _speakAndListen();
    } else {
      _startExpressiveCommunication();
    }
  }

  void _startExpressiveCommunication() {
    if (currentQuestionIndex >= selectedQuestions.length) {
      _finishAssessment();
      return;
    }

    _speakExpressiveQuestion(selectedQuestions[currentQuestionIndex]['question'])
        .then((_) => _startListeningExpressive());
  }

  void _speakAndListen() async {
    if (currentWordIndex >= selectedWords.length) {
      _finishAssessment();
      return;
    }

    String currentWord = selectedWords[currentWordIndex];
    Map<String, String> currentSymbol = filteredSymbols.firstWhere(
          (symbol) => symbol['wordName'] == currentWord,
      orElse: () => <String, String>{},
    );

    setState(() {
      assessmentStatus = 'Listen...';
    });
    _animationController.forward();

    await _resetSpeechRate();

    // Add a small delay before speaking the first word
    if (currentWordIndex == 0) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Speak the word (Auditory Comprehension part)
    for (int i = 0; i < repetitions; i++) {
      if (currentSymbol['wordAudio'] != null && currentSymbol['wordAudio']!.isNotEmpty) {
        await _playAudio(currentSymbol['wordAudio']!);
      } else {
        await _speakWord(currentWord);
      }
      await Future.delayed(Duration(milliseconds: 500));
    }

    setState(() {
      assessmentStatus = 'Your turn';
    });
    _animationController.reverse().then((_) => _animationController.forward());

    // Listen for the spoken word (Expressive Communication part)
    await _startListening(currentWord);
  }

  Future<void> _startListening(String currentWord) async {
    if (!isListening) {
      bool available = await speech.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done') {
            _processResult(null, currentWord); // Handle timeout
          }
        },
        onError: (error) => print('Speech recognition error: $error'),
      );

      if (available) {
        setState(() => isListening = true);
        speech.listen(
          onResult: (result) => _processResult(result, currentWord),
          listenFor: Duration(seconds: 5), // Adjust this duration as needed
          pauseFor: Duration(seconds: 2),
          partialResults: false,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        );

        // Set a timeout in case speech recognition takes too long
        _listenTimer = Timer(Duration(seconds: 7), () {
          if (isListening) {
            speech.stop();
            _processResult(null, currentWord);
          }
        });
      } else {
        print("Speech recognition not available");
        _moveToNextWord();
      }
    }
  }

  Future<void> _speakWord(String word) async {
    await flutterTts.setSpeechRate(speed);
    await flutterTts.speak(word);
    return flutterTts.awaitSpeakCompletion(true);
  }

  void _processResult(SpeechRecognitionResult? result, String currentWord) {
    _listenTimer?.cancel();
    if (!isListening) return; // Prevent multiple calls

    setState(() => isListening = false);
    speech.stop();

    bool isCorrect = false;
    String spokenWord = '';

    if (result != null && result.recognizedWords.isNotEmpty) {
      spokenWord = result.recognizedWords.split(' ')[0]; // Take only the first word
      isCorrect = spokenWord.toLowerCase() == currentWord.toLowerCase();
    }

    setState(() {
      assessmentResults.add({
        'word': currentWord,
        'spoken': spokenWord,
        'correct': isCorrect,
      });
      if (isCorrect) {
        correctAuditoryComprehension++;
        correctExpressiveCommunication++;
      }
      currentWordIndex++;
      assessmentStatus = '';
    });

    _moveToNextWord();
  }

  void _moveToNextWord() {
    if (currentWordIndex < selectedWords.length) {
      _animationController.reverse().then((_) => _speakAndListen());
    } else {
      _finishAssessment();
    }
  }

  void _finishAssessment() {
    speech.stop();
    _listenTimer?.cancel();

    if (assessmentType == 'Both' && currentAssessment == 'Auditory Comprehension') {
      setState(() {
        currentAssessment = 'Expressive Communication';
        currentQuestionIndex = 0;
      });
      _startExpressiveCommunication();
      return;
    }

    if (assessmentType == 'Auditory Comprehension' || assessmentType == 'Both') {
      scores['Auditory Comprehension']!['rawScore'] = (correctAuditoryComprehension / repetitions).round();
    }

    if (assessmentType == 'Expressive Communication' || assessmentType == 'Both') {
      int totalWords = expressiveResults.fold(0, (sum, result) => sum + (result['wordCount'] as int));
      scores['Expressive Communication']!['rawScore'] = totalWords;
    }

    List<String> subsets = [];
    if (assessmentType == 'Auditory Comprehension' || assessmentType == 'Both') {
      subsets.add('Auditory Comprehension');
    }
    if (assessmentType == 'Expressive Communication' || assessmentType == 'Both') {
      subsets.add('Expressive Communication');
    }

    for (var subset in subsets) {
      int rawScore = scores[subset]!['rawScore'];
      int totalItems = subset == 'Auditory Comprehension'
          ? (selectedWords.length / repetitions).round()
          : expressiveQuestions.length;
      int standardScore = _calculateStandardScore(rawScore, totalItems, subset); // Fixed: added subset as the third argument
      int percentileRank = _calculatePercentileRank(standardScore);
      String descriptiveRange = _getDescriptiveRange(standardScore);

      scores[subset]!['standardScore'] = standardScore;
      scores[subset]!['percentileRank'] = percentileRank;
      scores[subset]!['descriptiveRange'] = descriptiveRange;
    }

    if (assessmentType == 'Both') {
      int totalStandardScore = (scores['Auditory Comprehension']!['standardScore'] +
          scores['Expressive Communication']!['standardScore']) ~/ 2;
      scores['Total Language Score']!['standardScore'] = totalStandardScore;
      scores['Total Language Score']!['percentileRank'] = _calculatePercentileRank(totalStandardScore);
      scores['Total Language Score']!['descriptiveRange'] = _getDescriptiveRange(totalStandardScore);
    }

    setState(() {
      isAssessmentStarted = false;
      assessmentStatus = 'Assessment complete';
    });

    _showResultsTable();
  }

  void _navigateToPLS5Form() {
    _getBoardNameById(selectedBoardId).then((selectedBoardName) {
      print("Selected Board ID before navigation: $selectedBoardId");
    List<Map<String, String>> pls5Rows = [
      {
        'Subsets/Score': 'Auditory Comprehension',
        'Standard Score (50 - 150)': assessmentType == 'Auditory Comprehension' || assessmentType == 'Both'
            ? scores['Auditory Comprehension']!['standardScore'].toString()
            : '',
        'Percentile Rank (1 - 99%)': assessmentType == 'Auditory Comprehension' || assessmentType == 'Both'
            ? scores['Auditory Comprehension']!['percentileRank'].toString()
            : '',
        'Descriptive Range': assessmentType == 'Auditory Comprehension' || assessmentType == 'Both'
            ? scores['Auditory Comprehension']!['descriptiveRange'].toString()
            : '',
      },
      {
        'Subsets/Score': 'Expressive Communication',
        'Standard Score (50 - 150)': assessmentType == 'Expressive Communication' || assessmentType == 'Both'
            ? scores['Expressive Communication']!['standardScore'].toString()
            : '',
        'Percentile Rank (1 - 99%)': assessmentType == 'Expressive Communication' || assessmentType == 'Both'
            ? scores['Expressive Communication']!['percentileRank'].toString()
            : '',
        'Descriptive Range': assessmentType == 'Expressive Communication' || assessmentType == 'Both'
            ? scores['Expressive Communication']!['descriptiveRange'].toString()
            : '',
      },
      {
        'Subsets/Score': 'Total Language Score',
        'Standard Score (50 - 150)': assessmentType == 'Both'
            ? scores['Total Language Score']!['standardScore'].toString()
            : '',
        'Percentile Rank (1 - 99%)': assessmentType == 'Both'
            ? scores['Total Language Score']!['percentileRank'].toString()
            : '',
        'Descriptive Range': assessmentType == 'Both'
            ? scores['Total Language Score']!['descriptiveRange'].toString()
            : '',
      },
    ];

    String? pls5AuditoryComprehensionSummary = assessmentType == 'Auditory Comprehension' || assessmentType == 'Both'
        ? _generateAuditoryComprehensionSummary()
        : null;

    String? pls5ExpressiveCommunicationSummary = assessmentType == 'Expressive Communication' || assessmentType == 'Both'
        ? _generateExpressiveCommunicationSummary()
        : null;

    String? pls5TotalLanguageScoreSummary = assessmentType == 'Both'
        ? _generateTotalLanguageScoreSummary()
        : null;

    ActivityForms assessmentResults = ActivityForms(
      formType: 'PLS-5',
      name: '',
      date: DateTime.now(),
      pls5Rows: pls5Rows,
      activityFormName: '',
      formStatus: '',
      age: 0,
      dateCreated: DateTime.now(),
      dateModified: DateTime.now(),
      activityBoards: selectedBoardName.isNotEmpty ? [selectedBoardName] : [],
      pls5AuditoryComprehensionSummary: pls5AuditoryComprehensionSummary ?? '',
      pls5ExpressiveCommunicationSummary: pls5ExpressiveCommunicationSummary ?? '',
      pls5TotalLanguageScoreSummary: pls5TotalLanguageScoreSummary ?? '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePLS5Form_Widget(
          initialData: assessmentResults,
        ),
      ),
    );
    });
  }

  Future<String> _getBoardNameById(String? boardId) async {
    if (boardId == null) return "No board selected";

    try {
      DocumentSnapshot boardDoc = await FirebaseFirestore.instance
          .collection('board')
          .doc(boardId)
          .get();

      if (boardDoc.exists) {
        return boardDoc['name'] ?? "Unnamed Board";
      } else {
        return "Board not found";
      }
    } catch (e) {
      print("Error fetching board name: $e");
      return "Error fetching board name";
    }
  }

  String _generateAuditoryComprehensionSummary() {
    String descriptiveRange = scores['Auditory Comprehension']?['descriptiveRange'] ?? '';
    List<String> allWords = selectedWords;
    List<String> correctWords = assessmentResults
        .where((result) => result['correct'] == true)
        .map((result) => result['word'] as String)
        .toList();
    List<String> incorrectWords = assessmentResults
        .where((result) => result['correct'] == false)
        .map((result) => result['word'] as String)
        .toList();

    String summary = 'The child has shown ';

    switch (descriptiveRange) {
      case 'Very Superior':
        summary += 'great Auditory Comprehension for their age, ';
        break;
      case 'Superior':
        summary += 'good Auditory Comprehension for their age, ';
        break;
      case 'Above Average':
        summary += 'decent Auditory Comprehension for their age, ';
        break;
      case 'Average':
        summary += 'an average Auditory Comprehension for their age, ';
        break;
      case 'Below Average':
        summary += 'to have fallen a bit short with their Auditory Comprehension for their age, ';
        break;
      case 'Poor':
        summary += 'to have poor Auditory Comprehension for their age, ';
        break;
      case 'Very Poor':
        summary += 'to have Very Poor Auditory Comprehension for their age, ';
        break;
    }

    summary += 'assessed with the words ${allWords.join(", ")}, ';

    switch (descriptiveRange) {
      case 'Very Superior':
        summary += 'they were pronounced flawlessly, and their delivery was overall among the best their age. ';
        break;
      case 'Superior':
        summary += 'they were pronounced with little to no hesitation, and their delivery was a clear cut above the rest. ';
        break;
      case 'Above Average':
        summary += 'they were pronounced with a hint of hesitation, but nonetheless their delivery overall was modest. ';
        break;
      case 'Average':
        summary += 'they were pronounced with some hesitation, and their delivery overall is of no problem. ';
        break;
      case 'Below Average':
        summary += 'their pronunciation could use more work and so is their delivery. ';
        break;
      case 'Poor':
        summary += 'their pronunciation and overall delivery are of priority for improvement. ';
        break;
      case 'Very Poor':
        summary += 'they are completely behind in terms of pronunciation and overall delivery for their age and it is an absolute must for improvement and progression. ';
        break;
    }

    if (incorrectWords.length == allWords.length) {
      summary += 'They pronounced all words incorrectly. ';
    } else if (incorrectWords.isNotEmpty) {
      summary += 'They pronounced ${incorrectWords.join(", ")} incorrectly ';
      if (correctWords.isNotEmpty) {
        summary += 'and ${correctWords.join(", ")} correctly. ';
      }
    } else {
      summary += 'They pronounced all words correctly. ';
    }

    return summary;
  }

  String _generateExpressiveCommunicationSummary() {
    String descriptiveRange = scores['Expressive Communication']?['descriptiveRange'] ?? '';
    int totalWords = expressiveResults.fold(0, (sum, result) => sum + (result['wordCount'] as int));
    double averageWordsPerQuestion = totalWords / expressiveResults.length;

    String summary = 'The child has demonstrated ';

    switch (descriptiveRange) {
      case 'Very Superior':
        summary += 'exceptional Expressive Communication skills for their age. ';
        break;
      case 'Superior':
        summary += 'strong Expressive Communication skills for their age. ';
        break;
      case 'Above Average':
        summary += 'above-average Expressive Communication skills for their age. ';
        break;
      case 'Average':
        summary += 'age-appropriate Expressive Communication skills. ';
        break;
      case 'Below Average':
        summary += 'slightly below-average Expressive Communication skills for their age. ';
        break;
      case 'Poor':
        summary += 'poor Expressive Communication skills for their age. ';
        break;
      case 'Very Poor':
        summary += 'significantly delayed Expressive Communication skills for their age. ';
        break;
    }

    summary += 'They responded to ${expressiveResults.length} questions with an average of ${averageWordsPerQuestion.toStringAsFixed(1)} words per response. ';

    if (averageWordsPerQuestion > 10) {
      summary += 'Their responses were detailed and elaborate. ';
    } else if (averageWordsPerQuestion > 5) {
      summary += 'Their responses were of moderate length and detail. ';
    } else {
      summary += 'Their responses were brief and could benefit from expansion. ';
    }

    return summary;
  }

  String _generateTotalLanguageScoreSummary() {
    String descriptiveRange = scores['Total Language Score']?['descriptiveRange'] ?? '';

    String summary = 'Overall, the child\'s Total Language Score indicates ';

    switch (descriptiveRange) {
      case 'Very Superior':
        summary += 'exceptional language skills far above their age level. They demonstrate outstanding abilities in both understanding and expressing language, showing potential for advanced linguistic development.';
        break;
      case 'Superior':
        summary += 'language skills significantly above their age level. They show strong capabilities in comprehending and communicating ideas, with potential for accelerated language growth.';
        break;
      case 'Above Average':
        summary += 'language skills above what is typically expected for their age. They exhibit good language understanding and expression, with room for further enhancement of their strong foundation.';
        break;
      case 'Average':
        summary += 'age-appropriate language skills. They show typical development in both receptive and expressive language, meeting the expected milestones for their age group.';
        break;
      case 'Below Average':
        summary += 'language skills slightly below what is expected for their age. While they can communicate basic ideas, there can be improvement in both understanding and expressing more complex language concepts.';
        break;
      case 'Poor':
        summary += 'significant challenges in language skills compared to peers. They may struggle with understanding or expressing more complex ideas and would benefit from targeted language intervention.';
        break;
      case 'Very Poor':
        summary += 'substantial difficulties in language skills, falling far below age expectations. Immediate and intensive language intervention is recommended to address both receptive and expressive language delays.';
        break;
    }

    return summary;
  }

  int _calculateStandardScore(int rawScore, int totalItems, String subset) {
    double percentage = (rawScore / totalItems) * 100;
    if (subset == 'Expressive Communication') {
      if (percentage >= 98) return 150;
      if (percentage >= 85) return 130;
      if (percentage >= 75) return 110;
      if (percentage >= 55) return 90;
      if (percentage >= 35) return 70;
      return 50;
    } else {
      // Auditory Comprehension
      if (percentage >= 98) return 150;
      if (percentage >= 90) return 130;
      if (percentage >= 75) return 110;
      if (percentage >= 50) return 90;
      if (percentage >= 25) return 70;
      return 50;
    }
  }

  int _calculatePercentileRank(int standardScore) {
    if (standardScore >= 135) return 99;
    if (standardScore >= 120) return 95;
    if (standardScore >= 110) return 84;
    if (standardScore >= 90) return 50;
    if (standardScore >= 80) return 16;
    if (standardScore >= 70) return 5;
    return 1;
  }

  String _getDescriptiveRange(int standardScore) {
    if (standardScore >= 135) return 'Very Superior';
    if (standardScore >= 120) return 'Superior';
    if (standardScore >= 110) return 'Above Average';
    if (standardScore >= 90) return 'Average';
    if (standardScore >= 80) return 'Below Average';
    if (standardScore >= 70) return 'Poor';
    return 'Very Poor';
  }

  void _showResultsTable() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Assessment Results'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (assessmentType == 'Auditory Comprehension' || assessmentType == 'Both') ...[
                  Text('Auditory Comprehension Results:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Table(
                    border: TableBorder.all(),
                    columnWidths: const <int, TableColumnWidth>{
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          _buildTableCell('Word', isHeader: true),
                          _buildTableCell('Spoken', isHeader: true),
                          _buildTableCell('Correct', isHeader: true),
                        ],
                      ),
                      for (var result in assessmentResults)
                        TableRow(
                          children: [
                            _buildTableCell(result['word']),
                            _buildTableCell(result['spoken']),
                            _buildTableCell(result['correct'] ? 'Yes' : 'No'),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Auditory Comprehension Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_generateAuditoryComprehensionSummary()),
                  SizedBox(height: 20),
                ],
                if (assessmentType == 'Expressive Communication' || assessmentType == 'Both') ...[
                  Text('Expressive Communication Results:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Table(
                    border: TableBorder.all(),
                    columnWidths: const <int, TableColumnWidth>{
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          _buildTableCell('Question', isHeader: true),
                          _buildTableCell('Response', isHeader: true),
                          _buildTableCell('Words', isHeader: true),
                        ],
                      ),
                      for (var result in expressiveResults)
                        TableRow(
                          children: [
                            _buildTableCell(result['question']),
                            _buildTableCell(result['response']),
                            _buildTableCell(result['wordCount'].toString()),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Expressive Communication Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_generateExpressiveCommunicationSummary()),
                  SizedBox(height: 20),
                ],
                Table(
                  border: TableBorder.all(),
                  columnWidths: const <int, TableColumnWidth>{
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      children: [
                        _buildTableCell('Subsets/Score', isHeader: true),
                        _buildTableCell('Standard Score (50 - 150)',
                            isHeader: true),
                        _buildTableCell('Percentile Rank (1 - 99%)',
                            isHeader: true),
                        _buildTableCell('Descriptive Range', isHeader: true),
                      ],
                    ),
                    for (var subset in scores.keys)
                      TableRow(
                        children: [
                          _buildTableCell(subset),
                          _buildTableCell(
                              scores[subset]!['standardScore'].toString()),
                          _buildTableCell(
                              scores[subset]!['percentileRank'].toString()),
                          _buildTableCell(scores[subset]!['descriptiveRange']),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 20),
                if (assessmentType == 'Both') ...[
                  Text('Total Language Score Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_generateTotalLanguageScoreSummary()),
                  SizedBox(height: 20),
                ],
                Text('Would you like to plot these results in the PLS-5 Form?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPLS5Form();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}