import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:local_lo/Utilities/common_functions.dart';
import 'package:local_lo/widgets/homescreen_widgets/ride_preferences.dart';
import 'package:local_lo/widgets/shared_ride_request_setup_widgets/passengers.dart';

import 'package:widget_to_marker/widget_to_marker.dart';
import 'package:local_lo/Utilities/keys.dart';
import 'package:local_lo/providers/ride_route.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SharedRide with ChangeNotifier {
  String? city;
  List markers = [];

  Future cancelRequest() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isSharedRequestLive', false);
    FirebaseFirestore.instance.clearPersistence();
  }

  void setCity(String cityName) {
    city = cityName;
  }

  Future sendRequest(Map request, String idToSend) async {
    final db = FirebaseFirestore.instance;
    final path = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests_status');
    try {
      await path.doc(idToSend).update({
        'requests': FieldValue.arrayUnion([request]),
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  Future acceptRequest(String type, Map requestInfo, String requestId) async {
    final db = FirebaseFirestore.instance;
    final path = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests_status');
    final path2 = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests');

    if (type == 'Invite') {
      try {
        await db.runTransaction((transaction) async {
          final requestStatus = await transaction.get(path.doc(requestId));

          if (requestStatus['participants'].length + 1 ==
                  requestStatus['passengers'] ||
              requestStatus['joinedRequestId'] != null) {
            final reqadmin = await transaction
                .get(path.doc(FirebaseAuth.instance.currentUser!.uid));
            final requestremove = reqadmin['requests'] as List;
            requestremove.removeWhere((element) => element['id'] == requestId);
            await path
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .update({'requests': requestremove});
            throw 'unavailable';
          }

          transaction.update(path.doc(FirebaseAuth.instance.currentUser!.uid),
              {'joinedRequestId': requestId, 'requests': []});
          transaction.update(path2.doc(FirebaseAuth.instance.currentUser!.uid),
              {'isAvailable': false, 'requests': []});
          transaction.update(path.doc(requestId), {
            'participants': FieldValue.arrayUnion([requestInfo]),
          });
        }).timeout(const Duration(seconds: 15));
      } catch (e) {
        rethrow;
      }
    }

    if (type == 'Join') {
      try {
        await db.runTransaction((transaction) async {
          final requestStatus = await transaction.get(path.doc(requestId));

          if (requestStatus['participants'].length != 0 ||
              requestStatus['joinedRequestId'] != null) {
            List removeRequest = requestStatus['requests'] as List;
            removeRequest
                .removeWhere((element) => element['id'] == requestStatus.id);

            await path.doc(FirebaseAuth.instance.currentUser!.uid).update({
              'requests': FieldValue.arrayRemove([
                {...requestInfo, 'type': 'Join'}
              ]),
            });
            throw 'unavailable';
          }
          transaction.update(path2.doc(requestId), {'isAvailable': false});
          transaction.update(path.doc(requestId), {
            'joinedRequestId': FirebaseAuth.instance.currentUser!.uid,
            'requests': [],
          });
          transaction.update(path.doc(FirebaseAuth.instance.currentUser!.uid), {
            'participants': FieldValue.arrayUnion([requestInfo]),
            'requests': FieldValue.arrayRemove([
              {...requestInfo, 'type': 'Join'}
            ]),
          });
        }).timeout(const Duration(seconds: 15));
      } catch (e) {
        rethrow;
      }
    }
  }

  Future removeUser(Map user) async {
    final db = FirebaseFirestore.instance;
    final path = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests_status');
    final requestId = user['id'];
    final path2 = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests');
    try {
      await db.runTransaction((transaction) async {
        transaction.update(path2.doc(requestId), {'isAvailable': true});
        transaction.update(path.doc(requestId), {
          'joinedRequestId': null,
        });
        transaction.update(path.doc(FirebaseAuth.instance.currentUser!.uid), {
          'participants': FieldValue.arrayRemove([user]),
        });
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  Future removeUserFromReadyRide(Map user) async {
    final db = FirebaseFirestore.instance;
    final docId = FirebaseAuth.instance.currentUser!.uid;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.update(path.collection('pending_requests').doc(user['id']),
            {'isAvailable': true});
        transaction.update(
            path.collection('pending_requests_status').doc(user['id']),
            {'joinedRequestId': null});
        transaction
            .update(path.collection('ready_requests_status').doc(docId), {
          'participants': FieldValue.arrayRemove([user]),
          'isBroadcasted': false,
          'price': null,
          'suggestedDriverId': null
        });
        transaction.update(path.collection('ready_requests').doc(docId), {
          'isReadyForBroadcast': false,
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendMessage(chatId, userName, message) async {
    try {
      await FirebaseFirestore.instance
          .collection('shared_ride_requests')
          .doc(city)
          .collection('chat')
          .doc(chatId)
          .update(
        {
          'chat': FieldValue.arrayUnion(
            [
              {
                'name': userName,
                'id': FirebaseAuth.instance.currentUser!.uid,
                'message': message,
              }
            ],
          ),
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  Future leaveJoinedRide(joinedRideId, userInfo) async {
    final db = FirebaseFirestore.instance;
    final path = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests_status');

    final path2 = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('pending_requests');

    try {
      await db.runTransaction((transaction) async {
        transaction.update(path2.doc(userInfo['id']), {'isAvailable': true});
        transaction.update(path.doc(userInfo['id']), {
          'joinedRequestId': null,
        });
        transaction.update(path.doc(joinedRideId), {
          'participants': FieldValue.arrayRemove([userInfo]),
        });
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  Future generateCombinedRoute2(Map adminUser, List participantsList) async {
    List waypoints = [
      adminUser['pickupLatLng'],
      adminUser['destinationLatLng'],
    ];
    List wayPointLabels = [
      '${adminUser['name']} \n Pick Up',
      '${adminUser['name']} \n Destination'
    ];

    final List participants = participantsList;

    for (int i = 0; i < participants.length; i++) {
      waypoints.insert(i + (i + 2), participants[i]['pickupLatLng']);
      waypoints.insert(i + (i + 3), participants[i]!['destinationLatLng']);
      wayPointLabels.insert(
          i + (i + 2), '${participants[i]['name']} \n Pickup');
      wayPointLabels.insert(
          i + (i + 3), '${participants[i]['name']} \n Destination');
    }

    String destAPIString = '';
    String pickupAPIString = '';
    for (int i = 0; i < waypoints.length; i++) {
      if (i == 0) {
        pickupAPIString += '${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
      if (i == 1) {
        destAPIString += '${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
      if (i % 2 == 0) {
        pickupAPIString += '%7C${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
      if (i % 2 != 0) {
        destAPIString += '%7C${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
    }
    final response;
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json?destinations=${destAPIString}&origins=${pickupAPIString}&key=${Keys.mapsApiKey}');
      response = await get(url);
    } catch (e) {
      rethrow;
    }

    final decodeResponse = jsonDecode(response.body);
    List<int> distances = [];
    Map maxAt = {'i': 0, 'j': 0};
    for (int i = 0; i < decodeResponse['rows'].length; i++) {
      for (int j = 0; j < decodeResponse['rows'][i]['elements'].length; j++) {
        if (decodeResponse['rows'][i]['elements'][j]['distance']['value'] >
            decodeResponse['rows'][maxAt['i']]['elements'][maxAt['j']]
                ['distance']['value']) {
          maxAt['i'] = i;
          maxAt['j'] = j;
        }
        if (i == j) {
          distances.add(
              decodeResponse['rows'][i]['elements'][j]['distance']['value']);
        }
      }
    }

    final origin = waypoints[maxAt['i'] + maxAt['i']];

    final destination = waypoints[maxAt['j'] + maxAt['j'] + 1];

    waypoints
        .removeWhere((element) => element == origin || element == destination);

    final url =
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final body = {
      "origin": {
        "sideOfRoad": true,
        "location": {
          "latLng": {"latitude": origin['lat'], "longitude": origin['lng']}
        }
      },
      "destination": {
        "sideOfRoad": true,
        "location": {
          "latLng": {
            "latitude": destination['lat'],
            "longitude": destination['lng']
          }
        }
      },
      "intermediates": [
        ...waypoints.map((e) => {
              "sideOfRoad": true,
              "location": {
                "latLng": {"latitude": e['lat'], "longitude": e['lng']}
              }
            })
      ],
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "optimizeWaypointOrder": true,
      "computeAlternativeRoutes": false,
      "languageCode": "en-US",
      "units": "IMPERIAL"
    };
    final responseRoute = await post(url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': Keys.mapsApiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.optimizedIntermediateWaypointIndex'
        },
        body: jsonEncode(body));
    final routeInfo = jsonDecode(responseRoute.body);

    final polylineString =
        routeInfo['routes'][0]['polyline']['encodedPolyline'];
    String durationString = routeInfo['routes'][0]['duration'];
    durationString = durationString.replaceFirst('s', '');
    final duration = int.parse(durationString);
    final distanceMeters = routeInfo['routes'][0]['distanceMeters'];
    final distance = distanceMeters / 1000;
    print('Distances ' + distances.toString());
    List<double> percentageValuesOfFare = calculateShapleyValue(distances);

    final totalShapelyValue =
        percentageValuesOfFare.reduce((value, element) => value + element);
    final percentages = percentageValuesOfFare.map((element) {
      return CommonFunctions.roundDouble((element / totalShapelyValue), 4);
    }).toList();
    print('Shapley Value ' + percentages.toString());
    final percentagesNow = calculatePercentages(distanceMeters, distances);
    print('Percentage Composition ' + percentagesNow.toString());
    final Map fareFactor = {};
    for (int i = 0; i < percentagesNow.length; i++) {
      if (i == 0) {
        fareFactor.addEntries([
          MapEntry(FirebaseAuth.instance.currentUser!.uid, percentagesNow[i]),
        ]);
        continue;
      }
      fareFactor.addEntries([
        MapEntry(participants[i - 1]['id'], percentagesNow[i]),
      ]);
    }

    final db = FirebaseFirestore.instance;
    try {
      await db.runTransaction((transaction) async {
        transaction.update(
            db
                .collection('shared_ride_requests')
                .doc(city)
                .collection('ready_requests_status')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {
              "origin": origin,
              'duration': duration,
              "destination": destination,
              'passengers': FieldValue.increment(-1),
              "distance": distance,
              'price': null,
              'arrivals': null,
              'fareFactor': fareFactor,
              'isBroadcasted': false,
              "polylineString": polylineString,
            });
        transaction.set(
            db
                .collection('shared_ride_requests')
                .doc(city)
                .collection('ready_requests')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isReadyForBroadcast': false});
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      rethrow;
    }
  }

  Future generateCombinedRoute(DocumentSnapshot rideInfo) async {
    List waypoints = [
      rideInfo['adminUser']['pickupLatLng'],
      rideInfo['adminUser']['destinationLatLng']
    ];
    List wayPointLabels = [
      '${rideInfo['adminUser']['name']} \n Pick Up',
      '${rideInfo['adminUser']['name']} \n Destination'
    ];

    final List participants = rideInfo['participants'];

    for (int i = 0; i < participants.length; i++) {
      waypoints.insert(i + (i + 2), participants[i]['pickupLatLng']);
      waypoints.insert(i + (i + 3), participants[i]!['destinationLatLng']);
      wayPointLabels.insert(
          i + (i + 2), '${participants[i]['name']} \n Pickup');
      wayPointLabels.insert(
          i + (i + 3), '${participants[i]['name']} \n Destination');
    }

    String destAPIString = '';
    String pickupAPIString = '';
    for (int i = 0; i < waypoints.length; i++) {
      if (i == 0) {
        pickupAPIString += '${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
      if (i == 1) {
        destAPIString += '${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
      if (i % 2 == 0) {
        pickupAPIString += '%7C${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
      if (i % 2 != 0) {
        destAPIString += '%7C${waypoints[i]['lat']}%2C${waypoints[i]['lng']}';
        continue;
      }
    }
    final response;
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json?destinations=${destAPIString}&origins=${pickupAPIString}&key=${Keys.mapsApiKey}');
      response = await get(url);
    } catch (e) {
      rethrow;
    }

    final decodeResponse = jsonDecode(response.body);
    print(decodeResponse.toString());
    List<int> distances = [];
    Map maxAt = {'i': 0, 'j': 0};
    for (int i = 0; i < decodeResponse['rows'].length; i++) {
      for (int j = 0; j < decodeResponse['rows'][i]['elements'].length; j++) {
        if (decodeResponse['rows'][i]['elements'][j]['distance']['value'] >
            decodeResponse['rows'][maxAt['i']]['elements'][maxAt['j']]
                ['distance']['value']) {
          maxAt['i'] = i;
          maxAt['j'] = j;
        }
        if (i == j) {
          distances.add(
              decodeResponse['rows'][i]['elements'][j]['distance']['value']);
        }
      }
    }

    final origin = waypoints[maxAt['i'] + maxAt['i']];

    final destination = waypoints[maxAt['j'] + maxAt['j'] + 1];

    waypoints
        .removeWhere((element) => element == origin || element == destination);

    final url =
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final body = {
      "origin": {
        "sideOfRoad": true,
        "location": {
          "latLng": {"latitude": origin['lat'], "longitude": origin['lng']}
        }
      },
      "destination": {
        "sideOfRoad": true,
        "location": {
          "latLng": {
            "latitude": destination['lat'],
            "longitude": destination['lng']
          }
        }
      },
      "intermediates": [
        ...waypoints.map((e) => {
              "sideOfRoad": true,
              "location": {
                "latLng": {"latitude": e['lat'], "longitude": e['lng']}
              }
            })
      ],
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "optimizeWaypointOrder": true,
      "computeAlternativeRoutes": false,
      "languageCode": "en-US",
      "units": "IMPERIAL"
    };
    final responseRoute = await post(url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': Keys.mapsApiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.optimizedIntermediateWaypointIndex'
        },
        body: jsonEncode(body));
    final routeInfo = jsonDecode(responseRoute.body);

    final polylineString =
        routeInfo['routes'][0]['polyline']['encodedPolyline'];
    String durationString = routeInfo['routes'][0]['duration'];
    durationString = durationString.replaceFirst('s', '');
    final duration = int.parse(durationString);
    final distanceMeters = routeInfo['routes'][0]['distanceMeters'];
    final distance = distanceMeters / 1000;
    print('Distances ' + distances.toString());
    List<double> percentageValuesOfFare = calculateShapleyValue(distances);

    final totalShapelyValue =
        percentageValuesOfFare.reduce((value, element) => value + element);
    final percentages = percentageValuesOfFare.map((element) {
      return CommonFunctions.roundDouble((element / totalShapelyValue), 4);
    }).toList();
    print('Shapley Value ' + percentages.toString());
    final percentagesNow = calculatePercentages(distanceMeters, distances);
    print('Propotional Allocation ' + percentagesNow.toString());
    final Map fareFactor = {};
    for (int i = 0; i < percentagesNow.length; i++) {
      if (i == 0) {
        fareFactor.addEntries([
          MapEntry(FirebaseAuth.instance.currentUser!.uid, percentagesNow[i]),
        ]);
        continue;
      }
      fareFactor.addEntries([
        MapEntry(participants[i - 1]['id'], percentagesNow[i]),
      ]);
    }
    final db = FirebaseFirestore.instance;
    try {
      await db.runTransaction((transaction) async {
        transaction.set(
            db
                .collection('shared_ride_requests')
                .doc(city)
                .collection('ready_requests_status')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {
              "adminUser": {
                'name': rideInfo['adminUser']['name'],
                'imageUrl': rideInfo['adminUser']['imageUrl'],
                'phoneNumber': rideInfo['adminUser']['phoneNumber'],
                'pickupLatLng': rideInfo['adminUser']['pickupLatLng'],
                'destinationLatLng': rideInfo['adminUser']['destinationLatLng'],
              },
              "participants": rideInfo['participants'].map((e) => {
                    ...e,
                    'priceConfirm': false,
                  }),
              "origin": origin,
              'duration': duration,
              "destination": destination,
              "distance": distance,
              "polylineString": polylineString,
              'passengers': rideInfo['passengers'],
              "price": null,
              'ac': rideInfo['ac'],
              'carType': rideInfo['carType'],
              'isBroadcasted': false,
              "priceConfirmation": 0,
              'arrivals': null,
              'fareFactor': fareFactor,
              'driverId': null,
              'suggestedDriverId': null
            });
        transaction.set(
            db
                .collection('shared_ride_requests')
                .doc(city)
                .collection('ready_requests')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isReadyForBroadcast': false});
        transaction.update(
            db
                .collection('shared_ride_requests')
                .doc(city)
                .collection('pending_requests')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isAvailable': false});
        transaction.update(
            db
                .collection('shared_ride_requests')
                .doc(city)
                .collection('pending_requests_status')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isReady': true});
      });
    } catch (e) {
      rethrow;
    }
  }

  void makeMarker(points, labels) async {
    List<Marker> markers = [];
    for (int i = 0; i < points.length; i++) {
      final marker = Marker(
          markerId: MarkerId('${points[i]['lat']}'),
          position: LatLng(points[i]['lat'], points[i]['lng']),
          icon: await TextIconMarker(
            text: labels[i],
            iconData: FontAwesome5.map_pin,
            fontSize: 14,
          ).toBitmapDescriptor());
      markers.add(marker);
    }
  }

  Future<void> leaveCancelledRide() async {
    final db = FirebaseFirestore.instance;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.update(
            path
                .collection('pending_requests')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isAvailable': true});
        transaction.update(
            path
                .collection('pending_requests_status')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'joinedRequestId': null});
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveCompletedRide() async {
    final db = FirebaseFirestore.instance;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.delete(path
            .collection('pending_requests')
            .doc(FirebaseAuth.instance.currentUser!.uid));
        transaction.delete(
          path
              .collection('pending_requests_status')
              .doc(FirebaseAuth.instance.currentUser!.uid),
        );
      });
    } catch (e) {
      return;
    }
  }

  Future<void> deleteCompleteRide(id) async {
    final db = FirebaseFirestore.instance;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.delete(path.collection('ready_requests').doc(id));
        transaction.delete(
          path.collection('ready_requests_status').doc(id),
        );
      });
    } catch (e) {
      return;
    }
  }

  Future<void> cancelReadyRide() async {
    final db = FirebaseFirestore.instance;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.update(
            path
                .collection('pending_requests')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {
              'isAvailable': true,
            });
        transaction.update(
            path
                .collection('pending_requests_status')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isReady': false, 'participants': [], 'requests': []});
        transaction.delete(path
            .collection('ready_requests_status')
            .doc(FirebaseAuth.instance.currentUser!.uid));
        transaction.delete(path
            .collection('ready_requests')
            .doc(FirebaseAuth.instance.currentUser!.uid));
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelRide() async {
    final db = FirebaseFirestore.instance;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('isSharedRequestLive');
      await db.runTransaction((transaction) async {
        transaction.delete(
          path
              .collection('pending_requests')
              .doc(FirebaseAuth.instance.currentUser!.uid),
        );
        transaction.delete(
          path
              .collection('pending_requests_status')
              .doc(FirebaseAuth.instance.currentUser!.uid),
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveReadyRide(user, docId) async {
    final db = FirebaseFirestore.instance;

    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.update(
            path
                .collection('pending_requests')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'isAvailable': true});
        transaction.update(
            path
                .collection('pending_requests_status')
                .doc(FirebaseAuth.instance.currentUser!.uid),
            {'joinedRequestId': null});
        transaction
            .update(path.collection('ready_requests_status').doc(docId), {
          'participants': FieldValue.arrayRemove([user]),
          'isBroadcasted': false,
          'price': null,
          'suggestedDriverId': null
        });
        transaction.update(path.collection('ready_requests').doc(docId), {
          'isReadyForBroadcast': false,
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> agreeToFare(Map<dynamic, dynamic> value) async {
    final db = FirebaseFirestore.instance;
    final path = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('ready_requests_status');
    final participants = [];
    value['participants'].forEach((participant) {
      if (participant['id'] == FirebaseAuth.instance.currentUser!.uid) {
        participant['priceConfirm'] = true;
      }
      participants.add(participant);
    });
    try {
      await path.doc(value['id']).update({
        'participants': participants,
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> agreeToDriverFare(Map<dynamic, dynamic> value) async {
    final db = FirebaseFirestore.instance;
    final path = db
        .collection('shared_ride_requests')
        .doc(city)
        .collection('ready_requests_status');
    final participants = [];
    value['participants'].forEach((participant) {
      if (participant['id'] == FirebaseAuth.instance.currentUser!.uid) {
        participant['priceConfirm'] = false;
      }
      participants.add(participant);
    });
    try {
      await path.doc(value['id']).update({
        'participants': participants,
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  Future acceptRideOffer(participants, suggestedDriver, price) async {
    final db = FirebaseFirestore.instance;
    final currentId = FirebaseAuth.instance.currentUser!.uid;
    List arrivals = [
      {'id': FirebaseAuth.instance.currentUser!.uid, 'bool': null}
    ];
    participants.forEach((particpant) {
      arrivals.add({
        'id': particpant['id'],
        'bool': null,
      });
    });

    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        final currentRide = await transaction
            .get(path.collection('ready_requests_status').doc(currentId));
        if (currentRide['passengers'] !=
            (currentRide['participants'].length + 1)) {
          throw 'useleft';
        }
        final driver = await transaction
            .get(db.collection('drivers').doc(suggestedDriver['id']));
        if (driver['currentRide'] != null) {
          throw 'unavailable';
        }

        transaction.update(db.collection('drivers').doc(suggestedDriver['id']),
            {'currentRide': currentId});
        transaction.update(path.collection('ready_requests').doc(currentId),
            {'isReadyForBroadcast': false});
        transaction
            .update(path.collection('ready_requests_status').doc(currentId), {
          'driverId': suggestedDriver['id'],
          'driverInfo': suggestedDriver,
          'driverLocation': null,
          'isBroadcasted': false,
          'suggestedDriverId': null,
          'price': price,
          'arrivals': arrivals
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future suggestRideOffer(offerInfo) async {
    final db = FirebaseFirestore.instance;
    final currentId = FirebaseAuth.instance.currentUser!.uid;
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction
            .update(path.collection('ready_requests_status').doc(currentId), {
          'suggestedDriverId': offerInfo,
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future cancelSuggestRideOffer(participants) async {
    final db = FirebaseFirestore.instance;
    final currentId = FirebaseAuth.instance.currentUser!.uid;
    participants.forEach((participant) {
      participant['priceConfirm'] = true;
    });
    final path = db.collection('shared_ride_requests').doc(city);
    try {
      await db.runTransaction((transaction) async {
        transaction.update(
            path.collection('ready_requests_status').doc(currentId),
            {'suggestedDriverId': null, 'participants': participants});
      });
    } catch (e) {
      rethrow;
    }
  }

  List<double> calculateShapleyValue(List<int> distances) {
    List<double> farePercentages = List<double>.filled(distances.length, 0.0);

    int factorial(int n) {
      if (n <= 1) return 1;
      return n * factorial(n - 1);
    }

    for (int i = 0; i < distances.length; i++) {
      double shapleyValue = 0;

      for (int numPassengers = 1;
          numPassengers <= distances.length;
          numPassengers++) {
        List<int> coalitionIndices = List<int>.filled(numPassengers, -1);
        coalitionIndices[0] = i;

        void generateCoalitions(int currentIndex, int remainingIndices) {
          if (remainingIndices == 0) {
            double coalitionDistance = coalitionIndices.fold<double>(
                0, (sum, index) => sum + distances[index]);
            shapleyValue += coalitionDistance / factorial(distances.length - 1);
            return;
          }

          for (int j = 0; j < distances.length; j++) {
            if (coalitionIndices.contains(j)) continue;
            coalitionIndices[currentIndex] = j;
            generateCoalitions(currentIndex + 1, remainingIndices - 1);
            coalitionIndices[currentIndex] = -1;
          }
        }

        generateCoalitions(1, numPassengers - 1);
      }

      farePercentages[i] = shapleyValue;
    }

    return farePercentages;
  }

  List<double> calculatePercentages(
      int totalDistance, List<int> passengerDistances) {
    // Calculate the percentage share for each passenger
    List<double> percentageShares = passengerDistances
        .map((distance) => ((distance + 0.0) / totalDistance) * 100)
        .toList();

    // Calculate the sum of percentage shares
    double sumPercentage =
        percentageShares.reduce((value, element) => value + element);

    // Normalize the percentage shares
    List<double> normalizedPercentages = percentageShares
        .map((percentage) =>
            CommonFunctions.roundDouble((percentage / sumPercentage), 4))
        .toList();

    return normalizedPercentages;
  }
}
