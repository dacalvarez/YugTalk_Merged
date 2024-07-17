import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gtext/gtext.dart';
import 'StatsActGraphs_Widget.dart';
import 'StatsWrdGraphs_Widget.dart';
import 'WordUsage.dart';
import '../Activity Forms/ActivityForms.dart';
import '../Activity Forms/CreateBriganceForm_Widget.dart';
import '../Activity Forms/CreatePLS5Form_Widget.dart';
import 'package:intl/intl.dart';

class Stats_Mod extends StatelessWidget {
  const Stats_Mod({super.key});

  @override
  Widget build(BuildContext context) {
    List<WordUsage> wordUsages = generateDummyData();
    List<ActivityForms> activityForms = activityFormsData;

    int mostUsedCount = wordUsages.where((w) => w.isMostUsed).length;
    int leastUsedCount = wordUsages.length - mostUsedCount;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GeneralStats(wordUsages: wordUsages, activityForms: activityForms),
            const SizedBox(height: 15),
            MostUsedWordsStats(
              mostUsedCount: mostUsedCount,
              leastUsedCount: leastUsedCount,
              wordUsages: wordUsages,
            ),
            const SizedBox(height: 25),
            ActivitiesStats(activityForms: activityForms),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}

class LocationFrequency {
  final String location;
  final int frequency;

  LocationFrequency({required this.location, required this.frequency});
}

class MostUsedWordsStats extends StatefulWidget {
  final int mostUsedCount;
  final int leastUsedCount;
  final List<WordUsage> wordUsages;

  const MostUsedWordsStats({
    super.key,
    required this.mostUsedCount,
    required this.leastUsedCount,
    required this.wordUsages,
  });

