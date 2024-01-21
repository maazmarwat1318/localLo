import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:local_lo/Utilities/colors_typography.dart';
import 'package:local_lo/Utilities/custom_styles.dart';
import 'package:local_lo/Utilities/info_dialogs.dart';

import 'package:local_lo/mocks/fake_firebase_doc.dart';
import 'package:local_lo/providers/loading_controller.dart';

import 'package:local_lo/providers/shared_ride.dart';
import 'package:local_lo/providers/widget_front.dart';
import 'package:local_lo/widgets/homescreen_widgets/ride_preferences.dart';
import 'package:local_lo/widgets/route_and_price_finalization_widgets/driver_location_map.dart';
import 'package:local_lo/widgets/route_and_price_finalization_widgets/driver_offer_view.dart';
import 'package:local_lo/widgets/route_and_price_finalization_widgets/drives_offers_list.dart';
import 'package:local_lo/widgets/route_and_price_finalization_widgets/fare_approvals.dart';

import 'package:local_lo/widgets/route_and_price_finalization_widgets/passengers_number_bubble.dart';

import 'package:local_lo/widgets/route_and_price_finalization_widgets/route_overview.dart';
import 'package:local_lo/widgets/route_and_price_finalization_widgets/set_fare_price.dart';
import 'package:local_lo/widgets/shared_ride_request_setup_widgets/chat.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteAndPriceFinalization extends StatefulWidget {
  RouteAndPriceFinalization({super.key, required this.id});
  final id;

  @override
  State<RouteAndPriceFinalization> createState() =>
      _RouteAndPriceFinalizationState();
}

