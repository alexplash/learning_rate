import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'modelCreation/linRegOverview.dart';
import 'modelCreation/logRegOverview.dart';
import 'modelCreation/ranForOverview.dart';
import 'modelCreation/gradBoostRegOverview.dart';
import 'modelCreation/kMeansOverview.dart';
import 'userData/dataLibrary.dart';
import 'userData/modelLibrary.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learning Rate',
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color.fromARGB(255, 11, 11, 16),
          scaffoldBackgroundColor: const Color.fromARGB(255, 11, 11, 16),
          textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontFamily: 'FiraCode'),
              bodyMedium:
                  TextStyle(color: Colors.grey, fontFamily: 'FiraCode'))),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  List<String> datasetNames = [];
  String selectedDataset = '';
  String selectedModel = '';
  String errorMessage = '';

  Future<void> fetchDataNames() async {
    try {
      var response =
          await http.get(Uri.parse('http://127.0.0.1:5000/fetch_data_names'));
      if (response.statusCode == 200) {
        List<String> dataNames =
            List<String>.from(json.decode(response.body));
        setState(() {
          datasetNames = dataNames;
        });
      } else {
        throw Exception(
            'Failed to load dataset names with status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching dataset names: $e');
      setState(() {
        errorMessage = e.toString();
      });
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
          allowedExtensions: ['csv'],
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
        filename: fileName,
      );
      request.files.add(multipartFile);

      var response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          selectedDataset = fileName;
        });
        print('File uploaded successfully');
      } else {
        print('Failed to upload file');
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
  }

  void showExistingDatasetsDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Align(
              alignment: Alignment.center,
              child: Material(
                  color: Colors.transparent,
                  child: Container(
                      width: MediaQuery.of(context).size.width * 0.6,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 24, 24, 29),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'SELECT DATASET',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'FiraCode',
                            ),
                          ),
                          const SizedBox(height: 20),
                          ListView.builder(
                              shrinkWrap: true,
                              itemCount: datasetNames.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                    title: Text(datasetNames[index],
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                    trailing: IconButton(
                                        icon: const Icon(Icons.chevron_right,
                                            color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            selectedDataset =
                                                datasetNames[index];
                                          });
                                          Navigator.pop(context);
                                        }));
                              }),
                          const SizedBox(height: 20),
                          TextButton(
                              style: TextButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(
                                      color: Colors.white, width: 1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('CLOSE',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'FiraCode')))
                        ],
                      ))));
        });
  }

  void onError() {
    setState(() {
      errorMessage = 'Please select data AND model';
    });
  }

  void onNoError() {
    setState(() {
      errorMessage = '';
    });
  }

  void showLibraryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 11, 11, 16),
          title: const Center(
            child: Text(
              "LIBRARY SELECTION",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
                fontFamily: 'FiraCode'
              )
            ), 
          ),
          actions: <Widget>[
            Center(
              child: Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                          const DataLibraryPage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return child; // No transition
                          },
                        ),
                      );
                    },
                    child: const Text(
                      "DATA LIBRARY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Fira Code'
                      )
                    )
                  ),
                  const SizedBox(width: 20),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)
                      )
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                          const ModelLibraryPage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return child; // No transition
                          },
                        ),
                      );
                    },
                    child: const Text(
                      "MODEL LIBRARY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode'
                      )
                    )
                  )
                ],
              )
            )
          ]
        );
      }
    );
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LEARNING_RATE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'FiraCode'),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 23,
                          backgroundImage: AssetImage('images/profileImage.JPG'),
                          backgroundColor: Colors.transparent,
                        )
                      ),
                      onPressed: () => showLibraryDialog(context),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: (1 / 0.8),
                children: <Widget>[
                  UploadCard(
                    title: 'Existing Data',
                    description:
                        'Select from within your data library to train your ML model.',
                    imagePath: 'images/blue_wavy.jpg',
                    onTap: () async {
                      await fetchDataNames();
                      showExistingDatasetsDialog(context);
                    },
                  ),
                  UploadCard(
                    title: 'New Data',
                    description:
                        'Upload new data to your data library to train your ML model.',
                    imagePath: 'images/purple_wavy.jpg',
                    onTap: () async {
                      await pickFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (selectedDataset.isNotEmpty)
                Column(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Selected Dataset: $selectedDataset',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ]),
              Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                childAspectRatio: 1.0,
                children: <Widget>[
                  ModelCard(
                      title: 'Linear / Multi Regression',
                      description: 'Supervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Linear / Multi Regression';
                        });
                      },
                      imagePath: 'images/linR.png'),
                  ModelCard(
                      title: 'Logistic / Softmax Regression',
                      description: 'Supervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Logistic / Softmax Regression';
                        });
                      },
                      imagePath: 'images/logR.png'),
                  ModelCard(
                      title: 'Decision Tree / Random Forest',
                      description: 'Supervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Decision Tree / Random Forest';
                        });
                      },
                      imagePath: 'images/RF.png'),
                  ModelCard(
                      title: 'Gradient Boost Regressor',
                      description: 'Supervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Gradient Boost Regressor';
                        });
                      },
                      imagePath: 'images/GBR.png'),
                  ModelCard(
                      title: 'Gradient Boost Classifier',
                      description: 'Supervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Gradient Boost Classifier';
                        });
                      },
                      imagePath: 'images/GBC.png'),
                  ModelCard(
                      title: 'Support Vector Machine',
                      description: 'Supervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Support Vector Machine';
                        });
                      },
                      imagePath: 'images/SVM.png'),
                  ModelCard(
                      title: 'K - Means Clustering',
                      description: 'Unsupervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'K - Means Clustering';
                        });
                      },
                      imagePath: 'images/kmeans.png'),
                  ModelCard(
                      title: 'Gaussian Mixture Model',
                      description: 'Unsupervised',
                      onTap: () {
                        setState(() {
                          selectedModel = 'Gaussian Mixture Model';
                        });
                      },
                      imagePath: 'images/GMM.png'),
                ],
              ),
              const SizedBox(height: 20),
              if (selectedModel.isNotEmpty)
                Column(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Selected Model: $selectedModel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ]),
              Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
              const SizedBox(height: 20),
              ConfigDataButton(
                  fileName: selectedDataset,
                  modelName: selectedModel,
                  onError: onError,
                  onNoError: onNoError),
              const SizedBox(height: 20),
              if (errorMessage.isNotEmpty)
                Text(errorMessage,
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontFamily: 'FiraCode')),
              const SizedBox(height: 50)
            ],
          ),
        ),
      ),
    );
  }
}