  @override
  _MostUsedWordsStatsState createState() => _MostUsedWordsStatsState();
}

class _MostUsedWordsStatsState extends State<MostUsedWordsStats>
    with AutomaticKeepAliveClientMixin {
  late List<WordUsage> _filteredMostUsedWords;
  late List<WordUsage> _filteredLeastUsedWords;
  bool _sortAscending = true;
  int _sortColumnIndex = 0;
  String _selectedCategory = 'All Categories';
  String _selectedLocation = 'All Locations';

  @override
  void initState() {
    super.initState();
    _filteredMostUsedWords = _filterMostUsedWords();
    _filteredLeastUsedWords = _filterLeastUsedWords();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoIconButton(
                  count: widget.mostUsedCount.toString(),
                  onPressed: () {
                    _showWordsDialog(context, _filteredMostUsedWords);
                  },
                  title: 'Most Used Words',
                  textColor: textColor,
                ),
                _buildInfoIconButton(
                  count: widget.leastUsedCount.toString(),
                  onPressed: () {
                    _showWordsDialog(context, _filteredLeastUsedWords);
                  },
                  title: 'Least Used Words',
                  textColor: textColor,
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatsWrdGraphs_Widget(
                      wordUsages: widget.wordUsages,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoIconButton({
    required String count,
    required VoidCallback onPressed,
    required String title,
    required Color textColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GText(
          count,
          style: TextStyle(
            //fontSize: 24.0, // Adjusted font size
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GText(
              title,
              style: TextStyle(
                //fontSize: 14.0,
                color: textColor,
              ),
            ),
            const SizedBox(
              width: 4.0,
            ),
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: onPressed,
            ),
          ],
        ),
      ],
    );
  }

  void _showWordsDialog(BuildContext context, List<WordUsage> words) {
    List<WordUsage> filteredWords = List.from(words);
    List<String> searchQueries = [];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search word...',
                      ),
                      onChanged: (query) {
                        setState(() {
                          searchQueries = query.toLowerCase().split(' ');
                          filteredWords = words.where((word) {
                            return searchQueries.every((searchQuery) =>
                                word.word.toLowerCase().contains(searchQuery));
                          }).toList();
                        });
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue!;
                        if (_selectedCategory != 'All Categories') {
                          filteredWords = words
                              .where((word) =>
                                  word.category.toLowerCase() ==
                                  _selectedCategory.toLowerCase())
                              .toList();
                        } else {
                          filteredWords = List.from(words);
                        }
                      });
                    },
                    items: _buildCategoryDropdownItems(words),
                  ),
                  DropdownButton<String>(
                    value: _selectedLocation,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLocation = newValue!;
                        if (_selectedLocation != 'All Locations') {
                          filteredWords = words.where((word) {
                            return word.datesOfUsage.any((usage) => usage.values
                                .any((lfList) => lfList.any((lf) =>
                                    lf.location
                                        .toString()
                                        .split('.')
                                        .last
                                        .toLowerCase() ==
                                    _selectedLocation.toLowerCase())));
                          }).toList();
                        } else {
                          filteredWords = List.from(words);
                        }
                      });
                    },
                    items: _buildLocationDropdownItems(words),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 16.0,
                          headingRowHeight: 56.0,
                          dataRowMaxHeight: 56,
                          dividerThickness: 2,
                          columns: [
                            DataColumn(
                              label: buildSortableHeader(
                                'Word',
                                0,
                                () {
                                  setState(() {
                                    _sortAscending = !_sortAscending;
                                    _sortColumnIndex = 0;
                                    filteredWords.sort((a, b) {
                                      if (_sortAscending) {
                                        return a.word.compareTo(b.word);
                                      } else {
                                        return b.word.compareTo(a.word);
                                      }
                                    });
                                  });
                                },
                              ),
                            ),
                            DataColumn(
                              label: buildSortableHeader(
                                'Category',
                                1,
                                () {
                                  setState(() {
                                    _sortAscending = !_sortAscending;
                                    _sortColumnIndex = 1;
                                    filteredWords.sort((a, b) {
                                      if (_sortAscending) {
                                        return a.category.compareTo(b.category);
                                      } else {
                                        return b.category.compareTo(a.category);
                                      }
                                    });
                                  });
                                },
                              ),
                            ),
                            DataColumn(
                              label: buildSortableHeader(
                                'Frequency',
                                2,
                                () {
                                  setState(() {
                                    _sortAscending = !_sortAscending;
                                    _sortColumnIndex = 2;
                                    filteredWords.sort((a, b) {
                                      if (_sortAscending) {
                                        return a.dailyFrequency
                                            .compareTo(b.dailyFrequency);
                                      } else {
                                        return b.dailyFrequency
                                            .compareTo(a.dailyFrequency);
                                      }
                                    });
                                  });
                                },
                              ),
                            ),
                            DataColumn(
                              label: buildSortableHeader(
                                'Date Range',
                                3,
                                () {
                                  setState(() {
                                    _sortAscending = !_sortAscending;
                                    _sortColumnIndex = 3;
                                    filteredWords.sort((a, b) {
                                      DateTime firstDateA =
                                          a.datesOfUsage.first.keys.first;
                                      DateTime firstDateB =
                                          b.datesOfUsage.first.keys.first;
                                      DateTime lastDateB =
                                          b.datesOfUsage.last.keys.first;
                                      if (_sortAscending) {
                                        return firstDateA.compareTo(firstDateB);
                                      } else {
                                        return lastDateB.compareTo(firstDateA);
                                      }
                                    });
                                  });
                                },
                              ),
                            ),
                            const DataColumn(
                              label: GText('Locations'),
                            ),
                          ],
                          rows: filteredWords
                              .map(
                                (word) => DataRow(
                                  cells: [
                                    DataCell(
                                      GText(word.word),
                                    ),
                                    DataCell(
                                      GText(word.category),
                                    ),
                                    DataCell(
                                      GText(word.dailyFrequency.toString()),
                                    ),
                                    DataCell(
                                      GText(
                                        '${word.datesOfUsage.first.keys.first.toString().split(' ')[0]} - ${word.datesOfUsage.last.keys.first.toString().split(' ')[0]}',
                                      ),
                                    ),
                                    DataCell(
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: _selectedLocation ==
                                                'All Locations'
                                            ? _aggregateLocationFrequencies(
                                                    word, _selectedLocation)
                                                .map((locationFrequency) =>
                                                    GText(
                                                      '${locationFrequency.location}: ${locationFrequency.frequency}',
                                                    ))
                                                .toList()
                                            : _aggregateLocationFrequencies(
                                                    word, _selectedLocation)
                                                .map((locationFrequency) {
                                                if (locationFrequency.location
                                                        .toLowerCase() ==
                                                    _selectedLocation
                                                        .toLowerCase()) {
                                                  return GText(
                                                    '${locationFrequency.location}: ${locationFrequency.frequency}',
                                                  );
                                                } else {
                                                  return const SizedBox();
                                                }
                                              }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    ).then((value) {
      setState(() {
        _selectedCategory = 'All Categories';
        _selectedLocation = 'All Locations';
      });
    });
  }

  List<LocationFrequency> _aggregateLocationFrequencies(
      WordUsage word, String selectedLocation) {
    Map<String, int> locationFrequencies = {};

    for (var usage in word.datesOfUsage) {
      for (var lfList in usage.values) {
        for (var lf in lfList) {
          String location = lf.location.toString().split('.').last;
          int frequency = lf.frequency;
          // Add frequency to existing value if location matches the selected location
          if (selectedLocation == 'All Locations' ||
              location == selectedLocation) {
            locationFrequencies[location] =
                (locationFrequencies[location] ?? 0) + frequency;
          }
        }
      }
    }

    List<LocationFrequency> result = [];
    locationFrequencies.forEach((location, frequency) {
      result.add(LocationFrequency(location: location, frequency: frequency));
    });
    return result;
  }

  List<DropdownMenuItem<String>> _buildCategoryDropdownItems(
      List<WordUsage> words) {
    Set<String> categories = words.map((word) => word.category).toSet();
    List<DropdownMenuItem<String>> items = [];
    items.add(const DropdownMenuItem(
      value: 'All Categories',
      child: GText('All Categories'),
    ));
    items.addAll(categories.map((category) {
      return DropdownMenuItem(
        value: category,
        child: GText(category),
      );
    }).toList());
    return items;
  }

  List<DropdownMenuItem<String>> _buildLocationDropdownItems(
      List<WordUsage> words) {
    Set<String> locations = words
        .expand(
            (word) => word.datesOfUsage.expand((usage) => usage.values.expand(
                  (locationFrequencies) => locationFrequencies
                      .map((lf) => lf.location.toString().split('.').last),
                )))
        .toSet();
    List<DropdownMenuItem<String>> items = [];
    items.add(const DropdownMenuItem(
      value: 'All Locations',
      child: GText('All Locations'),
    ));
    items.addAll(locations.map((location) {
      return DropdownMenuItem(
        value: location,
        child: GText(location),
      );
    }).toList());
    return items;
  }

  Widget buildSortableHeader(
      String label, int columnIndex, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          GText(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Icon(
            _sortColumnIndex == columnIndex
                ? (_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                : null,
          ),
        ],
      ),
    );
  }

  List<WordUsage> _filterMostUsedWords() {
    return widget.wordUsages
        .where((wordUsage) => wordUsage.isMostUsed)
        .toList();
  }

  List<WordUsage> _filterLeastUsedWords() {
    return widget.wordUsages
        .where((wordUsage) => wordUsage.isLeastUsed)
        .toList();
  }
}

class ActivitiesStats extends StatefulWidget {
  final List<ActivityForms> activityForms;

  const ActivitiesStats({super.key, required this.activityForms});

  @override
  _ActivitiesStatsState createState() => _ActivitiesStatsState();
}

class _ActivitiesStatsState extends State<ActivitiesStats> {
  String _popupSearchQuery = '';
  int _toDoCount = 0;
  int _inProgressCount = 0;
  int _successfulCount = 0;
  StreamSubscription<QuerySnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _pls5Subscription;
  StreamSubscription<QuerySnapshot>? _briganceSubscription;
  int _pls5ToDoCount = 0;
  int _pls5InProgressCount = 0;
  int _pls5SuccessfulCount = 0;
  int _briganceToDoCount = 0;
  int _briganceInProgressCount = 0;
  int _briganceSuccessfulCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _pls5Subscription?.cancel();
    _briganceSubscription?.cancel();
    super.dispose();
  }

  void _fetchData() {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;

    if (userEmail == null) {
      return;
    }

    final userQuery = FirebaseFirestore.instance
        .collection('user')
        .where('email', isEqualTo: userEmail);

    _userSubscription?.cancel();
    _userSubscription = userQuery.snapshots().listen((userSnapshot) {
      if (userSnapshot.docs.isNotEmpty) {
        final userId = userSnapshot.docs.first.id;
        _fetchFormCounts(userId);
      }
    });
  }

  void _fetchFormCounts(String userId) {
    final pls5FormRef = FirebaseFirestore.instance
        .collection('user')
        .doc(userId)
        .collection('PLS5Form');
    final briganceFormRef = FirebaseFirestore.instance
        .collection('user')
        .doc(userId)
        .collection('BriganceForm');

    _pls5Subscription?.cancel();
    _briganceSubscription?.cancel();

    _pls5Subscription = pls5FormRef.snapshots().listen((snapshot) {
      _processSnapshot(snapshot, 'PLS-5');
    });

    _briganceSubscription = briganceFormRef.snapshots().listen((snapshot) {
      _processSnapshot(snapshot, 'Brigance');
    });
  }

  void _processSnapshot(QuerySnapshot snapshot, String formType) {
    int toDoCount = 0;
    int inProgressCount = 0;
    int successfulCount = 0;

    for (final doc in snapshot.docs) {
      final formStatus = doc['formStatus'];
      if (formStatus == 'To Do') {
        toDoCount++;
      } else if (formStatus == 'In Progress') {
        inProgressCount++;
      } else if (formStatus == 'Successful') {
        successfulCount++;
      }
    }

    if (mounted) {
      setState(() {
        if (formType == 'PLS-5') {
          _pls5ToDoCount = toDoCount;
          _pls5InProgressCount = inProgressCount;
          _pls5SuccessfulCount = successfulCount;
        } else if (formType == 'Brigance') {
          _briganceToDoCount = toDoCount;
          _briganceInProgressCount = inProgressCount;
          _briganceSuccessfulCount = successfulCount;
        }

        _toDoCount = _pls5ToDoCount + _briganceToDoCount;
        _inProgressCount = _pls5InProgressCount + _briganceInProgressCount;
        _successfulCount = _pls5SuccessfulCount + _briganceSuccessfulCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusContainer('To Do', _toDoCount, context, textColor),
                _buildStatusContainer(
                    'In Progress', _inProgressCount, context, textColor),
                _buildStatusContainer(
                    'Successful', _successfulCount, context, textColor),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatsActGraphs_Widget(
                      activityForms: widget.activityForms,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContainer(
      String status, int count, BuildContext context, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GText(
          count.toString(),
          style: TextStyle(
            //fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GText(
              status,
              style: TextStyle(
                //fontSize: 14.0,
                color: textColor,
              ),
            ),
            const SizedBox(
              width: 4.0,
            ),
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () {
                List<ActivityForms> filteredForms = widget.activityForms
                    .where((form) => form.formStatus == status)
                    .toList();
                _showDetailsDialog(context, status, filteredForms);
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showDetailsDialog(
      BuildContext context, String status, List<ActivityForms> activityForms) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search forms...',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _popupSearchQuery = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchFormsFromFirestore(status),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: GText('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: GText('No forms found.'));
                    } else {
                      List<Map<String, dynamic>> forms = snapshot.data!;
                      List<Map<String, dynamic>> filteredForms = forms
                          .where((form) => form['activityFormName']
                              .toLowerCase()
                              .contains(_popupSearchQuery.toLowerCase()))
                          .toList();
                      final DateFormat dateFormat =
                          DateFormat('yyyy-MM-dd HH:mm');

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredForms.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            Map<String, dynamic> form = filteredForms[index];
                            DateTime? date;
                            if (form['date'] is Timestamp) {
                              date = form['date'].toDate();
                            } else if (form['date'] is String) {
                              date = dateFormat.parse(form['date']);
                            } else {
                              date = null;
                            }
                            return ListTile(
                              title: GText(
                                form['activityFormName'],
                              ),
                              subtitle: GText(
                                'Type: ${form['formType']}\n'
                                'Name: ${form['name']}\n'
                                'Date Created: ${date != null ? dateFormat.format(date) : 'N/A'}\n',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                _navigateToForm(
                                    context, ActivityForms.fromMap(form));
                              },
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: const GText('Exit'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _popupSearchQuery = ''; // Reset the search query
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFormsFromFirestore(
      String status) async {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;

    final userDoc = await FirebaseFirestore.instance
        .collection('user')
        .where('email', isEqualTo: userEmail)
        .limit(1)
        .get();

    if (userDoc.docs.isNotEmpty) {
      final userId = userDoc.docs.first.id;

      final List<Map<String, dynamic>> forms = [];
      final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm');

      final briganceSnapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(userId)
          .collection('BriganceForm')
          .where('formStatus', isEqualTo: status)
          .get();

      for (final doc in briganceSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';

        final activityBoardsValue = data['activity_board_dropdown'];
        final activityBoards = activityBoardsValue is String
            ? activityBoardsValue
            : activityBoardsValue?.toString() ?? '';

        DateTime date = data['date'] != null && data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.now();

        forms.add({
          'formType': 'Brigance',
          'activityFormName': data['activityFormName'] ?? '',
          'activity_board_dropdown': activityBoards,
          'age': int.tryParse(data['age'] ?? '0') ?? 0,
          'briganceRows': data['briganceRows'] ?? [],
          'date': dateFormat.format(date),
          'formStatus': data['formStatus'],
          'gender': data['gender'] ?? '',
          'name': name ?? '',
          'next_steps': data['next_steps'] ?? '',
          'other_comments': data['other_comments'] ?? '',
          'therapist': data['therapist'] ?? '',
        });
      }

      final pls5Snapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(userId)
          .collection('PLS5Form')
          .where('formStatus', isEqualTo: status)
          .get();

      for (final doc in pls5Snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';

        final activityBoardsValue = data['activity_board_dropdown'];
        final activityBoards = activityBoardsValue is String
            ? activityBoardsValue
            : activityBoardsValue?.toString() ?? '';

        DateTime date = data['date'] != null && data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.now();

        forms.add({
          'formType': 'PLS-5',
          'activityFormName': data['activityFormName'] ?? '',
          'activity_board_dropdown': activityBoards,
          'age': int.tryParse(data['age'] ?? '0') ?? 0,
          'auditory_comprehension_summary':
              data['auditory_comprehension_summary'],
          'date': dateFormat.format(date),
          'expressive_communication_summary':
              data['expressive_communication_summary'],
          'formStatus': data['formStatus'] ?? '',
          'gender': data['gender'] ?? '',
          'name': name,
          'next_steps': data['next_steps'] ?? '',
          'other_comments': data['other_comments'] ?? '',
          'pls5Rows': data['pls5Rows'] ?? [],
          'therapist': data['therapist'] ?? '',
          'total_language_score_summary': data['total_language_score_summary'],
        });
      }

      return forms;
    } else {
      return [];
    }
  }

  void _navigateToForm(BuildContext context, ActivityForms form) {
    if (form.formType == 'PLS-5') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePLS5Form_Widget(initialData: form),
        ),
      );
    } else if (form.formType == 'Brigance') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBriganceForm_Widget(initialData: form),
        ),
      );
    }
  }
}

class GeneralStats extends StatelessWidget {
  final List<WordUsage> wordUsages;
  final List<ActivityForms> activityForms;

  const GeneralStats({
    Key? key,
    required this.wordUsages,
    required this.activityForms,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int wordCount = wordUsages.length;
    int categoryCount = wordUsages.map((w) => w.category).toSet().length;

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;

    return FutureBuilder<int>(
      future: getLocationCount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: GText('Error: ${snapshot.error}'));
        } else {
          int locationCount = snapshot.data ?? 0;
          int activityCount = activityForms.length;

          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Container(
              margin: const EdgeInsets.only(top: 20.0),
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: 3,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
                children: [
                  _buildGeneralStatContainer(
                      context, 'Words', wordCount.toString(), textColor),
                  _buildGeneralStatContainer(context, 'Categories',
                      categoryCount.toString(), textColor),
                  _buildGeneralStatContainer(context, 'Locations',
                      locationCount.toString(), textColor),
                  _buildGeneralStatContainer(context, 'Activities',
                      activityCount.toString(), textColor),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Future<int> getLocationCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return 0;
    }

    try {
      final userSettingsDoc = await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(user.email)
          .get();

      if (!userSettingsDoc.exists) {
        return 0;
      }

      final userLocations =
          userSettingsDoc.data()?['userLocations'] as Map<String, dynamic>?;
      if (userLocations == null) {
        return 0;
      }

      int totalLocations = 0;
      userLocations.forEach((key, value) {
        String decodedValue = utf8.decode(base64.decode(value));
        List<dynamic> decodedJson = jsonDecode(decodedValue);
        totalLocations += decodedJson.length;
      });

      return totalLocations;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildGeneralStatContainer(
      BuildContext context, String title, String count, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GText(
            count,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GText(title),
              const SizedBox(width: 4.0),
              IconButton(
                icon: const Icon(Icons.info),
                onPressed: () {
                  _showGeneralStatsDialog(context, title);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGeneralStatsDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GeneralStatsDialog(title: title);
      },
    );
  }
}

class GeneralStatsDialog extends StatefulWidget {
  final String title;

  const GeneralStatsDialog({Key? key, required this.title}) : super(key: key);

  @override
  _GeneralStatsDialogState createState() => _GeneralStatsDialogState();
}

class _GeneralStatsDialogState extends State<GeneralStatsDialog> {
  String _popupSearchQuery = '';
  String _selectedFilter = 'All';
  List<Map<String, String>> filteredItems = [];
  List<Map<String, String>> allItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    if (widget.title == 'Locations') {
      List<Map<String, String>> userLocations = await _fetchUserLocations();
      setState(() {
        allItems = userLocations;
        filteredItems = allItems;
      });
    } else {
      setState(() {
        filteredItems = _filterItems();
      });
    }
  }

  Future<List<Map<String, String>>> _fetchUserLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return [];
    }

    try {
      final userSettingsDoc = await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(user.email)
          .get();

      if (!userSettingsDoc.exists) {
        return [];
      }

      final userLocations =
          userSettingsDoc.data()?['userLocations'] as Map<String, dynamic>?;
      if (userLocations == null) {
        return [];
      }

      List<Map<String, String>> locationAddresses = [];
      userLocations.forEach((key, value) {
        String decodedValue = utf8.decode(base64.decode(value));
        List<dynamic> decodedJson = jsonDecode(decodedValue);
        for (var location in decodedJson) {
          String address = location['address'];
          locationAddresses.add({'type': key, 'address': address});
        }
      });

      return locationAddresses;
    } catch (e) {
      return [];
    }
  }

  void _filterItemsByCategory(String category) {
    setState(() {
      if (category == 'All') {
        filteredItems = allItems
            .where((item) => item['address']!
                .toLowerCase()
                .contains(_popupSearchQuery.toLowerCase()))
            .toList();
      } else {
        filteredItems = allItems
            .where((item) =>
                item['type'] == category &&
                item['address']!
                    .toLowerCase()
                    .contains(_popupSearchQuery.toLowerCase()))
            .toList();
      }
    });
  }

  List<Map<String, String>> _filterItems() {
    List<Map<String, String>> items;
    switch (widget.title) {
      case 'Words':
        items = generateDummyData()
            .map((wordUsage) =>
                {'address': wordUsage.word, 'category': wordUsage.category})
            .toList();
        break;
      case 'Categories':
        items = generateDummyData()
            .map((wordUsage) => {'address': wordUsage.category})
            .toSet()
            .toList();
        break;
      case 'Locations':
        items = allItems;
        break;
      case 'Activities':
        items = activityFormsData
            .map((form) =>
                {'address': form.activityFormName, 'type': form.formType})
            .toList();
        break;
      default:
        items = [];
    }

    return items
        .where((item) => item['address']!
            .toLowerCase()
            .contains(_popupSearchQuery.toLowerCase()))
        .toList();
  }

  Widget _buildFilterDropdown() {
    List<String> filterOptions;
    String filterLabel;

    switch (widget.title) {
      case 'Words':
        filterOptions = ['All'] +
            generateDummyData().map((w) => w.category).toSet().toList();
        filterLabel = 'Category: ';
        break;
      case 'Locations':
        filterOptions = ['All', 'Home', 'School', 'Clinic'];
        filterLabel = 'Location Type: ';
        break;
      case 'Activities':
        filterOptions = ['All', 'PLS-5', 'Brigance'];
        filterLabel = 'Form Type: ';
        break;
      default:
        return const SizedBox.shrink(); // No filter for other types
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        GText(
          filterLabel,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _selectedFilter,
          items: filterOptions.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: GText(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedFilter = newValue!;
              if (widget.title == 'Words') {
                filteredItems = _filterItems()
                    .where((item) =>
                        _selectedFilter == 'All' ||
                        item['category'] == _selectedFilter)
                    .toList();
              } else if (widget.title == 'Activities') {
                filteredItems = _filterItems()
                    .where((item) =>
                        _selectedFilter == 'All' ||
                        item['type'] == _selectedFilter)
                    .toList();
              } else {
                _filterItemsByCategory(_selectedFilter);
              }
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
              ),
              onChanged: (value) {
                setState(() {
                  _popupSearchQuery = value;
                  filteredItems = _filterItems();
                  if (widget.title == 'Words' || widget.title == 'Activities') {
                    filteredItems = filteredItems
                        .where((item) =>
                            _selectedFilter == 'All' ||
                            item['category'] == _selectedFilter ||
                            item['type'] == _selectedFilter)
                        .toList();
                  } else if (widget.title == 'Locations') {
                    _filterItemsByCategory(_selectedFilter);
                  }
                });
              },
            ),
          ),
        ],
      ),
      content: Column(
        children: [
          _buildFilterDropdown(),
          Expanded(
            child: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: widget.title == 'Locations' && filteredItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: GText(filteredItems[index]['address']!),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
          child: const GText('Exit'),
        ),
      ],
    );
  }
}
