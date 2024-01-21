import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:local_lo/Utilities/colors_typography.dart';

import 'package:local_lo/Utilities/custom_styles.dart';
import 'package:local_lo/Utilities/info_dialogs.dart';
import 'package:local_lo/mocks/fake_firebase_doc.dart';
import 'package:local_lo/providers/loading_controller.dart';
import 'package:local_lo/providers/shared_ride.dart';

import 'package:local_lo/widgets/shared_ride_request_setup_widgets/chat.dart';
import 'package:local_lo/widgets/shared_ride_request_setup_widgets/joined_ride_info.dart';
import 'package:local_lo/widgets/shared_ride_request_setup_widgets/passegner_number_bubble.dart';
import 'package:local_lo/widgets/shared_ride_request_setup_widgets/passengers.dart';
import 'package:local_lo/widgets/shared_ride_request_setup_widgets/requests.dart';
import 'package:local_lo/screens/route_and_price_finalization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedRideRequestSetup extends StatefulWidget {
  const SharedRideRequestSetup({super.key, this.joinedRideId});
  final String? joinedRideId;

  @override
  State<SharedRideRequestSetup> createState() => _SharedRideRequestSetupState();
}

class _SharedRideRequestSetupState extends State<SharedRideRequestSetup> {
  @override
  Widget build(BuildContext context) {
    final sharedRideInfo = Provider.of<SharedRide>(context, listen: false);
    final loadControl = Provider.of<LoadControl>(context, listen: false);
    final Stream passengersStream = FirebaseFirestore.instance
        .collection('shared_ride_requests')
        .doc(sharedRideInfo.city)
        .collection('pending_requests')
        .snapshots();

    final Stream<DocumentSnapshot> requestStream = FirebaseFirestore.instance
        .collection('shared_ride_requests')
        .doc(sharedRideInfo.city)
        .collection('pending_requests_status')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots();

    return Scaffold(
      body: widget.joinedRideId != null
          ? JoinedRideInfo(id: widget.joinedRideId)
          : StreamProvider<DocumentSnapshot>(
              create: (context) => requestStream,
              catchError: (context, error) {
                return FakeDoc(exist: false, id: 'xxx');
              },
              initialData: FakeDoc(exist: true, id: 'yyy'),
              child: Selector<DocumentSnapshot, String?>(selector: (_, value) {
                if (!value.exists && value.id == 'xxx') {
                  return '0';
                }

                if (value.exists && value.id == 'yyy') {
                  return null;
                }
                if (!value.exists) {
                  return '1';
                }

                return value['carType'];
              }, builder: (context, value, _) {
                if (value == null) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (value == '0') {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Network Error Occured'),
                      const SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: Text('Retry'))
                    ],
                  );
                }
                if (value == '1') {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Network Error Occured'),
                      const SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: Text('Retry'))
                    ],
                  );
                }

                return Selector<DocumentSnapshot, Map>(selector: (_, value) {
                  return {
                    'joinedRequestId': value['joinedRequestId'],
                    'isReady': value['isReady']
                  };
                }, builder: (context, value, child) {
                  if (value['joinedRequestId'] != null) {
                    return FutureBuilder(
                      future: Future(() async {
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setString('joinedRideId', value['joinedRideId']);
                      }),
                      builder: ((context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox();
                        }

                        return JoinedRideInfo(
                          id: value['joinedRequestId'],
                        );
                      }),
                    );
                  }
                  if (value['isReady'] == true) {
                    Future.delayed(const Duration(microseconds: 0), () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (context) => RouteAndPriceFinalization(
                              id: FirebaseAuth.instance.currentUser!.uid)));
                    });
                    return const SizedBox();
                  }

                  return SafeArea(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 15),
                            alignment: Alignment.center,
                            decoration: CustomStyles.passegnerContianerStyle
                                .copyWith(color: ColorsTypography.primaryColor),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ride Set Up',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Selector<LoadControl, bool>(
                                  selector: (_, value) {
                                    return value.sharedRideCancel;
                                  },
                                  builder: (context, value, child) =>
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: ColorsTypography
                                                  .warningColor),
                                          onPressed: value == true
                                              ? null
                                              : () async {
                                                  try {
                                                    loadControl
                                                        .setSharedRideCancel(
                                                            true);
                                                    await sharedRideInfo
                                                        .cancelRide();
                                                    Navigator.of(context)
                                                        .pushReplacementNamed(
                                                            '/mainroutingscreen');
                                                    loadControl
                                                        .setSharedRideCancel(
                                                            false);
                                                  } catch (e) {
                                                    loadControl
                                                        .setSharedRideCancel(
                                                            false);
                                                    InfoDialogs.showErrorDialog(
                                                        context,
                                                        'Network Error Occured');
                                                  }
                                                },
                                          child: const Text('Cancel')),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          PassengerNumberBubble(sharedRideInfo: sharedRideInfo),
                          const SizedBox(
                            height: 8,
                          ),
                          Expanded(
                            child: DefaultTabController(
                              length: 3,
                              child: Column(
                                children: [
                                  Container(
                                    decoration:
                                        CustomStyles.passegnerContianerStyle,
                                    child: const TabBar(
                                      splashBorderRadius:
                                          BorderRadius.all(Radius.circular(20)),
                                      tabs: [
                                        Tab(
                                          text: 'Passengers',
                                        ),
                                        Tab(
                                          text: 'Requests',
                                        ),
                                        Tab(
                                          text: 'Chat',
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Expanded(
                                    child: TabBarView(children: [
                                      PassengersList(
                                          passengersStream: passengersStream),
                                      Selector<DocumentSnapshot, List>(
                                          selector: (p0, p1) => p1['requests'],
                                          builder: (context, value, child) =>
                                              RequestsList()),
                                      Chat(
                                        chatId: FirebaseAuth
                                            .instance.currentUser!.uid,
                                      ),
                                    ]),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                });
              }),
            ),
    );
  }
}