class _RouteAndPriceFinalizationState extends State<RouteAndPriceFinalization> {
  final priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final sharedRideInfo = Provider.of<SharedRide>(context, listen: false);
    final widgetfront = Provider.of<WidgetFront>(context, listen: false);
    final loadControl = Provider.of<LoadControl>(context, listen: false);
    final stream = FirebaseFirestore.instance
        .collection('shared_ride_requests')
        .doc(sharedRideInfo.city)
        .collection('ready_requests_status')
        .doc(widget.id)
        .snapshots();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: StreamProvider<DocumentSnapshot>(
        create: (context) => stream,
        catchError: (context, error) {
          return FakeDoc(exist: false, id: 'xxx');
        },
        initialData: FakeDoc(exist: true, id: 'yyy'),
        child: Selector<DocumentSnapshot, String?>(
          selector: (_, value) {
            if (!value.exists && value.id == 'xxx') {
              return '0';
            }

            if (value.exists && value.id == 'yyy') {
              return null;
            }
            if (!value.exists) {
              return '1';
            }

            return value.id;
          },
          builder: (context, value, _) {
            if (value == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (value == '1') {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ride has been cancelled by the Admin'),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          try {
                            await sharedRideInfo.leaveCancelledRide();
                            Navigator.of(context).pushReplacementNamed(
                                '/sharedriderequestsetup');
                          } catch (e) {
                            rethrow;
                          }
                        },
                        child: const Text('Leave'))
                  ],
                ),
              );
            }

            if (value == '0') {
              return Center(
                child: Column(
                  children: [
                    const Text('Network Error occured'),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          setState(() {});
                        },
                        child: const Text('Retry'))
                  ],
                ),
              );
            }
            return SafeArea(
              child: Stack(children: [
                RideLeaveAndKickCheck(),
                Positioned(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                          alignment: Alignment.center,
                          decoration: CustomStyles.passegnerContianerStyle
                              .copyWith(color: ColorsTypography.primaryColor),
                          child: Selector<DocumentSnapshot, String>(
                            selector: (_, value) => value.id,
                            builder: (context, value, _) => Row(
                              children: [
                                Selector<DocumentSnapshot, Map>(
                                  selector: (p0, p1) => {
                                    'isBroadcasted': p1['isBroadcasted'],
                                    'driverId': p1['driverId']
                                  },
                                  builder: (context, value, child) => Expanded(
                                    child: Text(
                                      value['isBroadcasted'] == true
                                          ? 'Drivers Offers'
                                          : value['driverId'] == null
                                              ? 'Offer Fare Price'
                                              : 'Ride Route',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                ),
                                if (value ==
                                    FirebaseAuth.instance.currentUser!.uid)
                                  CancelButton(
                                      loadControl: loadControl,
                                      sharedRideInfo: sharedRideInfo),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const PassengerNumberBubble(),
                        const SizedBox(
                          height: 8,
                        ),
                        Expanded(
                          child: Selector<DocumentSnapshot, Map>(
                              selector: (_, value) {
                            return {
                              'isBroadcasted': value['isBroadcasted'],
                              'id': value.id,
                              'driverId': value['driverId'],
                              // 'suggestedDriver': value['suggestedDriverId'],
                            };
                          }, builder: (context, value, _) {
                            return DefaultTabController(
                                length: 2,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration:
                                          CustomStyles.passegnerContianerStyle,
                                      child: TabBar(
                                          splashBorderRadius:
                                              const BorderRadius.all(
                                                  Radius.circular(20)),
                                          tabs: [
                                            if (value['driverId'] == null) ...[
                                              if (value['isBroadcasted'] ==
                                                  true)
                                                const Tab(
                                                  text: 'Offers',
                                                ),
                                              if (value['isBroadcasted'] !=
                                                  true)
                                                const Tab(
                                                  text: 'Set Price',
                                                ),
                                            ],
                                            if (value['driverId'] != null)
                                              const Tab(
                                                text: 'Driver',
                                              ),
                                            const Tab(
                                              text: 'Chat',
                                            )
                                          ]),
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Expanded(
                                        child: TabBarView(
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            children: [
                                          if (value['driverId'] == null) ...[
                                            if (value['isBroadcasted'] == true)
                                              DriversOfferList(
                                                sharedRideInfo: sharedRideInfo,
                                                id: value['id'],
                                              ),
                                            if (value['isBroadcasted'] != true)
                                              Stack(children: [
                                                Positioned(
                                                  left: 0,
                                                  right: 0,
                                                  top: 0,
                                                  bottom: 0,
                                                  child: RouteOverview(
                                                    widgetFront: widgetfront,
                                                    sharedRideInfo:
                                                        sharedRideInfo,
                                                  ),
                                                ),
                                                const FareApprovals(),
                                                SetFarePrice(
                                                  priceController:
                                                      priceController,
                                                ),
                                              ]),
                                          ],
                                          if (value['driverId'] != null)
                                            DriverLocationMap(),
                                          Chat(chatId: value['id'])
                                        ]))
                                  ],
                                ));
                          }),
                        )
                      ],
                    ),
                  ),
                ),
                Positioned(
                    bottom: 10,
                    left: 50,
                    right: 50,
                    child: ArrivalAndRideCompleteCheck(
                        sharedRideInfo: sharedRideInfo)),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class CancelButton extends StatelessWidget {
  const CancelButton({
    Key? key,
    required this.loadControl,
    required this.sharedRideInfo,
  }) : super(key: key);

  final LoadControl loadControl;
  final SharedRide sharedRideInfo;

  @override
  Widget build(BuildContext context) {
    return Selector<DocumentSnapshot, Map>(
      selector: (p0, p1) => {'arrivals': p1['arrivals']},
      builder: (context, value, child) {
        bool hasStarted = false;
        if (value['arrivals'] != null) {
          value['arrivals'].forEach((arrival) {
            if (hasStarted == true) {
              return;
            }
            if (arrival['bool'] != null) {
              hasStarted = true;
            }
          });
        }
        if (hasStarted) {
          return const SizedBox();
        }
        return Selector<LoadControl, bool>(
          selector: (p0, p1) => p1.readyRideCancel,
          builder: (context, thisValue, child) => ElevatedButton(
            onPressed: thisValue == true
                ? null
                : () async {
                    try {
                      loadControl.setReadyRideCancel(true);
                      await sharedRideInfo.cancelReadyRide();
                      loadControl.setReadyRideCancel(false);
                      Navigator.of(context)
                          .pushReplacementNamed('/sharedriderequestsetup');
                    } catch (e) {
                      loadControl.setReadyRideCancel(false);
                      InfoDialogs.showErrorDialog(
                          context, 'Network Error Occured');
                    }
                  },
            style: ElevatedButton.styleFrom(
                backgroundColor: ColorsTypography.warningColor),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

class RideLeaveAndKickCheck extends StatelessWidget {
  const RideLeaveAndKickCheck({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<DocumentSnapshot, Map>(
      selector: (p0, p1) => {'participants': p1['participants'], 'id': p1.id},
      builder: (context, value, child) {
        if (value['id'] == FirebaseAuth.instance.currentUser!.uid) {
          return const SizedBox();
        }
        int? origin;

        value['participants'].forEach((passegner) {
          if (passegner['id'] == FirebaseAuth.instance.currentUser!.uid) {
            origin = 3;
            return;
          }
        });
        if (origin != null) {
          return const SizedBox();
        }

        Future.delayed(const Duration(microseconds: 0), () async {
          InfoDialogs.showInfoDialog(context, 'You are Removed from the Ride');
          await SharedPreferences.getInstance().then((value) {
            value.remove('joinedRideId');
          });
          Navigator.of(context).pushReplacementNamed('/sharedriderequestsetup');
        });
        return Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  const Text(
                      'You are removed from the Ride. If Auto Redirecting Fails Click Leave'),
                  const SizedBox(
                    height: 30,
                  ),
                  ElevatedButton(
                      onPressed: () async {
                        await SharedPreferences.getInstance().then((value) {
                          value.remove('joinedRideId');
                        });
                        Navigator.of(context)
                            .pushReplacementNamed('/sharedriderequestsetup');
                      },
                      child: const Text('Leave'))
                ],
              ),
            ));
      },
    );
  }
}

class ArrivalAndRideCompleteCheck extends StatelessWidget {
  const ArrivalAndRideCompleteCheck({
    Key? key,
    required this.sharedRideInfo,
  }) : super(key: key);

  final SharedRide sharedRideInfo;

  @override
  Widget build(BuildContext context) {
    return Selector<DocumentSnapshot, Map>(
      selector: (p0, p1) =>
          {'arrivals': p1['arrivals'], 'driverId': p1['driverId'], 'id': p1.id},
      builder: (context, value, child) {
        if (value['arrivals'] == null) {
          return const SizedBox();
        }
        bool? hasArrived;
        int trueCounts = 0;

        value['arrivals'].forEach((passegner) {
          if (passegner['bool'] == true) {
            trueCounts++;
          }
          if (passegner['id'] == FirebaseAuth.instance.currentUser!.uid) {
            hasArrived = passegner['bool'];
          }
        });
        if (hasArrived == null) {
          return const SizedBox();
        }
        if (hasArrived == false) {
          return Container(
            alignment: Alignment.center,
            width: double.infinity,
            height: 50,
            decoration: CustomStyles.passegnerContianerStyle.copyWith(
              color: ColorsTypography.primaryColor,
            ),
            child: const Text(
              'You Driver has arrived',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          );
        }
        bool lastPassenger = false;
        if (trueCounts == (value['arrivals'].length)) {
          lastPassenger = true;
        }

        Future.delayed(const Duration(microseconds: 0), () async {
          await SharedPreferences.getInstance().then((prefs) {
            try {
              prefs.setString('toReview', value['driverId']);
              prefs.remove('joinedRideId');
            } catch (e) {
              return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Text(
                            'Ride Completed. If Auto Redirecting Fails Click Return'),
                        const SizedBox(
                          height: 30,
                        ),
                        ElevatedButton(
                            onPressed: () async {
                              await SharedPreferences.getInstance()
                                  .then((prefs) {
                                try {
                                  prefs.setString(
                                      'toReview', value['driverId']);
                                  prefs.remove('joinedRideId');
                                } catch (e) {}
                                prefs.remove('isSharedRequestLive');
                              });
                              Navigator.of(context)
                                  .pushReplacementNamed('/homescreen');
                              sharedRideInfo.leaveCompletedRide();
                              if (lastPassenger == true) {
                                sharedRideInfo.deleteCompleteRide(value['id']);
                              }
                            },
                            child: const Text('Return'))
                      ],
                    ),
                  ));
            }
            prefs.remove('isSharedRequestLive');
          });

          Navigator.of(context).pushReplacementNamed('/homescreen');
          sharedRideInfo.leaveCompletedRide();
          if (lastPassenger == true) {
            sharedRideInfo.deleteCompleteRide(value['id']);
          }
        });
        return const SizedBox();
      },
    );
  }
}
