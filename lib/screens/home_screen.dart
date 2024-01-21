import 'package:flutter/material.dart';

import 'package:local_lo/Utilities/colors_typography.dart';

import 'package:local_lo/Utilities/info_dialogs.dart';
import 'package:local_lo/providers/ride_route.dart';
import 'package:local_lo/providers/user_auth.dart';
import 'package:local_lo/widgets/homescreen_widgets/app_drawer.dart';
import 'package:local_lo/widgets/homescreen_widgets/google_map_home.dart';
import 'package:local_lo/widgets/homescreen_widgets/location_input.dart';
import 'package:local_lo/widgets/homescreen_widgets/rating_widget.dart';
import 'package:local_lo/widgets/homescreen_widgets/ride_preferences.dart';
import 'package:provider/provider.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _destiantionFocusNode = FocusNode();
  final _pickupFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final userAuth = Provider.of<UserAuth>(context, listen: false);
    final rideRoute = Provider.of<RideRoute>(context, listen: false);
    void closeBottomSheet() {
      Navigator.of(context).pop();
    }

    void onRequestSubmit(ctx) {
      Navigator.of(ctx).pushReplacementNamed(
        '/sharedriderequestsetup',
      );
    }

    Future.delayed(const Duration(seconds: 0), () async {
      await SharedPreferences.getInstance().then((prefs) async {
        final toReview = prefs.getString('toReview') ?? 'x';
        if (toReview == 'x') {
          return;
        }
        showDialog(
          context: context,
          builder: (context) {
            return RateDriverDialog(
              driverId: toReview,
            );
          },
        );
      });
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      drawer: AppDrawer(userAuth: userAuth),
      body: SafeArea(
        child: FutureBuilder(
          future: Future.delayed(const Duration(microseconds: 0)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox();
            }

            return Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () {
                          _scaffoldKey.currentState!.openDrawer();
                        },
                        iconSize: 30,
                        icon: const Icon(
                          FontAwesome5.align_right,
                          color: ColorsTypography.primaryColor,
                        ),
                      ),
                      Expanded(
                        child: LocationInput(
                          pickupFocusNode: _pickupFocusNode,
                          destinationFocusNode: _destiantionFocusNode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        const GoogleMapHome(),
                        Consumer<RideRoute>(
                          builder: (context, value, child) => Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (value.isChooseMapLoading ||
                                    value.isCurrentLocationLoading)
                                  const CircularProgressIndicator(),
                                if (!(value.isChooseMapLoading ||
                                        value.isCurrentLocationLoading) &&
                                    value.isPickUpSelected != null &&
                                    value.isPickUpSelected == true)
                                  ElevatedButton(
                                    onPressed: () async {
                                      _pickupFocusNode.unfocus();
                                      _destiantionFocusNode.unfocus();
                                      value.setCurrentLocationLoading(true);
                                      try {
                                        await value
                                            .setPickUptoCurrentLocation();
                                        // value.setIsPickUpSelected(null);
                                        // value.setCurrentLocationLoading(false);
                                      } catch (e) {
                                        InfoDialogs.showErrorDialog(context,
                                            'Make Sure you have a working internet Connection');
                                        value.setIsPickUpSelected(null);
                                        value.setCurrentLocationLoading(false);
                                        return;
                                      }
                                      value.setCurrentLocationLoading(false);
                                      value.setMarker(value.pickUpLatLng!, 200);
                                      value.goToLocation(value.pickUpLatLng!);
                                      value.setIsPickUpSelected(null);
                                    },
                                    child: const Text(
                                      'Current Location',
                                    ),
                                  ),
                                if (value.isPickUpSelected != null &&
                                    !(value.isChooseMapLoading ||
                                        value.isCurrentLocationLoading))
                                  ElevatedButton(
                                    onPressed: () {
                                      _pickupFocusNode.unfocus();
                                      _destiantionFocusNode.unfocus();
                                      value.isChooseMapSelected = true;
                                    },
                                    child: const Text('Choose on Map'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 15,
                          left: 0,
                          right: 0,
                          child: Selector<RideRoute, bool>(
                            selector: (p0, p1) => p1.isRequestSubmitting,
                            builder: (context, value, child) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (value == true)
                                  const CircularProgressIndicator(),
                                if (value == false)
                                  ElevatedButton(
                                    onPressed: () async {
                                      rideRoute.setRequestSubmitting(true);
                                      if (rideRoute.pickUpLatLng == null ||
                                          rideRoute.destinationLatLng == null) {
                                        InfoDialogs.showErrorDialog(context,
                                            'Please Provide Complete Address');
                                        rideRoute.setRequestSubmitting(false);
                                        return;
                                      }
                                      double distance;
                                      try {
                                        distance = await rideRoute.checkRoute(
                                            rideRoute.pickUpLatLng!,
                                            rideRoute.destinationLatLng!);
                                      } catch (e) {
                                        rideRoute.setRequestSubmitting(false);
                                        InfoDialogs.showErrorDialog(context,
                                            'Unaccessible Locations. Please choose Locations close to Roads on Map');
                                        return;
                                      }
                                      rideRoute.setRequestSubmitting(false);

                                      showBottomSheet(
                                          elevation: 4,
                                          context: context,
                                          builder: (context) => RidePreferences(
                                                distance: distance,
                                                onClose: closeBottomSheet,
                                                onSuccess: () {
                                                  onRequestSubmit(context);
                                                },
                                              ));
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 20),
                                      child: Text(
                                        'Confirm Route',
                                        style: ColorsTypography
                                            .largeElevatedButtonText,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
