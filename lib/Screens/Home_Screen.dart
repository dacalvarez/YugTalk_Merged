import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gtext/gtext.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yugtalk/Widgets/Drawer_Widget.dart';
import '../Modules/Activity Mode/ActivityMode_Mod.dart';
import '../Modules/Activity Mode/Statistics/Stats_Mod.dart';
import '../Modules/Activity Mode/Statistics/WordUsage.dart';
import 'MeMode_Screen.dart';
import 'EditMode_Screen.dart';

class Home_Mod extends StatefulWidget {
  const Home_Mod({Key? key}) : super(key: key);
  static const routeName = '/home';

  @override
  _Home_ModState createState() => _Home_ModState();
}

class _Home_ModState extends State<Home_Mod>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController editModePasswordController =
      TextEditingController();
  final TextEditingController activityModePasswordController =
      TextEditingController();
  bool _passwordVisible = false;
  List<WordUsage> wordUsages = generateDummyData();
  String _selectedCategory = 'All Categories';
  String _selectedLocation = 'All Locations';
  bool _sortAscending = true;
  int _sortColumnIndex = 0;
  int _locationCount = 0;
  List<Map<String, String>> _userLocations = [];
  StreamSubscription<DocumentSnapshot>? _locationListener;
  late String userID;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupLocationListener();
    _fetchUserLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    editModePasswordController.dispose();
    activityModePasswordController.dispose();
    _locationListener?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserLocations() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
        setState(() {
          _locationCount = 0;
        });
      }
      return;
    }

    try {
      final userSettingsDoc = await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(user.email)
          .get();

      if (!mounted) return;

      if (!userSettingsDoc.exists) {
        setState(() {
          _locationCount = 0;
        });
        return;
      }

      final userLocations =
      userSettingsDoc.data()?['userLocations'] as Map<String, dynamic>?;
      if (userLocations == null) {
        setState(() {
          _locationCount = 0;
        });
        return;
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

      if (mounted) {
        setState(() {
          _userLocations = locationAddresses;
          _locationCount = locationAddresses.length;
        });
      }
    } catch (e) {
      print('Error fetching user locations: $e');
      if (mounted) {
        setState(() {
          _locationCount = 0;
        });
      }
    }
  }


  void _setupLocationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      userID = user.email!;

      _locationListener = FirebaseFirestore.instance
          .collection('userSettings')
          .doc(user.email)
          .snapshots()
          .listen((docSnapshot) {
        if (!mounted) return;

        if (docSnapshot.exists) {
          final userLocations =
          docSnapshot.data()?['userLocations'] as Map<String, dynamic>?;
          if (userLocations != null) {
            int totalLocations = 0;
            userLocations.forEach((key, value) {
              String decodedValue = utf8.decode(base64.decode(value));
              List<dynamic> decodedJson = jsonDecode(decodedValue);
              totalLocations += decodedJson.length;
            });
            if (mounted) {
              setState(() {
                _locationCount = totalLocations;
              });
            }
          }
        }
      }, onError: (error) {
        print('Error listening to location changes: $error');
      });
    }
  }

  Future<void> _authenticate(BuildContext context) async {
    final String password = _tabController.index == 1
        ? editModePasswordController.text.trim()
        : activityModePasswordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: GText('Please fill in the Password field first.')),
      );
      return;
    }

    try {
      String hashedPassword = hashPassword(password);

      QuerySnapshot<Map<String, dynamic>> slpSnapshot = await FirebaseFirestore
          .instance
          .collection('SLP')
          .where('password', isEqualTo: hashedPassword)
          .get();

      QuerySnapshot<Map<String, dynamic>> guardianSnapshot =
          await FirebaseFirestore.instance
              .collection('guardian')
              .where('password', isEqualTo: hashedPassword)
              .get();

      String userType;
      if (slpSnapshot.docs.isNotEmpty) {
        userType = 'SLP';
      } else if (guardianSnapshot.docs.isNotEmpty) {
        userType = 'guardian';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: GText('Invalid password.')),
        );
        return;
      }

      switch (_tabController.index) {
        case 0:
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => MeMode(userID: userID)));
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditMode(userID: userID)),
          );
          break;
        case 2:
          if (userType == 'SLP') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ActivityMode_Mod()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: GText('You do not have access to Activity Mode.')),
            );
          }
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: GText('Error: ${e.toString()}')),
      );
    }
  }

  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GText('Welcome to YugTalk!'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              tabs: [
                Tab(child: _buildTabContent('Me Mode', Icons.person)),
                Tab(child: _buildTabContent('Edit Mode', Icons.edit)),
                Tab(child: _buildTabContent('Activity Mode', Icons.extension)),
              ],
            ),
          ),
        ),
      ),
      drawer: const DrawerWidget(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMeModeContent(),
          _buildEditModeContent(),
          _buildActivityModeContent(),
        ],
      ),
    );
  }

  Widget _buildTabContent(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          GText(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMeModeContent() {
    int wordCount = wordUsages.length;
    int categoryCount = wordUsages.map((w) => w.category).toSet().length;
    int mostUsedCount = wordUsages.where((w) => w.isMostUsed).length;
    int leastUsedCount = wordUsages.where((w) => w.isLeastUsed).length;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/me_mode.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: GText('Start Communication'),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MeMode(userID: userID)));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Center(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard('Words', Icons.text_fields, wordCount),
                    _buildStatCard('Categories', Icons.category, categoryCount),
                    _buildStatCard(
                        'Most Used', Icons.trending_up, mostUsedCount),
                    _buildStatCard(
                        'Least Used', Icons.trending_down, leastUsedCount),
                    _buildStatCard(
                        'Locations', Icons.location_on, _locationCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, IconData icon, int count) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showDetailsDialog(context, title, count),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(isDarkMode ? 0.3 : 0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 40, color: Colors.deepPurple),
            const SizedBox(height: 8),
            GText(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            GText(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*void _showDetailsDialog(BuildContext context, String title, int count) {
    List<WordUsage> filteredWords = _getFilteredWords(title);

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
                        hintText: 'Search...',
                      ),
                      onChanged: (query) {
                        setState(() {
                          filteredWords = _searchWords(query, title);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (title == 'Categories' || title == 'Locations')
                    DropdownButton<String>(
                      value: title == 'Categories'
                          ? _selectedCategory
                          : _selectedLocation,
                      onChanged: (String? newValue) {
                        setState(() {
                          if (title == 'Categories') {
                            _selectedCategory = newValue!;
                          } else {
                            _selectedLocation = newValue!;
                          }
                          filteredWords = _getFilteredWords(title);
                        });
                      },
                      items: title == 'Categories'
                          ? _buildCategoryDropdownItems()
                          : _buildLocationDropdownItems(),
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 16.0,
                    columns: _getColumns(title),
                    rows: filteredWords
                        .map((word) => _getDataRow(word, title))
                        .toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: GText('Exit'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }*/

  void _showDetailsDialog(BuildContext context, String title, int count) {
    List<dynamic> items = _getFilteredItems(title);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GeneralStatsDialog(title: title);
      },
    );
  }

  List<dynamic> _getFilteredItems(String title) {
    switch (title) {
      case 'Words':
      case 'Most Used':
      case 'Least Used':
      case 'Categories':
        return _getFilteredWords(title);
      case 'Locations':
        return _userLocations;
      default:
        return [];
    }
  }

  List<WordUsage> _getFilteredWords(String title) {
    switch (title) {
      case 'Words':
      case 'Most Used':
      case 'Least Used':
      case 'Locations':
        return wordUsages.where((w) {
          bool matchesLocation = _selectedLocation == 'All Locations' ||
              w.datesOfUsage.any((usage) => usage.values.any((lfList) =>
                  lfList.any((lf) =>
                      lf.location.toString().split('.').last.toLowerCase() ==
                      _selectedLocation.toLowerCase())));
          bool matchesCategory = title != 'Categories' ||
              _selectedCategory == 'All Categories' ||
              w.category == _selectedCategory;
          bool matchesUsage = title != 'Most Used' || w.isMostUsed;
          bool matchesLeastUsed = title != 'Least Used' || w.isLeastUsed;
          return matchesLocation &&
              matchesCategory &&
              matchesUsage &&
              matchesLeastUsed;
        }).toList();
      case 'Categories':
        return wordUsages
            .where((w) =>
                _selectedCategory == 'All Categories' ||
                w.category == _selectedCategory)
            .toList();
      default:
        return [];
    }
  }

  List<WordUsage> _searchWords(String query, String title) {
    List<WordUsage> words = _getFilteredWords(title);
    return words
        .where((word) => word.word.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<DataColumn> _getColumns(String title) {
    List<DataColumn> columns = [
      DataColumn(
        label: GText('Word'),
        onSort: (columnIndex, ascending) {
          setState(() {
            _sortColumnIndex = columnIndex;
            _sortAscending = ascending;
            wordUsages.sort((a, b) => ascending
                ? a.word.compareTo(b.word)
                : b.word.compareTo(a.word));
          });
        },
      ),
      DataColumn(
        label: GText('Category'),
        onSort: (columnIndex, ascending) {
          setState(() {
            _sortColumnIndex = columnIndex;
            _sortAscending = ascending;
            wordUsages.sort((a, b) => ascending
                ? a.category.compareTo(b.category)
                : b.category.compareTo(a.category));
          });
        },
      ),
      DataColumn(
        label: GText('Frequency'),
        onSort: (columnIndex, ascending) {
          setState(() {
            _sortColumnIndex = columnIndex;
            _sortAscending = ascending;
            wordUsages.sort((a, b) => ascending
                ? a.dailyFrequency.compareTo(b.dailyFrequency)
                : b.dailyFrequency.compareTo(a.dailyFrequency));
          });
        },
      ),
    ];

    if (title == 'Locations') {
      columns.add(const DataColumn(label: GText('Location')));
    }

    return columns;
  }

  DataRow _getDataRow(WordUsage word, String title) {
    List<DataCell> cells = [
      DataCell(GText(word.word)),
      DataCell(GText(word.category)),
      DataCell(GText(word.dailyFrequency.toString())),
    ];

    if (title == 'Locations') {
      cells.add(DataCell(GText(
          word.datesOfUsage.first.values.first.first.location.toString())));
    }

    return DataRow(cells: cells);
  }

  List<DropdownMenuItem<String>> _buildCategoryDropdownItems() {
    Set<String> categories = wordUsages.map((word) => word.category).toSet();
    List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem(
          value: 'All Categories', child: GText('All Categories')),
    ];
    items.addAll(categories.map((category) =>
        DropdownMenuItem(value: category, child: GText(category))));
    return items;
  }

  List<DropdownMenuItem<String>> _buildLocationDropdownItems() {
    // Implement this method to return location dropdown items
    return [
      const DropdownMenuItem(
          value: 'All Locations', child: GText('All Locations')),
      const DropdownMenuItem(value: 'Home', child: GText('Home')),
      const DropdownMenuItem(value: 'School', child: GText('School')),
      const DropdownMenuItem(value: 'Clinic', child: GText('Clinic')),
    ];
  }

  Widget _buildPasswordContent(String mode, TextEditingController controller) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/${mode.toLowerCase().replaceAll(' ', '_')}.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple
                            .withOpacity(isDarkMode ? 0.3 : 0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GText(
                        'Enter Password',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(controller),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _authenticate(context),
                        child: GText('Enter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditModeContent() {
    return _buildPasswordContent('Edit Mode', editModePasswordController);
  }

  Widget _buildActivityModeContent() {
    return _buildPasswordContent(
        'Activity Mode', activityModePasswordController);
  }

  Widget _buildPasswordField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon:
              Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _passwordVisible = !_passwordVisible;
            });
          },
        ),
      ),
      obscureText: !_passwordVisible,
    );
  }
}
