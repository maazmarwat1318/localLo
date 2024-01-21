import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:local_lo/Utilities/colors_typography.dart';
import 'package:local_lo/Utilities/common_functions.dart';

import 'package:local_lo/Utilities/custom_styles.dart';
import 'package:local_lo/Utilities/keys.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

class RideRoute with ChangeNotifier {
  String? pickUpAddress;
  String? destinationAddress;
  String? city;
  LatLng? pickUpLatLng;
  LatLng? destinationLatLng;

  final _sessionToken = const Uuid().v4();
  final mapController = Completer<GoogleMapController>();
  List<Marker> markers = [
    const Marker(markerId: MarkerId('1')),
    const Marker(markerId: MarkerId('2'))
  ];
  bool? isPickUpSelected;
  bool isChooseMapSelected = false;

  LatLng currentLocation = const LatLng(34.0151, 71.5249);
  String? currentLocationAddress;

  bool isChooseMapLoading = false;
  bool isCurrentLocationLoading = false;
  bool isRequestSubmitting = false;

  void setRequestSubmitting(bool status) {
    isRequestSubmitting = status;
    notifyListeners();
  }

  void setChooseMapLoading(bool status) {
    isChooseMapLoading = status;
    notifyListeners();
  }

  void setCurrentLocationLoading(bool status) {
    isCurrentLocationLoading = status;
    notifyListeners();
  }

  void setIsPickUpSelected(status) {
    isPickUpSelected = status;
    notifyListeners();
  }

  void setIsChooseMapSelected(status) {
    isChooseMapSelected = status;
    notifyListeners();
  }

  void resetPickUp() {
    pickUpAddress = null;
    pickUpLatLng = null;
    markers[0] = const Marker(markerId: MarkerId('1'));
    notifyListeners();
  }

  void resetDestination() {
    destinationAddress = null;
    destinationLatLng = null;
    markers[1] = const Marker(markerId: MarkerId('1'));
    notifyListeners();
  }

  void setDestinatioAddress(String value) {
    destinationAddress = value;
    notifyListeners();
  }

  void setPickUpAddress(String value) {
    pickUpAddress = value;
    notifyListeners();
  }

  void setPickUp(LatLng value, String address) {
    pickUpLatLng = value;
    pickUpAddress = address;
    notifyListeners();
  }

  void setDestination(LatLng value, String address) {
    destinationLatLng = value;
    destinationAddress = address;
    notifyListeners();
  }

