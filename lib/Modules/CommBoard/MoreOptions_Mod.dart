import 'package:flutter/material.dart';

class MoreOptions extends StatefulWidget {
  final bool translate;
  final bool incrementUsageCount;
  final String? currentLanguage;

  const MoreOptions({
    Key? key,
    required this.translate,
    required this.incrementUsageCount,
    required this.currentLanguage,
  }) : super(key: key);

  @override
  _MoreOptionsState createState() => _MoreOptionsState();
}

class _MoreOptionsState extends State<MoreOptions> {
  late bool translate;
  late bool incrementUsageCount;

  @override
  void initState() {
    super.initState();
    translate = widget.translate;
    incrementUsageCount = widget.incrementUsageCount;
  }

  String getOppositeLanguage() {
    return widget.currentLanguage == 'English' ? 'Tagalog' : 'English';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Container(
        width: 350, // Increase the width of the dialog
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'More Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Switch language to ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: getOppositeLanguage(),
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: translate,
                    onChanged: (bool value) {
                      setState(() {
                        translate = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Symbol usage counter: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: incrementUsageCount ? 'On' : 'Off',
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: incrementUsageCount,
                    onChanged: (bool value) {
                      setState(() {
                        incrementUsageCount = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop({'translate': translate, 'incrementUsageCount': incrementUsageCount});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
