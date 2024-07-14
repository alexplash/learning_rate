import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

class KMeansOverviewPage extends StatefulWidget {
  const KMeansOverviewPage(
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
  State<KMeansOverviewPage> createState() => _KMeansOverviewPageState();
}

class _KMeansOverviewPageState extends State<KMeansOverviewPage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  dynamic data;
  List<String> selectedFeatures = [];
  List<String> finalFeatures = [];
  TextEditingController numClusters = TextEditingController();
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

    setState(() {
      finalFeatures = List<String>.from(selectedFeatures);
    });

    final body = {
      'features': finalFeatures.toList()
    };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/load_k_means'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body)
      );
      
      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        dynamic newData = responseData['new_dataset'];

        Map<String, Map<String, double>> centers = {};
        var rawCenters = responseData['centers'] as Map<dynamic, dynamic>;
        rawCenters.forEach((key, value) {
          var featureMap = Map<String, double>.from(value.map(
              (featureKey, featureValue) => MapEntry(featureKey.toString(),
                  double.parse(featureValue.toString()))));
          centers[key.toString()] = featureMap;
        });

        List<String> classLabels = [];
        var rawClassLabels = responseData['class_labels'];
        rawClassLabels.forEach((value) {
          String classLabel = value.toString();
          classLabels.add(classLabel);
        });

        Map<String, double> clusterInertias = {};
        var rawClusterInertias =
            responseData['cluster_inertias'] as Map<String, dynamic>;
        rawClusterInertias.forEach((key, value) {
          clusterInertias[key] = double.parse(value.toString());
        });

        Map<String, int> clusterSizes = {};
        var rawClusterSizes = responseData['cluster_sizes'];
        rawClusterSizes.forEach((key, value) {
          clusterSizes[key] = int.tryParse(value.toString()) ?? 0;
        });

        setState(() {
          modelParameters = {
            'newData': newData,
            'centers': centers,
            'classLabels': classLabels,
            'clusterInertias': clusterInertias,
            'clusterSizes': clusterSizes
          };
        });
        print('Model loaded successfully');
      } else {
        print('Failed to load model. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
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

  Future<void> trainKMeans() async {
    if (selectedFeatures.isEmpty) {
      setState(() {
        errorMessage = 'Please select features';
      });
      return;
    }

    setState(() {
      isLoading = true;
      finalFeatures = List<String>.from(selectedFeatures);
    });

    int nc = numClusters.text.isNotEmpty ? int.parse(numClusters.text) : 3;

    if (nc > 8) {
      setState(() {
        errorMessage = 'Maximum clusters is 8';
      });
      return;
    }

    final body = {
      'features': finalFeatures.toList(),
      'dataset': data,
      'n_clusters': nc
    };

    try {
      final response = await http.post(
          Uri.parse('http://127.0.0.1:5000/train_k_means'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        dynamic newData = responseData['new_dataset'];

        Map<String, Map<String, double>> centers = {};
        var rawCenters = responseData['centers'] as Map<dynamic, dynamic>;
        rawCenters.forEach((key, value) {
          var featureMap = Map<String, double>.from(value.map(
              (featureKey, featureValue) => MapEntry(featureKey.toString(),
                  double.parse(featureValue.toString()))));
          centers[key.toString()] = featureMap;
        });

        List<String> classLabels = [];
        var rawClassLabels = responseData['class_labels'];
        rawClassLabels.forEach((value) {
          String classLabel = value.toString();
          classLabels.add(classLabel);
        });

        Map<String, double> clusterInertias = {};
        var rawClusterInertias =
            responseData['cluster_inertias'] as Map<String, dynamic>;
        rawClusterInertias.forEach((key, value) {
          clusterInertias[key] = double.parse(value.toString());
        });

        Map<String, int> clusterSizes = {};
        var rawClusterSizes = responseData['cluster_sizes'];
        rawClusterSizes.forEach((key, value) {
          clusterSizes[key] = int.tryParse(value.toString()) ?? 0;
        });

        setState(() {
          modelParameters = {
            'newData': newData,
            'centers': centers,
            'classLabels': classLabels,
            'clusterInertias': clusterInertias,
            'clusterSizes': clusterSizes
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
    final url = Uri.parse('http://127.0.0.1:5000/infer_k_means');
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

  String dataToCSV(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return '';
    }

    final headers = data.first.keys;
    final csvData = StringBuffer();

    csvData.writeln(headers.join(','));

    for (var map in data) {
      csvData.writeln(headers.map((header) => map[header]).join(','));
    }

    return csvData.toString();
  }

  void downloadData(dynamic data) {
    List<Map<String, dynamic>> translatedData =
        List<Map<String, dynamic>>.from(data);

    final csvString = dataToCSV(translatedData);

    final bytes = utf8.encode(csvString);
    final blob = html.Blob([bytes], 'text/csv', 'native');

    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'data.csv')
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
                          setFeature: setFeature,
                          isCreate: widget.isCreate))
                ]),
                Divider(color: Colors.grey[600], thickness: 0.5, height: 20),
                if (widget.isCreate == true) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: numClusters,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FiraCode'),
                    decoration: InputDecoration(
                      labelText: 'Number of Clusters: Default = 3; Max = 8',
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
                      onTrainModel: trainKMeans,
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
                      classLabels: modelParameters['classLabels'],
                      clusterInertias: modelParameters['clusterInertias'],
                      clusterSizes: modelParameters['clusterSizes'],
                      newData: modelParameters['newData'],
                    ),
                  ]),
                  const SizedBox(height: 20),
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
                      return ClusterGraph(
                          feature: feature,
                          classLabels: modelParameters['classLabels'],
                          centers: modelParameters['centers'],
                          newData: modelParameters['newData']);
                    },
                  ),
                  const SizedBox(height: 20),
                  DownloadDataButton(onDownload: () {
                    downloadData(modelParameters['newData']);
                  }),
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
                    target: 'cluster',
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
  final Function(String) setFeature;
  final bool isCreate;

  const DataSummaryWidget(
      {Key? key,
      required this.data,
      required this.selectedFeatures,
      required this.setFeature,
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
                            ],
                          )
                        ]))
                .toList())
      ],
    );
  }
}

