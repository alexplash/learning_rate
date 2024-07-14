import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:html' as html;

class GradBoostRegOverviewPage extends StatefulWidget {
  const GradBoostRegOverviewPage(
      {super.key,
      this.fileName,
      this.dataset,
      this.metadata,
      required this.isCreate});

  final bool isCreate;
  final String? fileName;
  final dynamic dataset;
  final Map<String, dynamic>? metadata;

  @override
  State<GradBoostRegOverviewPage> createState() =>
      _GradBoostRegOverviewPageState();
}

class _GradBoostRegOverviewPageState extends State<GradBoostRegOverviewPage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  dynamic data;
  List<String> selectedFeatures = [];
  String? selectedTarget;
  List<String> finalFeatures = [];
  String? finalTarget;
  TextEditingController numTrees = TextEditingController();
  TextEditingController learningRate = TextEditingController();
  TextEditingController maxDepth = TextEditingController();
  Map<String, dynamic> modelParameters = {};
  String errorMessage = '';
  String inferErrorMessage = '';
  String? imageString;
  bool isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCreate == true) {
      fetchData();
    } else if (widget.isCreate == false) {
      loadModel();
    }
  }

  Future<void> loadModel() async {
    setState(() {
      isLoading = true;
    });

    data = widget.dataset;
    selectedFeatures = List<String>.from(widget.metadata!['features']);
    selectedTarget = widget.metadata!['target'].toString();

    setState(() {
      finalFeatures = List<String>.from(selectedFeatures);
      finalTarget = selectedTarget;
    });

    final body = {'features': finalFeatures.toList()};

    try {
      final response = await http.post(
          Uri.parse('http://127.0.0.1:5000/load_grad_boost_reg'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        Map<dynamic, dynamic> rawImportance =
            Map<dynamic, dynamic>.from(responseData['feature_importance']);
        Map<String, double> featureImportance = rawImportance.map((key, value) {
          double parsedValue = (value is double) ? value : double.parse(value);
          return MapEntry(key.toString(), parsedValue);
        });

        var rawEstimators = responseData['estimators'];
        int estimators =
            (rawEstimators is int) ? rawEstimators : int.parse(rawEstimators);

        List<double> trainScores =
            List<double>.from(responseData['train_scores']);

        var rawFinalLearningRate = responseData['learning_rate'];
        double finalLearningRate = (rawFinalLearningRate is double) ? rawFinalLearningRate : double.parse(rawFinalLearningRate);

        var rawFinalMaxDepth = responseData['max_depth'];
        int finalMaxDepth = (rawFinalMaxDepth is int) ? rawFinalMaxDepth : int.parse(rawFinalMaxDepth);

        print(featureImportance);
        print(estimators);
        print(trainScores);

        setState(() {
          modelParameters = {
            'featureImportance': featureImportance,
            'estimators': estimators,
            'trainScores': trainScores,
            'learningRate': finalLearningRate,
            'maxDepth': finalMaxDepth
          };
        });
        print('Model loaded successfully');
      } else {
        print('Failed to load model');
      }
    } catch (e) {
      print('Exception caught: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse(
          'http://127.0.0.1:5000/fetch_dataset?file_name=${widget.fileName}'));
      if (response.statusCode == 200) {
        setState(() {
          data = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        print('Failed to load dataset. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Exception caught: $e');
    }
  }

  void handleImageLoaded(String base64Image) {
    setState(() {
      imageString = base64Image;
      isLoadingImage = false;
    });
  }

  void handleVisualizeLoading(bool isLoading) {
    setState(() {
      isLoadingImage = isLoading;
    });
  }

  void setFeature(String columnName) {
    setState(() {
      if (selectedFeatures.contains(columnName)) {
        selectedFeatures.remove(columnName);
      } else {
        selectedFeatures.add(columnName);
      }
    });
  }

  void setTarget(String columnName) {
    setState(() {
      selectedTarget = columnName;
    });
  }

  Future<void> trainGradBoostReg() async {
    if (selectedFeatures.isEmpty || selectedTarget == null) {
      setState(() {
        errorMessage = 'Please select features AND target';
      });
      return;
    }

    setState(() {
      isLoading = true;
      finalFeatures = List<String>.from(selectedFeatures);
      finalTarget = selectedTarget;
    });

    int nt = numTrees.text.isNotEmpty ? int.parse(numTrees.text) : 100;
    double lr =
        learningRate.text.isNotEmpty ? double.parse(learningRate.text) : 0.1;
    int md = maxDepth.text.isNotEmpty ? int.parse(maxDepth.text) : 3;

    final body = {
      'features': finalFeatures.toList(),
      'target': finalTarget,
      'dataset': data,
      'n_trees': nt,
      'learning_rate': lr,
      'max_depth': md
    };

    try {
      final response = await http.post(
          Uri.parse('http://127.0.0.1:5000/train_grad_boost_reg'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        Map<dynamic, dynamic> rawImportance =
            Map<dynamic, dynamic>.from(responseData['feature_importance']);
        Map<String, double> featureImportance = rawImportance.map((key, value) {
          double parsedValue = (value is double) ? value : double.parse(value);
          return MapEntry(key.toString(), parsedValue);
        });

        var rawEstimators = responseData['estimators'];
        int estimators =
            (rawEstimators is int) ? rawEstimators : int.parse(rawEstimators);

        List<double> trainScores =
            List<double>.from(responseData['train_scores']);

        var rawFinalLearningRate = responseData['learning_rate'];
        double finalLearningRate = (rawFinalLearningRate is double) ? rawFinalLearningRate : double.parse(rawFinalLearningRate);

        var rawFinalMaxDepth = responseData['max_depth'];
        int finalMaxDepth = (rawFinalMaxDepth is int) ? rawFinalMaxDepth : int.parse(rawFinalMaxDepth);

        print(featureImportance);
        print(estimators);
        print(trainScores);

        setState(() {
          modelParameters = {
            'featureImportance': featureImportance,
            'estimators': estimators,
            'trainScores': trainScores,
            'learningRate': finalLearningRate,
            'maxDepth': finalMaxDepth
          };
        });
        print('Model trained successfully');
      } else {
        print('Failed to train model. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Exception caught: $e');
    }

    setState(() {
      errorMessage = '';
      isLoading = false;
    });
  }

  Future<void> runInference(
      Map<String, double> featureInputs, Function(String) onResult) async {
    final url = Uri.parse('http://127.0.0.1:5000/infer_grad_boost_reg');
    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'features': featureInputs}));
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        onResult(result['prediction'][0].toString());
        setState(() {
          inferErrorMessage = "";
        });
      } else {
        print('Failed to get prediction. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          inferErrorMessage = json.decode(response.body)['error'];
        });
        onResult('');
      }
    } catch (e) {
      print('Exception caught: $e');
      setState(() {
        inferErrorMessage = e.toString();
      });
      onResult('');
    }
  }

  void downloadTree(String base64String) {
    final RegExp regex = RegExp(r'data:image\/[a-zA-Z]*;base64,');
    final String cleanBase64 = base64String.replaceFirst(regex, '');

    final bytes = base64Decode(cleanBase64);

    final blob = html.Blob([bytes], 'image/png');

    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'decision_tree.png')
      ..click();

    // for the sole purpose of using anchor, such that there is no error on its lack of usage
    print(anchor);

    html.Url.revokeObjectUrl(url);
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
              const SizedBox(height: 10),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else ...[
                Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Expanded(
                      child: DataSummaryWidget(
                          data: data,
                          selectedFeatures: selectedFeatures,
                          selectedTarget: selectedTarget,
                          setFeature: setFeature,
                          setTarget: setTarget,
                          isCreate: widget.isCreate))
                ]),
                Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
                if (widget.isCreate == true) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: numTrees,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode'),
                    decoration: InputDecoration(
                      labelText: 'Number of Trees: Default = 100',
                      labelStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'FiraCode'),
                      hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'FiraCode'),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusColor: Colors.white,
                      hoverColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: learningRate,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode'),
                    decoration: InputDecoration(
                      labelText: 'Learning Rate: Default = 0.1',
                      labelStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'FiraCode'),
                      hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'FiraCode'),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusColor: Colors.white,
                      hoverColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: maxDepth,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode'),
                    decoration: InputDecoration(
                      labelText: 'Max Depth: Default = 3',
                      labelStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'FiraCode'),
                      hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'FiraCode'),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.grey[600]!, width: 2.0),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusColor: Colors.white,
                      hoverColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  TrainButton(
                      onTrainModel: trainGradBoostReg,
                      modelParameters: modelParameters),
                ],
                const SizedBox(height: 20),
                if (errorMessage.isNotEmpty) ...[
                  Text(errorMessage,
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontFamily: 'FiraCode')),
                  const SizedBox(height: 20),
                ],
                if (modelParameters.isNotEmpty) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    ModelInfoSection(
                        featureImportance: modelParameters['featureImportance'],
                        learningRate: modelParameters['learningRate'],
                        maxDepth: modelParameters['maxDepth'],
                    ),
                  ]),
                  const SizedBox(height: 20),
                  TrainScoreGraph(trainScores: modelParameters['trainScores']),
                  const SizedBox(height: 20),
                  VisualizeTreesSection(
                      estimators: modelParameters['estimators'],
                      onImageLoaded: handleImageLoaded,
                      onLoading: handleVisualizeLoading),
                  if (imageString != null && !isLoadingImage) ...[
                    const SizedBox(height: 20),
                    Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: Colors.white, width: 2.0),
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(children: [
                          Image.memory(
                            base64Decode(imageString!),
                            errorBuilder: (context, error, stackTrace) {
                              print("Image load error: $error");
                              print("Stack trace: $stackTrace");
                              return const Text('Failed to load image',
                                  style: TextStyle(color: Colors.red));
                            },
                          ),
                          const SizedBox(height: 20),
                          DownloadTreeButton(onDownload: () {
                            downloadTree(imageString!);
                          }),
                          const SizedBox(height: 20),
                        ]))
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Inference',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FiraCode',
                    ),
                  ),
                  const SizedBox(height: 20),
                  InferenceSection(
                      features: finalFeatures,
                      target: finalTarget!,
                      onSubmit: (inputs, onResult) {
                        runInference(inputs, (prediction) {
                          onResult(prediction);
                        });
                      },
                      data: data,
                      isCreate: widget.isCreate),
                  if (inferErrorMessage.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(inferErrorMessage,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontFamily: 'FiraCode')),
                  ],
                  const SizedBox(height: 50),
                ]
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
          Navigator.pop(context);
        },
        child: Text(
          'RETURN HOME',
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

class TrainButton extends StatefulWidget {
  final VoidCallback onTrainModel;
  final Map<String, dynamic>? modelParameters;

  const TrainButton(
      {Key? key, required this.onTrainModel, required this.modelParameters})
      : super(key: key);

  @override
  _TrainButtonState createState() => _TrainButtonState();
}

class _TrainButtonState extends State<TrainButton> {
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
        onPressed: widget.onTrainModel,
        child: Text(
          widget.modelParameters!.isEmpty ? 'TRAIN MODEL' : 'RETRAIN MODEL',
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

class DownloadTreeButton extends StatefulWidget {
  final VoidCallback onDownload;

  const DownloadTreeButton({Key? key, required this.onDownload})
      : super(key: key);

  @override
  _DownloadTreeButtonState createState() => _DownloadTreeButtonState();
}

class _DownloadTreeButtonState extends State<DownloadTreeButton> {
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
        onPressed: widget.onDownload,
        child: Text(
          "DOWNLOAD TREE",
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

class DataSummaryWidget extends StatelessWidget {
  final dynamic data;
  final List<String> selectedFeatures;
  final String? selectedTarget;
  final Function(String) setFeature;
  final Function(String) setTarget;
  final bool isCreate;

  const DataSummaryWidget(
      {Key? key,
      required this.data,
      required this.selectedFeatures,
      required this.selectedTarget,
      required this.setFeature,
      required this.setTarget,
      required this.isCreate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data == null || data.isEmpty) {
      return const Text(
        'No data available',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'FiraCode',
        ),
      );
    }

    int rowCount = data.length;
    int columnCount = data.isNotEmpty ? data[0].keys.length : 0;
    List<String> columnNames = data.isNotEmpty ? data[0].keys.toList() : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'FiraCode',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Rows: $rowCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'FiraCode',
          ),
        ),
        Text(
          'Columns: $columnCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'FiraCode',
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Columns: ',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'FiraCode',
                  fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  'Features',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'FiraCode',
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                Text(
                  'Target',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'FiraCode',
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnNames
                .map((name) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'FiraCode'),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.circle,
                                    color: selectedFeatures.contains(name)
                                        ? Colors.white
                                        : const Color.fromARGB(
                                            255, 82, 82, 82)),
                                onPressed: () {
                                  if (isCreate == true) {
                                    setFeature(name);
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: Icon(Icons.circle,
                                    color: selectedTarget == name
                                        ? Colors.white
                                        : const Color.fromARGB(
                                            255, 82, 82, 82)),
                                onPressed: () {
                                  if (isCreate == true) {
                                    setTarget(name);
                                  }
                                },
                              )
                            ],
                          )
                        ]))
                .toList())
      ],
    );
  }
}

