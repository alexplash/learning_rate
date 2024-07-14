import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:math';

class LogRegOverviewPage extends StatefulWidget {
  const LogRegOverviewPage({super.key, this.fileName, this.dataset, this.metadata, required this.isCreate});

  final bool isCreate;
  final String? fileName;
  final dynamic dataset;
  final Map<String, dynamic>? metadata;

  @override
  State<LogRegOverviewPage> createState() => _LogRegOverviewPageState();
}

class _LogRegOverviewPageState extends State<LogRegOverviewPage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  dynamic data;
  List<String> selectedFeatures = [];
  String? selectedTarget;
  List<String> finalFeatures = [];
  String? finalTarget;
  Map<String, dynamic> modelParameters = {};
  String errorMessage = '';
  String inferErrorMessage = '';

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

    final body = {
      'features': finalFeatures.toList()
    };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/load_log_reg'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body)
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        List<String> classes = List<String>.from(responseData['classes']);
        Map<String, Map<String, double>> coefficientsMap = {};
        Map<String, double> interceptsMap = {};

        var serverCoefficients = Map<String, dynamic>.from(responseData['coefficients']);
        var serverIntercepts = Map<String, dynamic>.from(responseData['intercepts']);

        serverCoefficients.forEach((key, value) {
          coefficientsMap[key] = Map<String, double>.from(value);
        });
        serverIntercepts.forEach((key, value) {
          interceptsMap[key] = value.toDouble();
        });

        print('classes:');
        print(classes);
        print('coefficientsMap:');
        print(coefficientsMap);
        print('interceptsMap:');
        print(interceptsMap);

        setState(() {
          modelParameters = {
            'intercepts': interceptsMap,
            'coefficients': coefficientsMap,
            'classes': classes
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

  Future<void> trainLogReg() async {
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

    final body = {
      'features': finalFeatures.toList(),
      'target': finalTarget,
      'dataset': data
    };

    try {
      final response = await http.post(
          Uri.parse('http://127.0.0.1:5000/train_log_reg'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      print('Raw server response: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        List<String> classes = List<String>.from(responseData['classes']);
        Map<String, Map<String, double>> coefficientsMap = {};
        Map<String, double> interceptsMap = {};

        var serverCoefficients =
            Map<String, dynamic>.from(responseData['coefficients']);
        var serverIntercepts =
            Map<String, dynamic>.from(responseData['intercepts']);

        serverCoefficients.forEach((key, value) {
          coefficientsMap[key] = Map<String, double>.from(value);
        });
        serverIntercepts.forEach((key, value) {
          interceptsMap[key] = value.toDouble();
        });

        print('classes:');
        print(classes);
        print('coefficientsMap:');
        print(coefficientsMap);
        print('interceptsMap:');
        print(interceptsMap);

        setState(() {
          modelParameters = {
            'intercepts': interceptsMap,
            'coefficients': coefficientsMap,
            'classes': classes
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
    final url = Uri.parse('http://127.0.0.1:5000/infer_log_reg');
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
                    isCreate: widget.isCreate
                  ))
                ]),
                Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
                if (widget.isCreate == true) ...[
                  const SizedBox(height: 10),
                  TrainButton(
                    onTrainModel: trainLogReg,
                    modelParameters: modelParameters
                  ),
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
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: finalFeatures.length,
                    itemBuilder: (context, index) {
                      String feature = finalFeatures.elementAt(index);
                      return ParameterGraph(
                          feature: feature,
                          coefficientsMap: modelParameters['coefficients'],
                          interceptsMap: modelParameters['intercepts'],
                          classes: modelParameters['classes'],
                          target: finalTarget!,
                          data: data);
                    },
                  ),
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
                    isCreate: widget.isCreate,
                  ),
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
        onPressed: widget.onTrainModel,
        child: Text(
          widget.modelParameters!.isEmpty ? 'TRAIN MODEL' : 'RETRAIN MODEL',
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

class ParameterGraph extends StatelessWidget {
  final String feature;
  final Map<String, Map<String, double>> coefficientsMap;
  final Map<String, double> interceptsMap;
  final String target;
  final List<String> classes;
  final dynamic data;

  const ParameterGraph(
      {Key? key,
      required this.feature,
      required this.coefficientsMap,
      required this.interceptsMap,
      required this.target,
      required this.classes,
      required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.brown
    ];

    List<double> featureValues =
        (data as List<dynamic>).map((e) => e[feature] as double).toList();
    double minFeatureValue = featureValues.reduce(min);
    double maxFeatureValue = featureValues.reduce(max);
    List<double> featureRange = List.generate(
        100,
        (index) =>
            minFeatureValue +
            ((maxFeatureValue - minFeatureValue) / 99 * index));

    List<LineChartBarData> lineBarsData = classes.map((className) {
      final color = colors[classes.indexOf(className) % colors.length];

      // Hypothetical case of binary logistic regression
      String positiveClass = coefficientsMap.keys.first;
      double intercept = interceptsMap.containsKey(className)
          ? interceptsMap[className]!
          : -interceptsMap[positiveClass]!;
      Map<String, double> coefficients = coefficientsMap.containsKey(className)
          ? coefficientsMap[className]!
          : {feature: -coefficientsMap[positiveClass]![feature]!};

      List<FlSpot> spots = featureRange.map((x) {
        final z = intercept + coefficients[feature]! * x;
        final probability = 1 / (1 + exp(-z));
        return FlSpot(x, probability);
      }).toList();

      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "$target probability vs. \u0394$feature",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'FiraCode',
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(color: Colors.white, thickness: 0.5, height: 20),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LineChart(
                LineChartData(
                    lineBarsData: lineBarsData,
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                        show: true, border: Border.all(color: Colors.white))),
              ),
            ),
          ),
          const Divider(color: Colors.white, thickness: 0.5, height: 20),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: classes.map((className) {
                  final color = colors[classes.indexOf(className) % colors.length];
                  final double oddsRatio = exp(coefficientsMap[className]?[feature] ?? -coefficientsMap[coefficientsMap.keys.first]![feature]!);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 10),
                        Container(
                          width: 20,
                          height: 20,
                          color: color,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "$className: Odds Ratio = $oddsRatio",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'FiraCode',
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
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
            algoName: 'log_reg',
            features: widget.features,
            target: widget.target,
            data: widget.data
          )
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
        onPressed: widget.onInference,
        child: Text(
          'PREDICT',
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
        body: json.encode(body)
      );

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
                  child: Text(
                    "NAME YOUR MODEL",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.white,
                        fontFamily: 'FiraCode'
                    )
                  ),
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
                            errorText:
                                showError ? errorMessage : null,
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
                        child: const Text(
                          'SAVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'FiraCode'
                          )
                        ),
                      )
                    )
                ]
              );
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
