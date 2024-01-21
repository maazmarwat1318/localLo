import 'package:flutter/cupertino.dart';

class LoadControl with ChangeNotifier {
  List requestLoaders = [];
  bool sharedRideCancel = false;
  bool sharedRideLeave = false;
  bool readyRideLeave = false;
  bool readyRideCancel = false;
  Map rideSimilarityScores = {};
  void setReadyRideLeave(bool val) {
    readyRideLeave = val;
    notifyListeners();
  }

  void setReadyRideCancel(bool val) {
    readyRideCancel = val;
    notifyListeners();
  }

  void setSharedRideCancel(bool val) {
    sharedRideCancel = val;
    notifyListeners();
  }

  void setSharedRideLeave(bool val) {
    sharedRideLeave = val;
    notifyListeners();
  }

  // void setInRequestLoader(id) async {
  //   requestLoaders.removeWhere((element) => false);
  // }
}
