import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

class DataLibraryPage extends StatefulWidget {
  const DataLibraryPage({super.key});

  @override
  State<DataLibraryPage> createState() => _DataLibraryPageState();
}

class _DataLibraryPageState extends State<DataLibraryPage> {
  bool isLoading = true;
  List<String> datasetNames = [];

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await fetchDataNames();
    });
  }

  Future<void> fetchDataNames() async {
    setState(() {
      isLoading = true;
    });
    try {
      var response =
          await http.get(Uri.parse("http://127.0.0.1:5000/fetch_data_names"));
      if (response.statusCode == 200) {
        List<String> responseData =
            List<String>.from(json.decode(response.body));
        setState(() {
          datasetNames = responseData;
        });
      } else {
        throw Exception(
            'Failed to load dataset names with status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching dataset names: $e');
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.only(
                    top: 40, left: 20, right: 20, bottom: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LEARNING_RATE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'FiraCode'),
                    ),
                    HomeButton()
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
              const SizedBox(height: 50),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              else ...[
                DataBreakdownWidget(datasetNames: datasetNames),
                const SizedBox(height: 50)
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class HomeButton extends StatefulWidget {
  const HomeButton({Key? key}) : super(key: key);

  @override
  _HomeButtonState createState() => _HomeButtonState();
}

class _HomeButtonState extends State<HomeButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() => _isHovering = true),
      onExit: (event) => setState(() => _isHovering = false),
      child: TextButton(
        style: TextButton.styleFrom(
            backgroundColor: _isHovering ? Colors.white : Colors.transparent,
            side: BorderSide(
                color: _isHovering ? Colors.black : Colors.white, width: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text(
          'RETURN HOME',
          style: TextStyle(
              color: _isHovering ? Colors.black : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'FiraCode'),
        ),
      ),
    );
  }
}

class DataBreakdownWidget extends StatefulWidget {
  final List<String> datasetNames;

  const DataBreakdownWidget({Key? key, required this.datasetNames})
      : super(key: key);

  @override
  _DataBreakdownWidgetState createState() => _DataBreakdownWidgetState();
}

class _DataBreakdownWidgetState extends State<DataBreakdownWidget> {
  List<String> currentDatasetNames = [];

  void initState() {
    super.initState();
    currentDatasetNames = widget.datasetNames;
  }

  void showOptionsDialog(BuildContext context, String dataName) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 11, 11, 16),
              title: const Center(
                child: Text("DELETE DATASET",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.white,
                        fontFamily: 'FiraCode')),
              ),
              actions: <Widget>[
                Center(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            await deleteDataset(dataName);
                            Navigator.of(context).pop();
                          },
                          child: const Text("YES",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Fira Code'))),
                      const SizedBox(width: 20),
                      TextButton(
                          style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("NO",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'FiraCode')))
                    ]))
              ]);
        });
  }

  Future<void> deleteDataset(String dataName) async {
    try {
      final body = {'data_name': dataName};

      var response = await http.post(
          Uri.parse('http://127.0.0.1:5000/delete_data'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 200) {
        setState(() {
          currentDatasetNames.remove(dataName);
        });
      } else {
        print('Failed to delete file');
      }
    } catch (e) {
      print('Exception caught: $e');
    }
  }

  Future<void> pickFile() async {
    try {
      if (kIsWeb) {
        html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.accept = '.csv';
        uploadInput.click();

        uploadInput.onChange.listen((e) async {
          final files = uploadInput.files;
          if (files!.isEmpty) return;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(files[0]);
          reader.onLoadEnd.listen((e) async {
            final data = reader.result as Uint8List;
            await uploadFile(files[0].name, data);
          });
        });
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv']
        );
        if (result != null) {
          PlatformFile file = result.files.first;
          await uploadFile(file.name, file.bytes!);
        } else {
          print('No file selected.');
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> uploadFile(String fileName, Uint8List fileData) async {
    try {
      var uri = Uri.parse('http://127.0.0.1:5000/store_data');
      var request = http.MultipartRequest('POST', uri);

      var multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileData,
        filename: fileName
      );
      request.files.add(multipartFile);

      var response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          currentDatasetNames.add(fileName);
        });
        print('File uploaded successfully');
      } else {
        print('Failed to upload file');
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Text(
                    'Saved Datasets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FiraCode',
                    ),
                  ),
      const SizedBox(height: 40),
      Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: currentDatasetNames.map((name) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DataCard(
                      name: name,
                      onTap: () {
                        showOptionsDialog(context, name);
                      }),
                  const SizedBox(height: 40)
                ]);
          }).toList()),
      UploadButton(
        onTap: () async {
          await pickFile();
        }
      )
    ]);
  }
}

class DataCard extends StatefulWidget {
  final String name;
  final VoidCallback onTap;

  const DataCard({Key? key, required this.name, required this.onTap})
      : super(key: key);

  @override
  _DataCardState createState() => _DataCardState();
}

class _DataCardState extends State<DataCard> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    double width = isHovering ? 730 : 700;
    double height = isHovering ? 110 : 100;

    return GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
            onEnter: (_) => setState(() => isHovering = true),
            onExit: (_) => setState(() => isHovering = false),
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white),
                  image: DecorationImage(
                      image: const AssetImage("images/blue_wavy.jpg"),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.5), BlendMode.darken)),
                ),
                width: width,
                height: height,
                child: Container(
                  child: Center(
                    child: Text(widget.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'FiraCode')),
                  ),
                ))));
  }
}

class UploadButton extends StatefulWidget {
  final VoidCallback onTap;

  const UploadButton({Key? key, required this.onTap}) : super(key: key);

  @override
  _UploadButtonState createState() => _UploadButtonState();
}

class _UploadButtonState extends State<UploadButton> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() => isHovering = true),
      onExit: (event) => setState(() => isHovering = false),
      child: TextButton(
        style: TextButton.styleFrom(
            backgroundColor: isHovering ? Colors.white : Colors.transparent,
            side: BorderSide(
                color: isHovering ? Colors.black : Colors.white, width: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        onPressed: widget.onTap,
        child: Text(
          'UPLOAD DATA',
          style: TextStyle(
              color: isHovering ? Colors.black : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'FiraCode'),
        ),
      ),
    );
  }
}
