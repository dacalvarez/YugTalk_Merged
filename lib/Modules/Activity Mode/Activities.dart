import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:gtext/gtext.dart';
import '../CommBoard/BoardDisplay_Mod.dart';
import 'package:just_audio/just_audio.dart';
import 'Activity Forms/ActivityForms.dart';
import 'Activity Forms/CreatePLS5Form_Widget.dart';

class SpeechAssessmentScreen extends StatefulWidget {
  @override
  _SpeechAssessmentScreenState createState() => _SpeechAssessmentScreenState();
}

class _SpeechAssessmentScreenState extends State<SpeechAssessmentScreen> {
  String? selectedBoardId;
  List<String> selectedWords = [];
  double speed = 1.0;
  int repetitions = 1;
  List<String> availableWords = [];
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  int currentWordIndex = 0;
  int correctWords = 0;
  List<Map<String, dynamic>> assessmentResults = [];
  int correctAuditoryComprehension = 0;
  int correctExpressiveCommunication = 0;
  String? userEmail;
  final AudioPlayer audioPlayer = AudioPlayer();
  String assessmentStatus = '';
  List<Map<String, String>> filteredSymbols = [];
  int rawScore = 0;
  int standardScore = 0;
  int percentileRank = 0;
  String descriptiveRange = '';
  Map<String, Map<String, dynamic>> scores = {
    'Auditory Comprehension': {'rawScore': 0, 'standardScore': 0, 'percentileRank': 0, 'descriptiveRange': ''},
    'Expressive Communication': {'rawScore': 0, 'standardScore': 0, 'percentileRank': 0, 'descriptiveRange': ''},
    'Total Language Score': {'standardScore': 0, 'percentileRank': 0, 'descriptiveRange': ''},
  };


  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeStt();
    _getCurrentUserEmail();
  }

  void _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(speed);
  }

  void _initializeStt() async {
    bool available = await speech.initialize();
    if (available) {
      // STT is ready to use
    } else {
      print("The user has denied the use of speech recognition.");
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
          .map((symbol) => symbol.map((key, value) => MapEntry(key, value.toString())))
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
      await audioPlayer.play();
    } catch (e) {
      print("Error playing audio: $e");
      await _speakWord(url.split('/').last.split('.').first);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBoardDropdown(),
              SizedBox(height: 20),
              _buildWordSelection(),
              SizedBox(height: 20),
              _buildSpeedSlider(),
              SizedBox(height: 20),
              _buildRepetitionsInput(),
              SizedBox(height: 20),
              if (selectedBoardId != null)
                BoardDisplay_Mod(
                  boardID: selectedBoardId!,
                  onSymbolSelected: _handleSymbolSelected,
                  selectedSymbols: filteredSymbols, // Here, filteredSymbols should be of type List<Map<String, String>>
                  language: 'English',
                  incrementUsageCount: false,
                  translate: false,
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startAssessment,
                child: GText('Start Assessment'),
              ),
              SizedBox(height: 20),
              _buildAssessmentStatus(), // Add this line
              _buildAssessmentResults(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });
    }
  }

  Widget _buildBoardDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('board')
          .where('ownerID', isEqualTo: userEmail)
          .where('isActivityBoard', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

        List<DropdownMenuItem<String>> boardItems = snapshot.data!.docs
            .map((doc) => DropdownMenuItem(
          value: doc.id,
          child: Text(doc['name'] ?? 'Unnamed Board'),
        ))
            .toList();

        return DropdownButton<String>(
          value: selectedBoardId,
          items: boardItems,
          onChanged: (String? newValue) {
            setState(() {
              selectedBoardId = newValue;
              _fetchAvailableWords();
            });
          },
          hint: GText('Select a board'),
        );
      },
    );
  }

  Widget _buildWordSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GText('Select Words:'),
        Wrap(
          spacing: 8.0,
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
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpeedSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GText('Speed: ${speed.toStringAsFixed(1)}'),
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
        ),
      ],
    );
  }

  Widget _buildRepetitionsInput() {
    return Row(
      children: [
        GText('Repetitions: '),
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
          ),
        ),
      ],
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
      availableWords = wordsSnapshot.docs
          .map((doc) => doc['wordName'] as String)
          .toList();
      selectedWords.clear();
      filteredSymbols.clear();
    });
  }

  void _startAssessment() async {
    if (selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: GText('Please select at least one word')),
      );
      return;
    }

    setState(() {
      currentWordIndex = 0;
      correctWords = 0;
      assessmentResults.clear();
      correctAuditoryComprehension = 0;
      correctExpressiveCommunication = 0;
    });

    _speakAndListen();
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

    // Update status to "Listen..."
    setState(() {
      assessmentStatus = 'Listen...';
    });

    // Speak the word (Auditory Comprehension part)
    for (int i = 0; i < repetitions; i++) {
      if (currentSymbol['wordAudio'] != null && currentSymbol['wordAudio']!.isNotEmpty) {
        await _playAudio(currentSymbol['wordAudio']!);
      } else {
        await _speakWord(currentWord);
      }
      await Future.delayed(Duration(milliseconds: 1000));
    }

    // Update status to "Your turn"
    setState(() {
      assessmentStatus = 'Your turn';
    });

    // Listen for the spoken word (Expressive Communication part)
    bool isListening = await speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          bool isCorrect = result.recognizedWords.toLowerCase() == currentWord.toLowerCase();
          setState(() {
            assessmentResults.add({
              'word': currentWord,
              'spoken': result.recognizedWords,
              'correct': isCorrect,
            });
            if (isCorrect) {
              correctAuditoryComprehension++;
              correctExpressiveCommunication++;
            }
            currentWordIndex++;
            assessmentStatus = '';
          });
          speech.stop();
          _speakAndListen(); // Move to next word
        }
      },
    );

    if (!isListening) {
      print("Couldn't start listening");
      // Handle the error, maybe try to restart the assessment
    }
  }

  Future<void> _speakWord(String word) async {
    await flutterTts.speak(word);
    return flutterTts.awaitSpeakCompletion(true);
  }

  void _finishAssessment() {
    speech.stop();
    setState(() {
      isListening = false;

      // Calculate raw scores
      scores['Auditory Comprehension']!['rawScore'] = correctAuditoryComprehension;
      scores['Expressive Communication']!['rawScore'] = correctExpressiveCommunication;

      // Calculate standard scores, percentile ranks, and descriptive ranges
      for (var subset in ['Auditory Comprehension', 'Expressive Communication']) {
        int rawScore = scores[subset]!['rawScore'];
        int standardScore = _calculateStandardScore(rawScore, selectedWords.length);
        int percentileRank = _calculatePercentileRank(standardScore);
        String descriptiveRange = _getDescriptiveRange(standardScore);

        scores[subset]!['standardScore'] = standardScore;
        scores[subset]!['percentileRank'] = percentileRank;
        scores[subset]!['descriptiveRange'] = descriptiveRange;
      }

      // Calculate Total Language Score
      int totalStandardScore = (scores['Auditory Comprehension']!['standardScore'] +
          scores['Expressive Communication']!['standardScore']) ~/ 2;
      scores['Total Language Score']!['standardScore'] = totalStandardScore;
      scores['Total Language Score']!['percentileRank'] = _calculatePercentileRank(totalStandardScore);
      scores['Total Language Score']!['descriptiveRange'] = _getDescriptiveRange(totalStandardScore);
    });

    _showResultsTable();
  }

  void _navigateToPLS5Form() {
    List<Map<String, String>> pls5Rows = scores.entries.map((entry) {
      return {
        'Subsets/Score': entry.key,
        'Standard Score (50 - 150)': entry.value['standardScore']?.toString() ?? '',
        'Percentile Rank (1 - 99%)': entry.value['percentileRank']?.toString() ?? '',
        'Descriptive Range': entry.value['descriptiveRange']?.toString() ?? '',
      };
    }).toList();

    ActivityForms assessmentResults = ActivityForms(
      formType: 'PLS-5',
      name: '',
      date: DateTime.now(),
      pls5Rows: pls5Rows, activityFormName: '', formStatus: '', age: 0, dateCreated: DateTime.now(), dateModified: DateTime.now(), activityBoards: [],
      // Add other necessary fields
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePLS5Form_Widget(
          initialData: assessmentResults,
        ),
      ),
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
                        _buildTableCell('Standard Score (50 - 150)', isHeader: true),
                        _buildTableCell('Percentile Rank (1 - 99%)', isHeader: true),
                        _buildTableCell('Descriptive Range', isHeader: true),
                      ],
                    ),
                    for (var subset in scores.keys)
                      TableRow(
                        children: [
                          _buildTableCell(subset),
                          _buildTableCell(scores[subset]!['standardScore'].toString()),
                          _buildTableCell(scores[subset]!['percentileRank'].toString()),
                          _buildTableCell(scores[subset]!['descriptiveRange']),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 20),
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

  int _calculateStandardScore(int rawScore, int totalItems) {
    // This is a simplified calculation. Replace with actual normative data conversion.
    double percentageCorrect = rawScore / totalItems;
    return (percentageCorrect * 100).round().clamp(50, 150);
  }

  int _calculatePercentileRank(int standardScore) {
    if (standardScore >= 131) return 99;
    if (standardScore >= 121) return 95;
    if (standardScore >= 111) return 84;
    if (standardScore >= 90) return 50;
    if (standardScore >= 80) return 16;
    if (standardScore >= 70) return 5;
    return 1;
  }

  String _getDescriptiveRange(int standardScore) {
    if (standardScore >= 131) return 'Very Superior';
    if (standardScore >= 121) return 'Superior';
    if (standardScore >= 111) return 'Above Average';
    if (standardScore >= 90) return 'Average';
    if (standardScore >= 80) return 'Below Average';
    if (standardScore >= 70) return 'Poor';
    return 'Very Poor';
  }

  Widget _buildAssessmentStatus() {
    return Visibility(
      visible: assessmentStatus.isNotEmpty,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              assessmentStatus == 'Listen...' ? Icons.hearing : Icons.mic,
              size: 24,
              color: Colors.blue,
            ),
            SizedBox(width: 10),
            GText(
              assessmentStatus,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GText('Assessment Progress:'),
        ...assessmentResults.map((result) => ListTile(
          title: Text(result['word']),
          subtitle: Text('Spoken: ${result['spoken']}'),
          trailing: Icon(
            result['correct'] ? Icons.check : Icons.close,
            color: result['correct'] ? Colors.green : Colors.red,
          ),
        )),
      ],
    );
  }
}