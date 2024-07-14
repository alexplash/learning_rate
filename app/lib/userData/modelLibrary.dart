import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '/modelCreation/linRegOverview.dart';
import '/modelCreation/logRegOverview.dart';
import '/modelCreation/ranForOverview.dart';
import '/modelCreation/gradBoostRegOverview.dart';
import '/modelCreation/kMeansOverview.dart';

class ModelLibraryPage extends StatefulWidget {
  const ModelLibraryPage({super.key});

  @override
  State<ModelLibraryPage> createState() => _ModelLibraryPageState();
}

class _ModelLibraryPageState extends State<ModelLibraryPage> {
  bool isLoading = true;
  List<String> modelNames = [];

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await fetchModelNames();
    });
  }

  Future<void> fetchModelNames() async {
    setState(() {
      isLoading = true;
    });
    try {
      var response = await http.get(
        Uri.parse("http://127.0.0.1:5000/fetch_model_names")
      );
      if (response.statusCode == 200) {
        List<String> responseData = List<String>.from(json.decode(response.body));
        setState(() {
          modelNames = responseData;
        });
      } else {
        throw Exception('Failed to load dataset names with status code ${response.statusCode}: ${response.body}');
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
                ModelBreakdownWidget(modelNames: modelNames),
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

class ModelBreakdownWidget extends StatefulWidget {
  final List<String> modelNames;

  const ModelBreakdownWidget({Key? key, required this.modelNames})
      : super(key: key);

  @override
  _ModelBreakdownWidgetState createState() => _ModelBreakdownWidgetState();
}

class _ModelBreakdownWidgetState extends State<ModelBreakdownWidget> {
  List<String> currentModelNames = [];
  Map<String, dynamic> finalMetadata = {};
  dynamic finalDataset;

  void initState() {
    super.initState();
    currentModelNames = widget.modelNames;
  }

  void showOptionsDialog(BuildContext context, String modelName) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 11, 11, 16),
              actions: <Widget>[
                Column(
                  children: [
                    const SizedBox(height: 20),
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
                            await deleteModel(modelName);
                            Navigator.of(context).pop();
                          },
                          child: const Text("DELETE MODEL",
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
                          onPressed: () async {
                            await fetchModel(modelName);
                            String algoName = finalMetadata['algo_name'];
                            Navigator.of(context).pop();
                            navigateModel(algoName);
                          },
                          child: const Text("USE MODEL",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'FiraCode')))
                    ]))
                  ]
                )
              ]);
        });
  }

  Future<void> deleteModel(String modelName) async {
    try {
      final body = {'model_name': modelName};

      var response = await http.post(
          Uri.parse('http://127.0.0.1:5000/delete_model'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 200) {
        setState(() {
          currentModelNames.remove(modelName);
        });
      } else {
        print('Failed to delete model');
      }
    } catch (e) {
      print('Exception caught: $e');
    }
  }

  Future<void> fetchModel(String modelName) async {
    final body = {
      'model_name': modelName
    };

    try {
      var response = await http.post(
        Uri.parse('http://127.0.0.1:5000/load_model'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body)
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseMap = Map<String, dynamic>.from(json.decode(response.body));
        finalMetadata = Map<String, dynamic>.from(responseMap['metadata']);
        finalDataset = responseMap['dataset'];
      } else {
        print('Failed to load model');
      }
    } catch (e) {
      print('Exception caught: $e');
    }
  }

  void navigateModel(String algoName) {
    if (algoName == 'lin_reg') {
      Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      LinRegOverviewPage(isCreate: false, dataset: finalDataset, metadata: finalMetadata),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
    } else if (algoName == 'log_reg') {
      Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      LogRegOverviewPage(isCreate: false, dataset: finalDataset, metadata: finalMetadata),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
    } else if (algoName == 'random_forest') {
      Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      RanForOverviewPage(isCreate: false, dataset: finalDataset, metadata: finalMetadata),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
    } else if (algoName == 'grad_boost_reg') {
      Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      GradBoostRegOverviewPage(isCreate: false, dataset: finalDataset, metadata: finalMetadata),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child; // No transition
                  },
                ),
              );
    } else if (algoName == 'k_means') {
      Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      KMeansOverviewPage(isCreate: false, dataset: finalDataset, metadata: finalMetadata),
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

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Text(
                    'Saved Models',
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
          children: currentModelNames.map((name) {
            String displayName = name.split('.zip')[0];

            return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ModelCard(
                      name: displayName,
                      onTap: () {
                        showOptionsDialog(context, name);
                      }),
                  const SizedBox(height: 40)
                ]);
          }).toList()),
    ]);
  }
}

class ModelCard extends StatefulWidget {
  final String name;
  final VoidCallback onTap;

  const ModelCard({Key? key, required this.name, required this.onTap})
      : super(key: key);

  @override
  _ModelCardState createState() => _ModelCardState();
}

class _ModelCardState extends State<ModelCard> {
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
                      image: const AssetImage("images/purple_wavy.jpg"),
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