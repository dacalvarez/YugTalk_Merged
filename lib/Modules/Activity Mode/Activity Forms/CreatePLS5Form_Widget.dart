import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;
import '../../../Widgets/Drawer_Widget.dart';
import '../Activity Boards/ActivityBoards.dart';
import 'ActivityForms.dart';
import 'Print_UtilsInterface.dart';
import 'Print_Utils.dart';
import 'Rewards.dart';
import 'SpinWheel_Widget.dart';

class CreatePLS5Form_Widget extends StatefulWidget {
  final ActivityForms? initialData;

  const CreatePLS5Form_Widget({super.key, this.initialData});

  @override
  _CreatePLS5Form_WidgetState createState() => _CreatePLS5Form_WidgetState();
}

class _CreatePLS5Form_WidgetState extends State<CreatePLS5Form_Widget> {
  List<List<TextEditingController>> textControllers = [];
  final _formKey = GlobalKey<FormBuilderState>();
  String _selectedStatus = 'To Do';
  String _selectedActivityBoard = '';
  final GlobalKey<_PLS5TableState> pls5TableKey = GlobalKey<_PLS5TableState>();

  @override
  void initState() {
    super.initState();
    _initializeTextControllers();
    _selectedStatus = widget.initialData?.formStatus ?? 'To Do';

    if (widget.initialData?.activityBoards != null) {
      _selectedActivityBoard = widget.initialData!.activityBoards.join(', ');
    }
  }

