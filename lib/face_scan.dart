import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:liveness_detect/face_scan_widget.dart';

class FaceScanPage extends StatelessWidget {
  const FaceScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Center(
        child: FaceScanWidget(
          onChange: (value) {
            log("face scan result : ${value}");
          },
        ),
      ),
    );
  }
}