class ModelInfoSection extends StatefulWidget {
  final Map<String, double> featureImportance;
  final double learningRate;
  final int maxDepth;

  const ModelInfoSection({Key? key, required this.featureImportance, required this.learningRate, required this.maxDepth})
      : super(key: key);

  @override
  _ModelInfoSectionState createState() => _ModelInfoSectionState();
}

class _ModelInfoSectionState extends State<ModelInfoSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feature Importance: ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 10),
            ...widget.featureImportance.entries.map((entry) => Text(
                '${entry.key}: ${entry.value.toString()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'FiraCode'))),
            const SizedBox(height: 20),
            const Text('Learning Rate: ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 10),
            Text(
              widget.learningRate.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'FiraCode'
              )
            ),
            const SizedBox(height: 20),
            const Text('Max Depth: ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 10),
            Text(
              widget.maxDepth.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'FiraCode'
              )
            ),
          ],
        ));
  }
}

class TrainScoreGraph extends StatelessWidget {
  final List<double> trainScores;

  const TrainScoreGraph({Key? key, required this.trainScores})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> dataPoints = [];
    for (int i = 0; i < trainScores.length; i++) {
      final double x = i + 1;
      final double y = trainScores[i];
      dataPoints.add(FlSpot(x, y));
    }
    double maxX = trainScores.length.toDouble();
    double minY = dataPoints.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    double maxY = dataPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);

    return Container(
        height: 500,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Model Performance Error vs. Training Steps",
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontFamily: 'FiraCode'),
              textAlign: TextAlign.center,
            ),
            const Divider(color: Colors.white, thickness: 0.5, height: 20),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: LineChart(LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'FiraCode'),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                          show: true, border: Border.all(color: Colors.white)),
                      minX: 0,
                      maxX: maxX,
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                            spots: dataPoints,
                            isCurved: false,
                            color: Colors.white,
                            barWidth: 0.25)
                      ]))),
            ),
            const Divider(color: Colors.white, thickness: 0.5, height: 20),
            const SizedBox(height: 10),
            const Text(
                'Each training step is associated with a tree in the inference process. Visualize each individual tree below.',
                style: TextStyle(
                    color: Colors.white, fontSize: 14, fontFamily: 'FiraCode'),
                textAlign: TextAlign.center),
            const SizedBox(height: 20)
          ],
        ));
  }
}