  void _initializeTextControllers() {
    if (widget.initialData != null &&
        widget.initialData!.pls5Rows.isNotEmpty) {
      textControllers = widget.initialData!.pls5Rows.map((row) {
        return [
          TextEditingController(text: row['Subsets/Score'] ?? ''),
          TextEditingController(text: row['Standard Score (#)'] ?? ''),
          TextEditingController(text: row['Percentile Rank (%)'] ?? ''),
          TextEditingController(text: row['Descriptive Range (average/below average)'] ?? ''),
        ];
      }).toList();
    } else {
      textControllers = [
        [
          TextEditingController(text: 'Auditory Comprehension'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        [
          TextEditingController(text: 'Expressive Communication'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        [
          TextEditingController(text: 'Total Language Score'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
      ];
    }
  }


  /*@override
  void dispose() {
    for (var row in textControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }*/

  Future<void> _saveAsPDF(BuildContext context) async {
    final PrintUtilsInterface printUtils = PrintUtils();

    try {
      final pdf = await _generatePdf(_selectedActivityBoard);
      if (pdf.document.pdfPageList.pages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF. Please try again.')),
        );
        return;
      }
      await printUtils.savePdf(context, pdf, 'YugTalk - Modified PLS5 Form.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveAsExcel(BuildContext context) async {
    try {
      final bytes = await _generateExcel(_selectedActivityBoard);
      final PrintUtilsInterface printUtils = PrintUtils();
      await printUtils.saveExcel(context, bytes, 'YugTalk - Modified PLS5 Form.xlsx');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: ${e.toString()}')),
      );
    }
  }

  Future<pw.Document> _generatePdf(String selectedActivityBoard) async {
    final pdf = pw.Document();

    if (_formKey.currentState?.saveAndValidate() ?? false) {
      Map<String, dynamic> formData = _formKey.currentState!.value;
      final robotoBold =
      pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));
      final robotoRegular =
      pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
      String formattedDate = formData['date'] != null ? DateFormat('yyyy-MM-dd')
          .format(formData['date']) : DateFormat('yyyy-MM-dd').format(
          DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context context) {
            if (context.pageNumber == 1) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('YugTalk’s Modified PLS-5 Activity Form',
                      style: pw.TextStyle(font: robotoBold, fontSize: 20)),
                ],
              );
            } else {
              return pw.Container();
            }
          },
          footer: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            );
          },
          build: (pw.Context context) => [
            pw.Header(
                level: 0,
                child: pw.Container()),
            pw.Text('Patient Information:',
                style: pw.TextStyle(font: robotoBold, fontSize: 12)),
            pw.Text(
                'Name: ${formData['name'] ?? 'John Doe'}',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.Text('Age: ${formData['age'] ?? '5'}',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.Text('Gender: ${formData['gender'] ?? 'Male'}',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.Text('Therapist: ${formData['therapist'] ?? 'Trish Corpus'}',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.Text(
                'Date: $formattedDate',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('Form Title: ${formData['activityFormName'] ??
                'Modified PLS5 Activity Form'}',
                style: pw.TextStyle(font: robotoBold, fontSize: 12)),
            pw.Text('Form Status: $_selectedStatus',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.Text('Activity Board: $selectedActivityBoard',
                style: pw.TextStyle(font: robotoRegular, fontSize: 12)),
            pw.SizedBox(height: 8),
            _buildTable(robotoBold, robotoRegular),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),
            _buildSummarySection(
                'Auditory Comprehension Summary',
                formData['auditory_comprehension_summary'] ?? 'Nothing worthy to mention',
                robotoBold,
                robotoRegular),
            pw.SizedBox(height: 8),
            _buildSummarySection(
                'Expressive Communication Summary',
                formData['expressive_communication_summary'] ?? 'Nothing worthy to mention',
                robotoBold,
                robotoRegular),
            pw.SizedBox(height: 8),
            _buildSummarySection(
                'Total Language Score Summary',
                formData['total_language_score_summary'] ?? 'Nothing worthy to mention',
                robotoBold,
                robotoRegular),
            pw.Divider(),
            pw.SizedBox(height: 8),
            _buildSummarySection('Other Comments',
                formData['other_comments'] ?? 'Nothing worthy to mention',
                robotoBold,
                robotoRegular),
            pw.SizedBox(height: 8),
            _buildSummarySection('Next Steps',
                formData['next_steps'] ?? 'No further steps required',
                robotoBold,
                robotoRegular),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                  'Disclaimer: YugTalk is an experimental AAC app for therapy purposes.',
                  style: pw.TextStyle(font: robotoRegular, fontSize: 8)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form is not valid. Please check the inputs')),
      );

    }
    return pdf;
  }

  pw.Widget _buildSummarySection(String title, String content, pw.Font titleFont, pw.Font contentFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: titleFont, fontSize: 12)),
        if (content.trim().isNotEmpty)
          pw.Text(content, style: pw.TextStyle(font: contentFont, fontSize: 12))
        else
          pw.SizedBox(height: 24),
      ],
    );
  }

  Future<List<int>> _generateExcel(String selectedActivityBoard) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    if (_formKey.currentState?.saveAndValidate() ?? false) {
      Map<String, dynamic> formData = _formKey.currentState!.value;
      sheet
          .getRangeByName('A1')
          .columnWidth = 35;
      sheet
          .getRangeByName('B1')
          .columnWidth = 18;
      sheet
          .getRangeByName('C1')
          .columnWidth = 18;
      sheet
          .getRangeByName('D1')
          .columnWidth = 40;
      sheet.getRangeByName('A1:D1').merge();
      sheet.getRangeByName('A1').setText('PLS-5 Activity Form');
      sheet
          .getRangeByName('A1')
          .cellStyle
          .hAlign = HAlignType.center;
      sheet
          .getRangeByName('A1')
          .cellStyle
          .bold = true;
      sheet.getRangeByName('A2:B2').merge();
      sheet.getRangeByName('A2').setText('Patient Information');
      sheet
          .getRangeByName('A2')
          .cellStyle
          .hAlign = HAlignType.center;
      sheet
          .getRangeByName('A2')
          .cellStyle
          .bold = true;
      sheet.getRangeByName('A3').setText('Name');
      sheet.getRangeByName('B3').setText(formData['name'] ?? 'John Doe');
      sheet.getRangeByName('A4').setText('Age');
      sheet.getRangeByName('B4').setText(formData['age'] ?? '5');
      sheet.getRangeByName('A5').setText('Gender');
      sheet.getRangeByName('B5').setText(formData['gender'] ?? 'Male');
      sheet.getRangeByName('A6').setText('Therapist');
      sheet.getRangeByName('B6').setText(formData['therapist'] ?? 'Trish Corpus');
      sheet.getRangeByName('A7').setText('Date');
      String formattedDate = formData['date'] != null ? DateFormat('yyyy-MM-dd').format(formData['date']) : DateFormat('yyyy-MM-dd').format(DateTime.now());
      sheet.getRangeByName('B7').setText(formattedDate);
      sheet.getRangeByName('A9').setText('Form Title');
      sheet
          .getRangeByName('B9')
          .setText(formData['activityFormName'] ?? 'Modified PLS5 Activity Form');
      sheet.getRangeByName('A10').setText('Form Status');
      sheet.getRangeByName('B10').setText(_selectedStatus);
      sheet.getRangeByName('A11').setText('Activity Board');
      sheet
          .getRangeByName('B11')
          .setText(selectedActivityBoard);

      sheet.getRangeByName('A13').setText('Subsets/Score');
      sheet.getRangeByName('B13').setText('Standard Score (#)');
      sheet.getRangeByName('C13').setText('Percentile Rank (%)');
      sheet
          .getRangeByName('D13')
          .setText('Descriptive Range (average/below average)');
      sheet.getRangeByName('A13:D13').cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByName('A13:D13').cellStyle.bold = true;
      sheet.getRangeByName('A13:D13').cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByName('A13:D13').cellStyle.borders.all.color = '#000000';

      sheet.getRangeByName('A14').setText('Auditory Comprehension');
      sheet.getRangeByName('B14').setText(
          '${widget.initialData?.pls5AuditoryComprehensionStandardScore}');
      sheet.getRangeByName('C14').setText(
          '${widget.initialData?.pls5AuditoryComprehensionPercentileRank}');
      sheet.getRangeByName('D14').setText(
          '${widget.initialData?.pls5AuditoryComprehensionDescriptiveRange}');

      sheet.getRangeByName('A15').setText('Expressive Communication');
      sheet.getRangeByName('B15').setText(
          '${widget.initialData?.pls5ExpressiveCommunicationStandardScore}');
      sheet.getRangeByName('C15').setText(
          '${widget.initialData?.pls5ExpressiveCommunicationPercentileRank}');
      sheet.getRangeByName('D15').setText(
          '${widget.initialData?.pls5ExpressiveCommunicationDescriptiveRange}');

      sheet.getRangeByName('A14').setText('Total Language Score');
      sheet
          .getRangeByName('B14')
          .setText(
          '${widget.initialData?.pls5TotalLanguageScoreStandardScore}');
      sheet
          .getRangeByName('C14')
          .setText(
          '${widget.initialData?.pls5TotalLanguageScorePercentileRank}');
      sheet.getRangeByName('D1').setText(
          '${widget.initialData?.pls5TotalLanguageScoreDescriptiveRange}');

      sheet.getRangeByName('A18').setText('Auditory Comprehension Summary');
      sheet
          .getRangeByName('B18')
          .setText('${formData['auditory_comprehension_summary'] ?? 'Nothing worthy to mention'
          }');
      sheet.getRangeByName('A19').setText('Expressive Communication Summary');
      sheet
          .getRangeByName('B19')
          .setText('${formData['expressive_communication_summary'] ?? 'Nothing worthy to mention'
          }');
      sheet.getRangeByName('A20').setText('Total Language Score Summary');
      sheet
          .getRangeByName('B20')
          .setText('${formData['total_language_score_summary'] ?? 'Nothing worthy to mention'
          }');
      sheet.getRangeByName('A21').setText('Other Comments');
      sheet
          .getRangeByName('B21')
          .setText(formData['other_comments'] ?? 'Nothing worthy to mention');
      sheet.getRangeByName('A22').setText('Next Steps');
      sheet.getRangeByName('B22').setText(formData['next_steps'] ?? 'No further steps required');

      for (int rowIndex = 0; rowIndex < textControllers.length; rowIndex++) {
        for (int colIndex = 0;
        colIndex < textControllers[rowIndex].length;
        colIndex++) {
          Range cell = sheet.getRangeByIndex(rowIndex + 14, colIndex + 1);
          cell.setText(textControllers[rowIndex][colIndex].text);
          cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
          cell.cellStyle.borders.all.color = '#000000';
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form is not valid. Please check the inputs')),
      );
      return [];
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  pw.Widget _buildTable(pw.Font headerFont, pw.Font cellFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black),
      children: [
        pw.TableRow(
          children: [
            _buildTableHeaderCell('Subsets/Score', headerFont),
            _buildTableHeaderCell('Standard Score (#)', headerFont),
            _buildTableHeaderCell('Percentile Rank (%)', headerFont),
            _buildTableHeaderCell(
                'Descriptive Range\n(average/below average)', headerFont),
          ],
        ),
        ...List.generate(
          textControllers.length,
              (rowIndex) => pw.TableRow(
            children: List.generate(
              textControllers[rowIndex].length,
                  (colIndex) => _buildTableCell(
                  textControllers[rowIndex][colIndex].text, cellFont),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeaderCell(String text, pw.Font headerFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8.0),
      child: pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: headerFont,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font cellFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8.0),
      child: pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: cellFont, fontSize: 12),
        ),
      ),
    );
  }

  void _showSaveOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Export as PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _saveAsPDF(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Export as Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _saveAsExcel(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleSave(List<List<TextEditingController>> textControllers) {
    setState(() {
      this.textControllers = textControllers;
    });
  }

  void _handleActivityBoardChanged(String newValue) {
    setState(() {
      _selectedActivityBoard = newValue;
    });
  }

  void _updateSelectedStatus(String newStatus) {
    setState(() {
      _selectedStatus = newStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PLS-5 Form'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.stars),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SpinWheel_Widget(rewards: defaultRewards),
                ),
              );
            },
          ),
          SetStatus(
            initialStatus: _selectedStatus,
            onChanged: _updateSelectedStatus
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: const DrawerWidget(),
      body: FormBuilder(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              patientInfo(initialData: widget.initialData),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormBuilderTextField(
                        name: 'activityFormName',
                        initialValue: widget.initialData?.activityFormName ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ActivityBoardDropdown(
                              initialValue: widget.initialData?.activityBoards.isNotEmpty == true
                                  ? widget.initialData!.activityBoards.first
                                  : '',
                              onChanged: _handleActivityBoardChanged,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              // Add navigation logic to the activity board page here in the future
                            },
                            child: const Text('Go to Activity Board'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PLS5Table(
                        key: pls5TableKey,
                        initialData: widget.initialData,
                          onSave: _handleSave,
                      ),
                      const SizedBox(height: 20),
                      FormBuilderTextField(
                        name: 'auditory_comprehension_summary',
                        initialValue: widget.initialData?.pls5AuditoryComprehensionSummary ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Auditory Comprehension Summary:',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 25),
                      FormBuilderTextField(
                        name: 'expressive_communication_summary',
                        initialValue: widget.initialData?.pls5ExpressiveCommunicationSummary ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Expressive Communication Summary:',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 25),
                      FormBuilderTextField(
                        name: 'total_language_score_summary',
                        initialValue: widget.initialData?.pls5TotalLanguageScoreSummary ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Total Language Score Summary:',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 25),
                      FormBuilderTextField(
                        name: 'other_comments',
                        initialValue: widget.initialData?.pls5OtherComments ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Other Comments:',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 25),
                      FormBuilderTextField(
                        name: 'next_steps',
                        initialValue: widget.initialData?.nextSteps ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Next Steps:',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      SavePrintButtons(
                        formData: widget.initialData,
                        textControllers: textControllers,
                        formKey: _formKey,
                        selectedStatus: _selectedStatus,
                        onShowSaveOptions: _showSaveOptions,
                        onStatusChanged: _updateSelectedStatus,
                        pls5TableKey: pls5TableKey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityBoardDropdown extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;

  const ActivityBoardDropdown({
    Key? key,
    this.initialValue = '',
    required this.onChanged,
  }) : super(key: key);

  @override
  _ActivityBoardDropdownState createState() => _ActivityBoardDropdownState();
}

class _ActivityBoardDropdownState extends State<ActivityBoardDropdown> {
  late String _selectedActivityBoard;

  @override
  void initState() {
    super.initState();
    _selectedActivityBoard = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderDropdown(
      name: 'activity_board_dropdown',
      initialValue: _selectedActivityBoard,
      decoration: const InputDecoration(
        labelText: 'Activity Board',
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      onChanged: (newValue) {
        setState(() {
          _selectedActivityBoard = newValue.toString();
        });
        widget.onChanged(newValue.toString());
      },
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text(
            'Select Activity Board',
            style: TextStyle(fontSize: 14),
          ),
        ),
        ...activityBoardsData
            .map((activityBoard) => DropdownMenuItem(
              value: activityBoard.boardName,
              child: Text(
                activityBoard.boardName,
                style: const TextStyle(fontSize: 14),
              ),
            ))
        .toList(),
      ],
    );
  }
}

class PLS5Table extends StatefulWidget {
  final ActivityForms? initialData;
  final Function(List<List<TextEditingController>>) onSave;
  final FocusNode? initialFocusNode;

  const PLS5Table({super.key, this.initialData, required this.onSave, this.initialFocusNode});

  @override
  _PLS5TableState createState() => _PLS5TableState();
}

class _PLS5TableState extends State<PLS5Table> {
  List<List<TextEditingController>> textControllers = [];
  List<List<FocusNode>> focusNodes = [];
  late FocusNode _initialFocusNode;

  @override
  void initState() {
    super.initState();
    _initializeTextControllers();
    _initializeFocusNodes();
    _initialFocusNode = widget.initialFocusNode ?? focusNodes[0][0];
  }

  void _initializeFocusNodes() {
    focusNodes = List.generate(textControllers.length, (i) {
      return List.generate(textControllers[i].length, (j) {
        var focusNode = FocusNode();
        focusNode.addListener(() {
          if (!focusNode.hasFocus) {
          widget.onSave(textControllers);
          }
        });
        return focusNode;
      });
    });
  }

  void _initializeTextControllers() {
    if (widget.initialData != null &&
        widget.initialData!.pls5Rows.isNotEmpty) {
      textControllers = widget.initialData!.pls5Rows.map((row) {
        return [
          TextEditingController(text: row['Subsets/Score'] ?? ''),
          TextEditingController(text: row['Standard Score (#)'] ?? ''),
          TextEditingController(text: row['Percentile Rank (%)'] ?? ''),
          TextEditingController(text: row['Descriptive Range (average/below average)'] ?? ''),
        ];
      }).toList();
    } else {
      textControllers = [
        [
          TextEditingController(text: 'Auditory Comprehension'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        [
          TextEditingController(text: 'Expressive Communication'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        [
          TextEditingController(text: 'Total Language Score'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
      ];
    }
  }

  void resetTable() {
    setState(() {
      _initializeFocusNodes();
      FocusScope.of(context).unfocus();
      textControllers = [
        [
          TextEditingController(text: 'Auditory Comprehension'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        [
          TextEditingController(text: 'Expressive Communication'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        [
          TextEditingController(text: 'Total Language Score'),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
      ];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNodes.isNotEmpty && focusNodes[0].isNotEmpty) {
        FocusScope.of(context).requestFocus(focusNodes[0][0]);
      }
    });
  }

  @override
  void dispose() {
    for (var row in textControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    _initialFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: FocusScopeNode(),
      autofocus: true,
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: Colors.black),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FractionColumnWidth(0.25),
            1: FractionColumnWidth(0.25),
            2: FractionColumnWidth(0.25),
            3: FractionColumnWidth(0.25),
          },
          children: [
            const TableRow(
              children: [
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        'Subsets/Score',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        'Standard Score (#)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        'Percentile Rank (%)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        'Descriptive Range\n(average/below average)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ...List.generate(
              textControllers.length,
                  (rowIndex) => TableRow(
                children: List.generate(
                  textControllers[rowIndex].length,
                      (colIndex) => TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: TextFormField(
                          controller: textControllers[rowIndex][colIndex],
                          focusNode: focusNodes[rowIndex][colIndex],
                          autofocus: rowIndex == 0 && colIndex == 0,
                          textAlign: TextAlign.center,
                          maxLines: null,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(8.0),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class patientInfo extends StatelessWidget {
  final ActivityForms? initialData;

  const patientInfo({super.key, this.initialData});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: FormBuilderTextField(
              name: 'name',
              initialValue: initialData != null
                  ? initialData!.name
                  : '',
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FormBuilderTextField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              name: 'age',
              initialValue: initialData?.age.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Age',
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FormBuilderDropdown(
              name: 'gender',
              initialValue: initialData?.gender ?? '',
              decoration: const InputDecoration(
                labelText: 'Gender',
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              items: ['Male', 'Female']
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(
                          gender,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FormBuilderTextField(
              name: 'therapist',
              initialValue: initialData?.therapist ?? '',
              decoration: const InputDecoration(
                labelText: 'Therapist',
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FormBuilderDateTimePicker(
              name: 'date',
              initialValue: initialData?.date ?? DateTime.now(),
              decoration: const InputDecoration(
                labelText: 'Date',
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              inputType: InputType.date,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class SetStatus extends StatefulWidget {
  final String initialStatus;
  final void Function(String) onChanged;

  const SetStatus({
    Key? key,
    required this.initialStatus,
    required this.onChanged,
  }) : super(key: key);

  @override
  _SetStatusState createState() => _SetStatusState();
}

class _SetStatusState extends State<SetStatus> {
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  void didUpdateWidget(covariant SetStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      setState(() {
        _selectedStatus = widget.initialStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: 'formStatus',
      builder: (FormFieldState<String?> field) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.15,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FormBuilderDropdown<String>(
                    key: ValueKey(_selectedStatus),
                    name: 'formStatus',
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedStatus = newValue!;
                        field.didChange(newValue);
                        widget.onChanged(newValue);
                      });
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return <String>['To Do', 'In Progress', 'Successful']
                          .map<Widget>((String value) {
                        return Text(
                          value,
                          style: TextStyle(
                            color: _getStatusColor(value),
                            fontSize: 16,
                          ),
                        );
                      }).toList();
                    },
                    items: <String>['To Do', 'In Progress', 'Successful']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: _getStatusColor(value),
                            fontSize: 16,
                          ),
                        ),
                      );
                    }).toList(),
                    dropdownColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.blue;
      case 'In Progress':
        return const Color.fromARGB(255, 255, 145, 0);
      case 'Successful':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}

class SavePrintButtons extends StatefulWidget {
  final ActivityForms? formData;
  final List<List<TextEditingController>> textControllers;
  final GlobalKey<FormBuilderState> formKey;
  final String selectedStatus;
  final void Function(BuildContext) onShowSaveOptions;
  final void Function(String) onStatusChanged;
  final GlobalKey<_PLS5TableState> pls5TableKey;

  const SavePrintButtons({
    required this.formData,
    required this.textControllers,
    required this.formKey,
    required this.selectedStatus,
    required this.onShowSaveOptions,
    required this.onStatusChanged,
    required this.pls5TableKey,
    super.key,
  });

  void onDataFetched(List<List<TextEditingController>> updatedControllers) {
    textControllers.clear();
    textControllers.addAll(updatedControllers);
  }

  @override
  _SavePrintButtonsState createState() => _SavePrintButtonsState();
}

class _SavePrintButtonsState extends State<SavePrintButtons>{
  DateTime? lastSaveTime;
  bool _isLoading = false;
  final GlobalKey<_DropdownHistoryState> _dropdownHistoryKey = GlobalKey<_DropdownHistoryState>();

  @override
  void initState() {
    super.initState();
    if (widget.formData?.name != null) {
      _dropdownHistoryKey.currentState?._fetchDates();
    }
  }

  @override
  void didUpdateWidget(SavePrintButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formData?.name != oldWidget.formData?.name) {
      _dropdownHistoryKey.currentState?._fetchDates();
    }
  }

  Map<String, dynamic> _getFormData() {
    final formData = widget.formKey.currentState?.value ?? {};
    final tableData = widget.textControllers
          .map((textControllers) => {
          'Subsets/Score': textControllers[0].text,
          'Standard Score (#)': textControllers[1].text,
          'Percentile Rank (%)': textControllers[2].text,
          'Descriptive Range (average/below average)': textControllers[3].text,
      }).toList();

      return {
        ...formData,
        'pls5Rows': tableData,
        'formStatus': widget.selectedStatus,
      };
  }

  Future<List<Map<String, dynamic>>> _fetchDates(String name) async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: userEmail)
          .get();

      if (querySnapshot.size == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found with the logged-in email')),
        );
        return [];
      }

      final userDocumentId = querySnapshot.docs.first.id;

      final pls5QuerySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(userDocumentId)
          .collection('PLS5Form')
          .where('name', isEqualTo: name)
          .get();

      return pls5QuerySnapshot.docs
          .map((doc) {
        final data = doc.data();
        final date = data['date'];
        final status = data['formStatus'];
        final docName = data['name'];
        return date != null
            ? {'date': (date as Timestamp).toDate(), 'status': status, 'name': docName}
            : null;
      })
          .where((date) => date != null)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred when trying to fetch dates: $e')),
      );
      return [];
    }
  }

  Future<void> saveToFirestore() async {
    if (lastSaveTime != null && DateTime.now().difference(lastSaveTime!) < const Duration(seconds: 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Currently saving the previous save. Please wait')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (!widget.formKey.currentState!.saveAndValidate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete the form before saving')),
        );
        return;
      }

      DateTime selectedDate = widget.formKey.currentState!.value['date'];

      DateTime dateWithCurrentTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
      );

      String? userEmail = FirebaseAuth.instance.currentUser?.email;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: userEmail)
          .get();

      if (querySnapshot.size == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found with the logged-in email')),
        );
        return;
      }

      final userDocumentId = querySnapshot.docs.first.id;

      final pls5QuerySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(userDocumentId)
          .collection('PLS5Form')
          .get();

      int newDocId = 1;
      if (pls5QuerySnapshot.size > 0) {
        final docIds = pls5QuerySnapshot.docs.map((doc) => int.tryParse(doc.id)).where((id) => id != null).cast<int>().toList();
        if (docIds.isNotEmpty) {
          newDocId = docIds.reduce((a, b) => a > b ? a : b) + 1;
        }
      }

      final formData = _getFormData();
      formData['date'] = dateWithCurrentTime;

      await FirebaseFirestore.instance
          .collection('user')
          .doc(userDocumentId)
          .collection('PLS5Form')
          .doc(newDocId.toString())
          .set(formData);

      lastSaveTime = DateTime.now();

      final updatedDatesWithStatus = await _fetchDates(formData['name']);

      setState(() {
        _dropdownHistoryKey.currentState?._datesWithStatus = updatedDatesWithStatus;
        _dropdownHistoryKey.currentState?._selectedDate = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form data saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred when trying to save: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchDates(String name) async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: userEmail)
          .get();

      if (querySnapshot.size == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found with the logged-in email')),
        );
        return [];
      }

      final userDocumentId = querySnapshot.docs.first.id;

      final pls5QuerySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(userDocumentId)
          .collection('PLS5Form')
          .where('name', isEqualTo: name)
          .get();

      return pls5QuerySnapshot.docs
          .map((doc) {
        final data = doc.data();
        final date = data['date'];
        final status = data['formStatus'];
        final docName = data['name'];
        return date != null
            ? {'date': (date as Timestamp).toDate(), 'status': status, 'name': docName}
            : null;
          })
          .where((date) => date != null)
          .cast<Map<String, dynamic>>()
          .toList();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred when trying to fetch dates: $e')),
      );
      return [];
    }
  }

  Future<void> _fetchFormData(DateTime selectedDate) async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: userEmail)
          .get();

      if (querySnapshot.size == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found with the logged-in email')),
        );
        return;
      }

      final userDocumentId = querySnapshot.docs.first.id;
      final pls5QuerySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(userDocumentId)
          .collection('PLS5Form')
          .where('date', isEqualTo: Timestamp.fromDate(selectedDate))
          .get();

      if (pls5QuerySnapshot.size == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No form data found for the selected date')),
        );
        return;
      }

      final formData = pls5QuerySnapshot.docs.first.data();

      if (formData['date'] is Timestamp) {
        Timestamp timestamp = formData['date'] as Timestamp;
        DateTime date = timestamp.toDate();
        formData['date'] = date;
      }

      widget.formKey.currentState?.reset();
      widget.formKey.currentState?.patchValue(formData);

      final pls5Rows = formData['pls5Rows'] as List<dynamic>? ?? [];

      final newTextControllers = pls5Rows.map((rowData) {
        List<TextEditingController> controllers = [];
        for (int i = 0; i < 4; i++) {
          String columnName = ['Subsets/Score', 'Standard Score (#)', 'Percentile Rank (%)', 'Descriptive Range (average/below average)'][i];
          controllers.add(TextEditingController(text: rowData[columnName] ?? ''));
        }
        return controllers;
      }).toList();

      setState(() {
        widget.onDataFetched(newTextControllers);
        widget.onStatusChanged(formData['formStatus'] ?? 'To Do');
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred when trying to fetch form data: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      widget.formKey.currentState?.patchValue({
        'name': '',
        'age': '',
        'gender': '',
        'therapist': '',
        'date': DateTime.now(),
        'activityFormName': '',
        'activity_board_dropdown': '',
        'auditory_comprehension_summary': '',
        'expressive_communication_summary': '',
        'total_language_score_summary': '',
        'other_comments': '',
        'next_steps': ''
      });
      widget.onStatusChanged('To Do');
      widget.pls5TableKey.currentState?.resetTable();
      _dropdownHistoryKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
          ElevatedButton(
            onPressed: _resetForm,
            child: const Text('Clear'),
          ),
        Row(
          children: [
            const Text('History: '),
            DropdownHistory(
              key: _dropdownHistoryKey,
              fetchDates: (name) => fetchDates(name),
              fetchFormData: _fetchFormData,
              formKey: widget.formKey,
              textControllers: widget.textControllers,
              onDataFetched: widget.onDataFetched,
              onStatusChanged: widget.onStatusChanged,
              initialName: widget.formData?.name,
              initialDate: widget.formData?.date
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : saveToFirestore,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => widget.onShowSaveOptions(context),
              child: const Text('Export'),
            ),
          ],
        ),
      ],
    );
  }
}

class DropdownHistory extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String) fetchDates;
  final Future<void> Function(DateTime) fetchFormData;
  final GlobalKey<FormBuilderState> formKey;
  final List<List<TextEditingController>> textControllers;
  final Function(List<List<TextEditingController>>) onDataFetched;
  final Function(String) onStatusChanged;
  final String? initialName;
  final DateTime? initialDate;

  const DropdownHistory({
    required this.fetchDates,
    required this.fetchFormData,
    required this.formKey,
    required this.textControllers,
    required this.onDataFetched,
    required this.onStatusChanged,
    this.initialName,
    this.initialDate,
    super.key,
  });

  @override
  State<DropdownHistory> createState() => _DropdownHistoryState();
}

class _DropdownHistoryState extends State<DropdownHistory> {
  List<Map<String, dynamic>> _datesWithStatus = [];
  DateTime? _selectedDate;
  String? _currentName;
  DateTime? _currentDate;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _currentName = widget.initialName;
    _fetchDates();

    final exactMatchIndex = _datesWithStatus.indexWhere(
          (item) => item['name'] == _currentName,
    );
    if (exactMatchIndex != -1) {
      setState(() {
        _selectedDate = _datesWithStatus[exactMatchIndex]['date'];
      });
      widget.fetchFormData(_datesWithStatus[exactMatchIndex]['date']).then((_) {
        final formData = widget.formKey.currentState?.value;
        if (formData != null && formData.containsKey('formStatus')) {
          widget.onStatusChanged(formData['formStatus']);
        }
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error occurred when fetching form data: $error')),
        );
      });
    } else {
      setState(() {
        _datesWithStatus = [];
        _selectedDate = null;
      });
    }
  }

  void _closeDropdown() {
    setState(() {
      _isOpen = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _currentName = widget.initialName;
    }
    if (widget.initialDate != null) {
      _currentDate = widget.initialDate;
    }
    _fetchDates();
  }

  @override
  void didUpdateWidget(DropdownHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialName != _currentName ||
        widget.initialDate != _currentDate) {
      if (widget.initialName != null && widget.initialName!.isNotEmpty) {
        _currentName = widget.initialName;
        _currentDate = widget.initialDate;
        _fetchDates();

        // Check if the initial name has an exact match
        final exactMatchIndex = _datesWithStatus.indexWhere((
            item) => item['name'] == _currentName);
        if (exactMatchIndex != -1) {
          setState(() {
            _selectedDate = _datesWithStatus[exactMatchIndex]['date'];
          });
          widget.fetchFormData(_datesWithStatus[exactMatchIndex]['date']).then((
              _) {
            final formData = widget.formKey.currentState?.value;
            if (formData != null && formData.containsKey('formStatus')) {
              widget.onStatusChanged(formData['formStatus']);
            }
          }).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(
                  'Error occurred when fetching form data: $error')),
            );
          });
        }
      } else {
        setState(() {
          _datesWithStatus = [];
          _selectedDate = null;
        });
      }
    }
  }

  void reset() {
    setState(() {
      _selectedDate = null;
    });
  }

  Future<void> _fetchDates() async {
    if (_currentName != null && _currentName!.isNotEmpty) {
      final datesWithStatus = await widget.fetchDates(_currentName!);
      setState(() {
        _datesWithStatus = datesWithStatus;
        _selectedDate = null;
      });
    } else {
      setState(() {
        _datesWithStatus = [];
        _selectedDate = null;
      });
    }
  }

  Future<void> _deleteDate(dynamic dateValue) async {
    if (dateValue is! DateTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Invalid date type')),
      );
      return;
    }

    DateTime date = dateValue;

    bool confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this save?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirmDelete) {
      try {
        String? userEmail = FirebaseAuth.instance.currentUser?.email;
        if (userEmail == null) {
          throw Exception('No user logged in');
        }

        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .where('email', isEqualTo: userEmail)
            .get();

        if (userDoc.docs.isEmpty) {
          throw Exception('No user found with the logged-in email');
        }

        String userId = userDoc.docs.first.id;
        await FirebaseFirestore.instance
            .collection('user')
            .doc(userId)
            .collection('PLS5Form')
            .where('date', isEqualTo: Timestamp.fromDate(date))
            .get()
            .then((snapshot) {
          for (DocumentSnapshot ds in snapshot.docs) {
            ds.reference.delete();
          }
        });

        setState(() {
          _datesWithStatus.removeWhere((item) => item['date'] == date);
          if (_selectedDate == date) {
            _selectedDate = null;
          }
        });

        if (_datesWithStatus.length == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save deleted successfully')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<dynamic>(
      initialValue: _selectedDate,
      onOpened: () {
        setState(() {
          _isOpen = true;
        });
      },
      onCanceled: _closeDropdown,
      onSelected: (dynamic value) {
        if (value is DateTime) {
          setState(() {
            _selectedDate = value;
            _isOpen = false;
          });
          widget.fetchFormData(value).then((_) {
            final formData = widget.formKey.currentState?.value;
            if (formData != null && formData.containsKey('formStatus')) {
              widget.onStatusChanged(formData['formStatus']);
            }
          }).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(
                  'Error occurred when fetching form data: $error')),
            );
          });
        } else if (value is Map<String, dynamic>) {
          _deleteDate(value['date']);
        }
      },
      itemBuilder: (BuildContext context) {
        return _datesWithStatus.map((Map<String, dynamic> dateWithStatus) {
          return PopupMenuItem<dynamic>(
            value: dateWithStatus['date'] as DateTime,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('yyyy-MM-dd HH:mm').format(
                        dateWithStatus['date'] as DateTime)} - ${dateWithStatus['status']}',
                    overflow: TextOverflow.clip,
                  ),
                ),
                PopupMenuItem<dynamic>(
                  value: dateWithStatus,
                  padding: EdgeInsets.zero,
                  height: 24,
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_selectedDate != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate!)
              : 'Select Date'),
          Icon(_isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
        ],
      ),
    );
  }
}