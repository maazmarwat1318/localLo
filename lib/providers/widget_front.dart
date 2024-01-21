import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class WidgetFront with ChangeNotifier {
  List<Marker> routeMarkers = [];
  List<LatLng> decodedPolyline = [];
  LatLng origin = LatLng(0, 0);

  void addMarkerstoroute(List<Marker> markers) {
    routeMarkers = [];
    routeMarkers.addAll(markers);
    notifyListeners();
  }

  void changeOrigin(loc) {
    origin = loc;
    notifyListeners();
  }

  void changeOriginUnotified(loc) {
    origin = loc;
    notifyListeners();
  }

  void addDecodedPolyline(List<LatLng> polyList) {
    decodedPolyline = [];
    decodedPolyline.addAll(polyList);
    notifyListeners();
  }

  void addDecodedPolylineAndOrigin(loc, List<LatLng> polyList) {
    origin = loc;
    decodedPolyline = [];
    decodedPolyline.addAll(polyList);
    notifyListeners();
  }
}
