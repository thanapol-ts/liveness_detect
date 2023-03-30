// ignore_for_file: unrelated_type_equality_checks

import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceScanWidget extends StatefulWidget {
  const FaceScanWidget({super.key, required this.onChange});

  final ValueChanged<int> onChange;

  @override
  State<FaceScanWidget> createState() => _FaceScanWidgetState();
}

class _FaceScanWidgetState extends State<FaceScanWidget> {
  late CameraController? cameraController;
  late CameraValue cameraValue;
  late CameraDescription frontCamera;

  bool isCameraInitialize = false;

  int stepIndex = 0;
  double faceHeightOffset = 100;
  double headZAngleOffset = 3;
  double headZAngleBase = 0;
  double blinkOffset = 0.15;
  int bottomMouthBase = 0;
  int bottomMouthOffset = 50;

  static List<String> listState = [
    "Put you face on frame",
    "Blink your eye",
    "Turn head left",
    "Tuen head right",
    "Open your mount",
    "Ok"
  ];

  @override
  void initState() {
    super.initState();
    isCameraAvailable();
  }

  isCameraAvailable() {
    availableCameras().then((listCamera) {
      for (var camera in listCamera) {
        log("camera == ${listCamera.length}");
        if (camera.lensDirection.name == 'front') {
          cameraController = CameraController(
            camera,
            ResolutionPreset.medium,
          );

          cameraController!.initialize().then((_) {
            if (!mounted) {
              return;
            }

            cameraValue = cameraController!.value;
            frontCamera = camera;

            Future.delayed(const Duration(seconds: 3)).then((value) {
              cameraController!.startImageStream((cameraImage) {
                faceDetect(image: cameraImage);
              }).catchError((error) {
                log("error == ${error}");
              });
            });

            setState(() {
              isCameraInitialize = true;
            });
          }).catchError((Object e) {
            if (e is CameraException) {
              switch (e.code) {
                case 'CameraAccessDenied':
                  log("user denid camera");
                  break;

                default:
                  log("handle error");
                  break;
              }
            }
          });
        }
      }
    });
  }

  void faceDetect({required CameraImage image}) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final imageRotation =
        InputImageRotationValue.fromRawValue(frontCamera.sensorOrientation);
    if (imageRotation == null) return;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return;

    final planeData = image.planes.map((Plane plane) {
      return InputImagePlaneMetadata(
        bytesPerRow: plane.bytesPerRow,
        height: plane.height,
        width: plane.width,
      );
    }).toList();

    final inputImageData = InputImageData(
        size: imageSize,
        imageRotation: imageRotation,
        inputImageFormat: inputImageFormat,
        planeData: planeData);

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    final options = FaceDetectorOptions(
        enableLandmarks: true,
        enableTracking: true,
        enableClassification: true,
        enableContours: true);
    final faceDetector = FaceDetector(options: options);

    final List<Face> faces = await faceDetector.processImage(inputImage);

    log('found face = ${faces.length}');

    if (faces.isNotEmpty) {
      log("detect step : $stepIndex");

      final Rect boundingBox = faces.first.boundingBox;
      final noseBase = faces.first.landmarks[FaceLandmarkType.noseBase];
      final bottomMouth = faces.first.landmarks[FaceLandmarkType.bottomMouth];
      final leftEyeOpen = faces.first.leftEyeOpenProbability;
      final rightEyeOpen = faces.first.rightEyeOpenProbability;
      final headEulerAnglez = faces.first.headEulerAngleZ;

      log('face distance : ${boundingBox.height} || faceHeightOffset :$faceHeightOffset');
      log('face center : ${boundingBox.center.distance}');
      log('nose position  : x = ${noseBase!.position.x} y = ${noseBase.position.y}');
      log('leftEyeOpen  : $leftEyeOpen');
      log('rightEyeOpen  : $rightEyeOpen');
      log('bottomMouth  : ${bottomMouth!.position.y}');
      log('headEulerAnglez  : $headEulerAnglez');

      if ((boundingBox.height > faceHeightOffset)) {
        if (stepIndex < 1) {
          changeStateDection(1);
        }
      } else {
        changeStateDection(0);
      }

      if (stepIndex > 0) {
        switch (stepIndex) {
          case 1:
            {
              log('step Blink detection');
              if ((leftEyeOpen! < blinkOffset) &&
                  (rightEyeOpen! < blinkOffset)) {
                log("step blink detection: yes");
                headZAngleBase = headEulerAnglez!;
                bottomMouthBase = bottomMouth.position.y;
                changeStateDection(2);
              }
            }
            break;
          case 2:
            {
              log('step Turn head left');
              if (headEulerAnglez! < (headZAngleBase - headZAngleOffset)) {
                log("step  Turn head left: yes");
                changeStateDection(3);
              }
            }
            break;
          case 3:
            {
              log('step Turn head right');
              if (headEulerAnglez! > (headZAngleBase + headZAngleOffset)) {
                log("step Turn head right: yes");
                changeStateDection(4);
              }
            }

            break;
          case 4:
            {
              log('step Open your mount');
              if (bottomMouth.position.y >
                  (bottomMouthBase + bottomMouthOffset)) {
                log("step Open your mount");
                changeStateDection(5);
              }
            }
            break;
          case 5:
            {
              log('Ok');
            }
            break;
          default:
        }
      }
    }
  }

  changeStateDection(int state) {
    setState(() {
      stepIndex = state;
    });
  }

  @override
  void dispose() {
    cameraController!.stopImageStream();
    cameraController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCameraInitialize) {
      return LayoutBuilder(builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
                child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth,
              child: Center(
                child: LayoutBuilder(builder: (context, constraints) {
                  var scale = (constraints.maxWidth / constraints.maxHeight) *
                      cameraValue.aspectRatio;
                  if (scale < 1) scale = 1 / scale;
                  return Transform.scale(
                    scale: scale,
                    child: CameraPreview(cameraController!),
                  );
                }),
              ),
            )),
            const SizedBox(
              height: 50,
            ),
            Text(listState[stepIndex]),
            const SizedBox(
              height: 50,
            ),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    stepIndex = 0;
                  });
                },
                child: Text("click"))
          ],
        );
      });
    } else {
      return Container();
    }
  }
}
