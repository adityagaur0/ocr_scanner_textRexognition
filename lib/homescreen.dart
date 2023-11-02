import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ocr_scanner/result.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// widgetbindingObserver:  to display camera feed in our app ,we will need to have control of the lifecycle
// of our main widget

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  //to manage the the permission to camera is granted.
  bool _isPermissionGranted = false;

  // future will be executed first to request the permission.
  late final Future<void> _future;
  CameraController? _cameraController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _requestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        return GestureDetector(
          onTap: _scanImage,
          child: Stack(
            children: [
              if (_isPermissionGranted)
                FutureBuilder<List<CameraDescription>>(
                  future: availableCameras(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _initCameraController(snapshot.data!);

                      return Center(child: CameraPreview(_cameraController!));
                    } else {
                      return const LinearProgressIndicator(); // to show camera is not granted
                    }
                  },
                ),
              Scaffold(
                appBar: AppBar(
                  title: const Text('Text Recognition Sample'),
                ),
                backgroundColor:
                    _isPermissionGranted ? Colors.transparent : null,
                body: _isPermissionGranted
                    ? Column(
                        children: [
                          Expanded(
                            child: Container(),
                          ),
                          Container(
                            padding: const EdgeInsets.only(bottom: 30.0),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: _scanImage,
                                child: const Text('Scan text'),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Container(
                          padding:
                              const EdgeInsets.only(left: 24.0, right: 24.0),
                          child: const Text(
                            'Camera permission denied',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // private method in charge of requesting the permission and upadating the
  //state based on the result
  //avoid this way to Insted use
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    _isPermissionGranted = status == PermissionStatus.granted;
  }

  //method to open the camera
  void _startCamera() {
    //very imp to check weather camera controller is not null.
    if (_cameraController != null) {
      _cameraSelected(_cameraController!.description);
    }
  }

  //method to close the camera
  void _stopCamera() {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
  }

//method to initalise the camera controller
  void _initCameraController(List<CameraDescription> cameras) {
    //we check the _cameracontroller variable is not already intialised.
    if (_cameraController != null) {
      return; // if so we exit the method
    }

    //select which camera we want
    //iterate all the cameras and choose the first camera which point backward.
    CameraDescription? camera;
    for (var i = 0; i < cameras.length; i++) {
      final CameraDescription current = cameras[i];
      if (current.lensDirection == CameraLensDirection.back) {
        camera = current;
        break;
      }
    }

    //pass to another method
    if (camera != null) {
      _cameraSelected(camera);
    }
  }

  // responsible to initalise the camera already defined
  Future<void> _cameraSelected(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset
          .max, // set resolution to maximum that will help text detection.
      enableAudio: false,
    );

    // asynchronus method to perform initalization
    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);

    // incharget of refreshing the state in order to show already intialized camera.

    if (!mounted) {
      return;
    }
    setState(() {});
  }

//scan image
  Future<void> _scanImage() async {
    //first check camera contrller is not null
    if (_cameraController == null) return;

    //to direct the user to result screen
    final navigator = Navigator.of(context);

    try {
      //obtain picture from camera
      final pictureFile = await _cameraController!.takePicture();

      final file = File(pictureFile.path);

      final inputImage = InputImage.fromFile(file);

      final recognizedText =
          await textRecognizer.processImage(inputImage); //google ml kit

      await navigator.push(
        MaterialPageRoute(
          builder: (BuildContext context) =>
              ResultScreen(textstring: recognizedText.text),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred when scanning text'),
        ),
      );
    }
  }
}