class ModelInfoSection extends StatefulWidget {
  final List<String> classLabels;
  final Map<String, double> clusterInertias;
  final Map<String, int> clusterSizes;
  final dynamic newData;

  const ModelInfoSection(
      {Key? key,
      required this.classLabels,
      required this.clusterInertias,
      required this.clusterSizes,
      required this.newData})
      : super(key: key);

  @override
  _ModelInfoSectionState createState() => _ModelInfoSectionState();
}

class _ModelInfoSectionState extends State<ModelInfoSection> {
  @override
  Widget build(BuildContext context) {
    int totalSize = widget.newData.length;

    return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Class Labels: ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 10),
            ...widget.classLabels.map((label) => Text('Class $label',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'FiraCode'))),
            const SizedBox(height: 20),
            const Text('Cluster Inertias: ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 10),
            ...widget.clusterInertias.entries.map((entry) => Text(
                'Class ${entry.key}: ${entry.value}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'FiraCode'))),
            const SizedBox(height: 20),
            const Text('Cluster Sizes: ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FiraCode',
                )),
            const SizedBox(height: 10),
            ...widget.clusterSizes.entries.map((entry) {
              double percentage = entry.value / totalSize * 100;
              String formattedPercentage = percentage.toStringAsFixed(2);

              return Text(
                  'Class ${entry.key}: ${entry.value} ($formattedPercentage%)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'FiraCode'));
            }),
          ],
        ));
  }
}

class ClusterGraph extends StatelessWidget {
  final String feature;
  final List<String> classLabels;
  final Map<String, Map<String, double>> centers;
  final dynamic newData;

  const ClusterGraph(
      {Key? key,
      required this.feature,
      required this.classLabels,
      required this.centers,
      required this.newData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, Color> clusterColors = {
      '0': Colors.red,
      '1': Colors.green,
      '2': Colors.blue,
      '3': Colors.yellow,
      '4': Colors.orange,
      '5': Colors.purple,
      '6': Colors.pink,
      '7': Colors.brown
    };

    double maxX = newData
        .map((map) => map[feature].toDouble())
        .reduce((a, b) => a > b ? a : b);
    double minX = newData
        .map((map) => map[feature].toDouble())
        .reduce((a, b) => a < b ? a : b);
    double maxY = newData
        .map((map) => map['cluster'].toDouble())
        .reduce((a, b) => a > b ? a : b);

    Map<String, List<FlSpot>> clusterDataPoints = {};
    for (int i = 0; i < newData.length; i++) {
      final double x = newData[i][feature].toDouble();
      final double y = newData[i]['cluster'].toDouble();
      clusterDataPoints.putIfAbsent(y.toString(), () => []);
      clusterDataPoints[y.toString()]!.add(FlSpot(x, y));
    }

    centers.forEach((clusterKey, features) {
      if (features.containsKey(feature)) {
        double centroidValue = features[feature]!;
        clusterDataPoints[clusterKey]
            ?.add(FlSpot(centroidValue, double.parse(clusterKey)));
      }
    });

    List<LineChartBarData> lines = clusterDataPoints.entries.map((entry) {
      return LineChartBarData(
          spots: entry.value,
          isCurved: false,
          color: clusterColors[entry.key],
          barWidth: 0.25,
          dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isCentroid = centers[entry.key]![feature] == spot.x;
                return FlDotCirclePainter(
                    radius: isCentroid ? 8 : 4,
                    color: barData.color!,
                    strokeColor: isCentroid ? Colors.white : Colors.transparent,
                    strokeWidth: 2);
              }),
          belowBarData: BarAreaData(show: false));
    }).toList();

    return Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Text(
            'Cluster vs. $feature',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontFamily: 'FiraCode'),
            textAlign: TextAlign.center,
          ),
          const Divider(color: Colors.white, thickness: 0.5, height: 20),
          const SizedBox(height: 10),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData:
                        LineTouchTooltipData(getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.x}, ${spot.y}',
                          const TextStyle(color: Colors.black),
                        );
                      }).toList();
                    })),
                lineBarsData: lines,
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
              ),
            ),
          )),
          const Divider(color: Colors.white, thickness: 0.5, height: 20),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: classLabels.map((classLabel) {
                    final color = clusterColors[classLabel];
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 10),
                          Container(
                            width: 20,
                            height: 20,
                            color: color,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Class $classLabel",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'FiraCode',
                            ),
                          )
                        ]));
                  }).toList())
            ],
          ),
          const SizedBox(height: 20),
        ]));
  }
}

class DownloadDataButton extends StatefulWidget {
  final VoidCallback onDownload;

  const DownloadDataButton({Key? key, required this.onDownload})
      : super(key: key);

  @override
  _DownloadDataButtonState createState() => _DownloadDataButtonState();
}

class _DownloadDataButtonState extends State<DownloadDataButton> {
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
          "DOWNLOAD DATA",
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
              algoName: 'k_means',
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
      'dataset': widget.data
    };

    try {
      final response = await http.post(
          Uri.parse('http://127.0.0.1:5000/save_unsupervised'),
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