class VisualizeTreesSection extends StatefulWidget {
  final int estimators;
  final Function(String) onImageLoaded;
  final Function(bool) onLoading;

  const VisualizeTreesSection(
      {Key? key,
      required this.estimators,
      required this.onImageLoaded,
      required this.onLoading})
      : super(key: key);

  @override
  _VisualizeTreesSection createState() => _VisualizeTreesSection();
}

class _VisualizeTreesSection extends State<VisualizeTreesSection> {
  double sliderValue = 1;
  int treeIndex = 1;
  bool isHovering = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        visualizeTree();
      }
    });
  }

  Future<void> visualizeTree() async {
    if (!mounted) return;

    widget.onLoading(true);
    setState(() {
      isLoading = true;
    });

    final body = {'tree_index': treeIndex};

    final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/graph_grad_boost_reg'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body));

    if (mounted) {
      if (response.statusCode == 200) {
        String imageBase64 = jsonDecode(response.body)['image_base64'];
        widget.onImageLoaded(imageBase64.split(',').last);
        setState(() {
          isLoading = false;
        });
      } else {
        print("Failed to load tree image");
        setState(() {
          isLoading = false;
        });
      }
      widget.onLoading(false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Visualize Trees',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
            else ...[
              SliderTheme(
                  data: SliderThemeData(
                      activeTrackColor: Colors.white,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.3),
                      valueIndicatorColor: Colors.white,
                      valueIndicatorTextStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'FiraCode')),
                  child: Slider(
                      value: sliderValue,
                      min: 1,
                      max: widget.estimators.toDouble(),
                      divisions: widget.estimators - 1,
                      label: '$sliderValue',
                      onChanged: (double value) {
                        setState(() {
                          sliderValue = value;
                        });
                      })),
              const SizedBox(height: 10),
              MouseRegion(
                  onEnter: (event) => setState(() => isHovering = true),
                  onExit: (event) => setState(() => isHovering = false),
                  child: TextButton(
                      style: TextButton.styleFrom(
                          backgroundColor:
                              isHovering ? Colors.white : Colors.transparent,
                          side: BorderSide(
                              color: isHovering ? Colors.black : Colors.white,
                              width: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        treeIndex = sliderValue.toInt();
                        visualizeTree();
                      },
                      child: Text('VISUALIZE',
                          style: TextStyle(
                              color: isHovering ? Colors.black : Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'FiraCode')))),
            ]
          ],
        ));
  }
}

