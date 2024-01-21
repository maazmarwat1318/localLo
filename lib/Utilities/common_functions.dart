import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';

class CommonFunctions {
  static Future<File?> getImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo =
        await picker.pickImage(source: ImageSource.camera, maxWidth: 300);
    File? imageFile;
    if (photo != null) {
      imageFile = File(photo.path);
    }
    return imageFile;
  }

  static double roundDouble(double value, int places) {
    double mod = pow(10.0, places) as double;
    return ((value * mod).round().toDouble() / mod);
  }
}
