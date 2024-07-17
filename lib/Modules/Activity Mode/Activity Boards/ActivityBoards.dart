class ActivityBoards {
  final String boardName;
  final String boardCategory;
  final List<String> connectedActivityForms;
  final String boardDescription;
  final DateTime dateCreated;
  DateTime dateModified;
  bool isFavorite;

  ActivityBoards({
    required this.boardName,
    required this.boardCategory,
    required this.connectedActivityForms,
    required this.boardDescription,
    required this.dateCreated,
    required this.dateModified,
    this.isFavorite = false,
  });
}

List<ActivityBoards> activityBoardsData = [
  ActivityBoards(
    boardName: 'John Doe (3) Basic Needs Board',
    boardCategory: 'Basic Needs',
    connectedActivityForms: ['PLS-5 Age 3 John Doe'],
    boardDescription:
    'A board designed to help John Doe communicate his basic needs effectively.',
    dateCreated: DateTime(2024, 1, 15),
    dateModified: DateTime(2024, 1, 18),
    isFavorite: true,
  ),
  ActivityBoards(
    boardName: 'Jane Smith (4) Cognitive and Language Development Board',
    boardCategory: 'Cognitive and Language Development',
    connectedActivityForms: ['Brigance Age 4 Jane Smith'],
    boardDescription:
    'A board focused on enhancing Jane Smith\'s cognitive skills and language development.',
    dateCreated: DateTime(2024, 2, 20),
    dateModified: DateTime(2024, 2, 25),
    isFavorite: false,
  ),
  ActivityBoards(
    boardName: 'Kenny Smith (3) Social Interaction Board',
    boardCategory: 'Social Interaction',
    connectedActivityForms: ['Brigance Age 3 Kenny Smith'],
    boardDescription:
    'A board aimed at improving Kenny Smith\'s social interaction and communication with peers.',
    dateCreated: DateTime(2024, 5, 18),
    dateModified: DateTime(2024, 5, 20),
    isFavorite: false,
  ),
  ActivityBoards(
    boardName: 'Wendy Pearson (3) Academic Support Board',
    boardCategory: 'Academic Support',
    connectedActivityForms: ['Brigance Age 3 Wendy Pearson'],
    boardDescription:
    'A board tailored to support Wendy Pearson\'s academic activities and learning processes.',
    dateCreated: DateTime(2024, 5, 17),
    dateModified: DateTime(2024, 5, 19),
    isFavorite: false,
  ),
];