class InferenceSection extends StatefulWidget {
  final List<String> features;
  final String target;
  final Function(Map<String, double>, Function(String)) onSubmit;
  final dynamic data;
  final bool isCreate;

  const InferenceSection(
      {Key? key,
      required this.features,
      required this.target,
      required this.onSubmit,
      required this.data,
      required this.isCreate})
      : super(key: key);

  @override
  _InferenceSectionState createState() => _InferenceSectionState();
}

class _InferenceSectionState extends State<InferenceSection> {
  final Map<String, TextEditingController> controllers = {};
  String inferredValue = '';

  @override
  void initState() {
    super.initState();
    widget.features.forEach((feature) {
      controllers[feature] = TextEditingController();
    });
  }

  @override
  void dispose() {
    controllers.forEach((key, value) {
      value.dispose();
    });
    super.dispose();
  }

  void handleInference() {
    Map<String, double> featureValues = {};
    controllers.forEach((feature, controller) {
      double? value = double.tryParse(controller.text);
      if (value != null) {
        featureValues[feature] = value;
      }
    });
    widget.onSubmit(featureValues, (result) {
      setState(() {
        inferredValue = result;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ...controllers.entries.map((entry) {
        return Column(
          children: [
            TextField(
              controller: entry.value,
              cursorColor: Colors.white,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontFamily: 'FiraCode'),
              decoration: InputDecoration(
                labelText: entry.key,
                labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontFamily: 'FiraCode'),
                hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontFamily: 'FiraCode'),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 2.0),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 2.0),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 2.0),
                ),
                focusColor: Colors.white,
                hoverColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
          ],
        );
      }).toList(),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        InferenceButton(onInference: handleInference),
        if (widget.isCreate == true) ...[
          const SizedBox(width: 20),
          SaveButton(
              algoName: 'grad_boost_reg',
              features: widget.features,
              target: widget.target,
              data: widget.data)
        ]
      ]),
      if (inferredValue.isNotEmpty) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Predicted ${widget.target}: $inferredValue',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'FiraCode',
            ),
          ),
        ),
      ]
    ]);
  }
}