  Future getCurrentLocation() async {
    Location location = Location();

    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        throw 'error';
      }
    }
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw 'error';
      }
    }
    try {
      locationData = await location.getLocation();
      currentLocation = LatLng(
        CommonFunctions.roundDouble(locationData.latitude!, 5),
        CommonFunctions.roundDouble(locationData.longitude!, 5),
      );
      return;
    } catch (e) {
      rethrow;
    }
  }

  Future setPickUptoCurrentLocation() async {
    if (currentLocationAddress != null) {
      pickUpAddress = currentLocationAddress;
      pickUpLatLng = currentLocation;
      markers.removeAt(0);
      markers.insert(
        0,
        Marker(
          markerId: MarkerId("${pickUpLatLng!.latitude}"),
          position: currentLocation,
          icon: await const TextIconMarker(
            fontSize: 16,
            text: 'Pick Up',
            iconData: FontAwesome5.map_pin,
          ).toBitmapDescriptor(),
        ),
      );
      notifyListeners();
      return;
    }
    try {
      currentLocationAddress =
          await convertCoordinatesToAddress(currentLocation);
    } catch (e) {
      rethrow;
    }

    pickUpAddress = currentLocationAddress;
    pickUpLatLng = currentLocation;
    markers.removeAt(0);
    markers.insert(
      0,
      Marker(
        markerId: MarkerId("${pickUpLatLng!.latitude}"),
        position: currentLocation,
        icon: await const TextIconMarker(
          text: 'Pick Up',
          fontSize: 16,
          iconData: FontAwesome5.map_pin,
        ).toBitmapDescriptor(),
      ),
    );
    notifyListeners();
  }

  Future<List> getSearchPlaces(String input) async {
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${Keys.mapsApiKey}&sessiontoken=$_sessionToken&components=country:pk");

    List places = [];
    try {
      final response = await get(url);

      if (response.statusCode != 200) {
        throw 'Make Sure you have a working internet Connection';
      }
      places = jsonDecode(response.body)['predictions']
          .map((e) => {
                'description': e['structured_formatting']['main_text'],
                'sub_title': e['structured_formatting']['secondary_text']
                    .replaceAll(RegExp(', Pakistan'), ''),
                'place_id': e['place_id'],
              })
          .toList();
    } catch (e) {
      rethrow;
    }
    // places = places.map((e) => e['description']).toList();

    // print(places);
    return places;
  }

  Future<void> getLatLngbyPlaceId(String placeId) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?fields=geometry&place_id=$placeId&key=${Keys.mapsApiKey}');
    try {
      final result = await get(url);
      if (result.statusCode != 200) {
        throw 'Make Sure you have a working internet Connection';
      }
      final decodedResults = jsonDecode(result.body);
      if (decodedResults["status"] == "OK") {
        final lat = decodedResults['result']['geometry']['location']['lat'];
        final lng = decodedResults['result']['geometry']['location']['lng'];
        if (isPickUpSelected == true) {
          pickUpLatLng = LatLng(CommonFunctions.roundDouble(lat, 5),
              CommonFunctions.roundDouble(lng, 5));
          return;
        }
        if (isPickUpSelected == false) {
          destinationLatLng = LatLng(CommonFunctions.roundDouble(lat, 5),
              CommonFunctions.roundDouble(lng, 5));

          return;
        }
        return;
      }
      throw 'Unexpected Network error Occurred! Please try Later';
    } catch (e) {
      rethrow;
    }
  }

  Future convertCoordinatesToAddress(LatLng value) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${value.latitude},${value.longitude}&result_type=establishment|premise|street_address|route&key=${Keys.mapsApiKey}');
    try {
      final result = await get(url).catchError((_) {
        throw 'Network error! Can not get current Location Address';
      });
      if (result.statusCode != 200) {
        throw 'Network error! Can not get current Location Address';
      }

      if (result.statusCode == 200) {
        final decodedResult = json.decode(result.body);
        if (decodedResult['status'] == 'ZERO_RESULTS') {
          throw 'No address found for this Location please choose a nearby place';
        }
        if (decodedResult['status'] == 'OK') {
          final address = decodedResult['results'][0]['formatted_address'];

          if (isPickUpSelected != false) {
            String? cityName;
            for (var component in decodedResult['results'][0]
                ['address_components']) {
              if (component['types'].contains('locality')) {
                cityName = component['long_name'];
              }
            }
            if (cityName == null) {
              throw 'We are not available in your city';
            }
            cityName = cityName.toString().toLowerCase().replaceAll(' ', '');
            city = cityName;
          }
          return address;
        }
        throw 'Unexpected Network Error Occured! Please try Again';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> goToLocation(LatLng location) async {
    final GoogleMapController controller = await mapController.future;
    CameraPosition locationPosition = CameraPosition(
      target: location,
      zoom: CustomStyles.defaultMapZoom,
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(locationPosition));
    controller.dispose();
  }

  Future<void> setMarker(LatLng location, double hue) async {
    if (isPickUpSelected == true) {
      markers.removeAt(0);
      markers.insert(
        0,
        Marker(
          markerId: MarkerId("${location.latitude}"),
          position: location,
          icon: await const TextIconMarker(
            text: 'Pick Up',
            fontSize: 16,
            iconData: FontAwesome5.map_pin,
          ).toBitmapDescriptor(),
        ),
      );
      notifyListeners();
    }
    if (isPickUpSelected == false) {
      markers.removeAt(1);
      markers.insert(
          1,
          Marker(
            markerId: MarkerId("${location.latitude}"),
            position: location,
            icon: await const TextIconMarker(
              text: 'Destination',
              iconData: FontAwesome5.map_pin,
              fontSize: 16,
            ).toBitmapDescriptor(),
          ));
      notifyListeners();
    }
  }

  Future checkRoute(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse(
          'https://routes.googleapis.com/directions/v2:computeRoutes');
      final body = {
        "origin": {
          "sideOfRoad": true,
          "location": {
            "latLng": {
              "latitude": origin.latitude,
              "longitude": origin.longitude
            }
          }
        },
        "destination": {
          "sideOfRoad": true,
          "location": {
            "latLng": {
              "latitude": destination.latitude,
              "longitude": destination.longitude
            }
          }
        },
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
        "computeAlternativeRoutes": false,
        "languageCode": "en-US",
        "units": "IMPERIAL"
      };
      final responseRoute = await post(url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': Keys.mapsApiKey,
            'X-Goog-FieldMask': 'routes.distanceMeters'
          },
          body: jsonEncode(body));
      final routeInfo = jsonDecode(responseRoute.body);
      final distance = routeInfo['routes'][0]['distanceMeters'] / 1000;
      return distance;
    } catch (e) {
      rethrow;
    }
  }

  Future submitRideRequest(Map<String, dynamic> requestInfo,
      Map<String, dynamic> requestStatus) async {
    final db = FirebaseFirestore.instance;
    final id = FirebaseAuth.instance.currentUser!.uid;

    final path = db.collection('shared_ride_requests').doc(city);

    try {
      await db.runTransaction((transaction) async {
        transaction.set(
            path.collection('pending_requests').doc(id), requestInfo);
        transaction.set(
            path.collection('pending_requests_status').doc(id), requestStatus);
        transaction.set(path.collection('chat').doc(id), {'chat': []});
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isSharedRequestLive', true);
    prefs.setString('city', city!);
  }
}

class TextIconMarker extends StatelessWidget {
  const TextIconMarker({
    Key? key,
    required this.fontSize,
    required this.text,
    required this.iconData,
  }) : super(key: key);
  final double fontSize;
  final String text;
  final IconData iconData;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: ColorsTypography.primaryColor,
              borderRadius: BorderRadius.all(
                Radius.circular(20),
              ),
            ),
            child: Text(
              maxLines: 2,
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            )),
        const SizedBox(
          height: 5,
        ),
        const Icon(
          FontAwesome5.map_pin,
          size: 30,
          color: ColorsTypography.primaryColor,
        )
      ],
    );
  }
}
