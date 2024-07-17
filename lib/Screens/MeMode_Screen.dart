import 'package:flutter/material.dart';
import '../Modules/CommBoard/CommBoard_Mod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Modules/CommBoard/MoreOptions_Mod.dart';

class MeMode extends StatefulWidget {
  final String userID;

  const MeMode({super.key, required this.userID});

  @override
  State<MeMode> createState() => _MeModeState();
}

class _MeModeState extends State<MeMode> {
  String? mainBoardID;
  List<String> userOwnedBoards = [];
  int lockButtonPressCount = 0;
  int hamburgerButtonPressCount = 0;
  final int requiredPressCount = 3;
  bool incrementUsageCount = true;
  bool translate = false;
  String? currentLanguage;
  final String puzzleQuestion = 'What is 7 x 6?';
  final String puzzleAnswer = '42';

  @override
  void initState() {
    super.initState();
    _fetchMainBoardID();
  }

  Future<void> _fetchMainBoardID() async {
    String userID = widget.userID;

    try {
      QuerySnapshot boardSnapshot = await FirebaseFirestore.instance
          .collection('board')
          .where('ownerID', isEqualTo: userID)
          .get();

      List<QueryDocumentSnapshot> ownedBoards = boardSnapshot.docs;
      List<String> ownedBoardIDs = ownedBoards.map((doc) => doc.id).toList();
      setState(() {
        userOwnedBoards = ownedBoardIDs;
      });

      QuerySnapshot mainBoardSnapshot = await FirebaseFirestore.instance
          .collection('board')
          .where('ownerID', isEqualTo: userID)
          .where('isMain', isEqualTo: true)
          .get();

      if (mainBoardSnapshot.docs.isNotEmpty) {
        setState(() {
          mainBoardID = mainBoardSnapshot.docs.first.id;
        });
        fetchBoardLanguage(mainBoardSnapshot.docs.first.id);
      } else {
        _showSelectBoardDialog();
      }
    } catch (e) {
      print("Error fetching boards: $e");
    }
  }

  Future<void> fetchBoardLanguage(String boardID) async {
    try {
      DocumentSnapshot boardSnapshot = await FirebaseFirestore.instance.collection('board').doc(boardID).get();
      if (boardSnapshot.exists) {
        setState(() {
          currentLanguage = boardSnapshot.get('language');
        });
      }
    } catch (e) {
      print('Error fetching board language: $e');
    }
  }

  void _showSelectBoardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Main Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: userOwnedBoards.map((boardID) {
            return ListTile(
              title: Text(boardID),
              onTap: () {
                setState(() {
                  mainBoardID = boardID;
                });
                fetchBoardLanguage(boardID);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPuzzleDialog(Function onSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents the dialog from being dismissed by tapping outside
      builder: (context) {
        final TextEditingController answerController = TextEditingController();
        return AlertDialog(
          title: const Text('Solve the Puzzle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(puzzleQuestion),
              const SizedBox(height: 20),
              TextField(
                controller: answerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Answer'),
              ),
              const SizedBox(height: 20),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog when Cancel is pressed
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (answerController.text == puzzleAnswer) {
                  Navigator.of(context).pop();
                  onSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Puzzle solved!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect answer, please try again.')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _onLockButtonPressed() {
    setState(() {
      lockButtonPressCount++;
      if (lockButtonPressCount >= requiredPressCount) {
        lockButtonPressCount = 0;  // Reset the press count
        _showPuzzleDialog(() {
          Navigator.of(context).pop();
        });
      }
    });
  }

  void _onHamburgerButtonPressed() {
    setState(() {
      hamburgerButtonPressCount++;
      if (hamburgerButtonPressCount >= requiredPressCount) {
        hamburgerButtonPressCount = 0;  // Reset the press count
        _showPuzzleDialog(() {
          showDialog(
            context: context,
            builder: (context) => MoreOptions(
              translate: translate,
              incrementUsageCount: incrementUsageCount,
              currentLanguage: currentLanguage,
            ),
          ).then((result) {
            if (result != null) {
              setState(() {
                translate = result['translate'];
                incrementUsageCount = result['incrementUsageCount'];
              });
            }
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me Mode'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.lock),
          onPressed: _onLockButtonPressed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _onHamburgerButtonPressed,
          ),
        ],
      ),
      body: mainBoardID != null
          ? CommBoard_Mod(
              boardID: mainBoardID!,
              isEditMode: false,
              incrementUsageCount: incrementUsageCount,
              translate: translate,
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