class InferenceButton extends StatefulWidget {
  final VoidCallback onInference;

  const InferenceButton({Key? key, required this.onInference})
      : super(key: key);

  @override
  _InferenceButtonState createState() => _InferenceButtonState();
}

class _InferenceButtonState extends State<InferenceButton> {
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
        onPressed: widget.onInference,
        child: Text(
          'PREDICT',
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

class SaveButton extends StatefulWidget {
  final String algoName;
  final List<String> features;
  final String target;
  final dynamic data;

  const SaveButton({
    Key? key,
    required this.algoName,
    required this.features,
    required this.target,
    required this.data,
  }) : super(key: key);

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _isHovering = false;
  TextEditingController controller = TextEditingController();
  bool showError = false;
  String errorMessage = '';
  String? modelName;

  Future<bool> saveModel() async {
    modelName = controller.text.trim();

    final body = {
      'algo_name': widget.algoName,
      'model_name': modelName,
      'features': widget.features,
      'target': widget.target,
      'dataset': widget.data
    };

    try {
      final response = await http.post(
          Uri.parse('http://127.0.0.1:5000/save_model'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 200) {
        print('Model Saved Successfully');
        return true;
      } else {
        print('Failed to train model');
        return false;
      }
    } catch (e) {
      print('Exception caught: $e');
      return false;
    }
  }

  void showSaveDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
                backgroundColor: const Color.fromARGB(255, 11, 11, 16),
                title: const Center(
                  child: Text("NAME YOUR MODEL",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                          fontFamily: 'FiraCode')),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: controller,
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                            hintText: "Enter model name",
                            hintStyle: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontFamily: 'FiraCode'),
                            enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 1.0),
                                borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 1.0),
                                borderRadius: BorderRadius.circular(10)),
                            errorText: showError ? errorMessage : null,
                            errorStyle: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontFamily: 'FiraCode'))),
                  ],
                ),
                actions: <Widget>[
                  Center(
                      child: TextButton(
                    style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      if (controller.text.trim().isEmpty) {
                        setState(() {
                          showError = true;
                          errorMessage = 'PLEASE ENTER MODEL NAME';
                        });
                      } else {
                        setState(() {
                          showError = false;
                          errorMessage = '';
                        });
                        bool success = await saveModel();
                        if (success == true) {
                          Navigator.of(context).pop();
                        } else if (success == false) {
                          setState(() {
                            showError = true;
                            errorMessage = 'FAILED TO SAVE MODEL';
                          });
                        }
                      }
                    },
                    child: const Text('SAVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'FiraCode')),
                  ))
                ]);
          });
        });
  }

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
        onPressed: () => showSaveDialog(context),
        child: Text(
          'SAVE MODEL',
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