class UploadCard extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback onTap;

  const UploadCard({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onTap,
  }) : super(key: key);

  @override
  _UploadCardState createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets margin =
        isHovering ? const EdgeInsets.all(5) : const EdgeInsets.all(10);

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovering = true),
        onExit: (_) => setState(() => isHovering = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: margin,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 24, 24, 29),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 24, 24, 29),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'FiraCode')),
                    const SizedBox(height: 5),
                    Text(widget.description,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontFamily: 'FiraCode')),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
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

class ModelCard extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback onTap;

  const ModelCard({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onTap,
  }) : super(key: key);

  @override
  _ModelCardState createState() => _ModelCardState();
}

class _ModelCardState extends State<ModelCard> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets margin =
        isHovering ? const EdgeInsets.all(5) : const EdgeInsets.all(10);

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovering = true),
        onExit: (_) => setState(() => isHovering = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: AssetImage(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color.fromARGB(200, 24, 24, 29),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FiraCode',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FiraCode',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConfigDataButton extends StatefulWidget {
  final String fileName;
  final String modelName;
  final VoidCallback onError;
  final VoidCallback onNoError;

  const ConfigDataButton(
      {Key? key,
      required this.fileName,
      required this.modelName,
      required this.onError,
      required this.onNoError})
      : super(key: key);

  @override
  _ConfigDataButtonState createState() => _ConfigDataButtonState();
}

class _ConfigDataButtonState extends State<ConfigDataButton> {
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
        onPressed: () {
          if (widget.fileName.isEmpty || widget.modelName.isEmpty) {
            widget.onError();
          } else {
            widget.onNoError();
            if (widget.modelName == 'Linear / Multi Regression') {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      LinRegOverviewPage(fileName: widget.fileName, isCreate: true),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
            } else if (widget.modelName == 'Logistic / Softmax Regression') {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      LogRegOverviewPage(fileName: widget.fileName, isCreate: true),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
            } else if (widget.modelName == 'Decision Tree / Random Forest') {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      RanForOverviewPage(fileName: widget.fileName, isCreate: true),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
            } else if (widget.modelName == 'Gradient Boost Regressor') {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      GradBoostRegOverviewPage(fileName: widget.fileName, isCreate: true),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
            } else if (widget.modelName == 'K - Means Clustering') {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      KMeansOverviewPage(fileName: widget.fileName, isCreate: true),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
            }
          }
        },
        child: Text(
          'CONFIGURE MODEL',
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
