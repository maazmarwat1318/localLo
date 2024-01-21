import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_lo/providers/shared_ride.dart';
import 'package:local_lo/providers/user_auth.dart';
import 'package:local_lo/screens/home_screen.dart';
import 'package:local_lo/screens/profile_set_up.dart';
import 'package:local_lo/screens/shared_ride_request_setup.dart';
import 'package:local_lo/screens/verify_phone_number.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainRoutingScreen extends StatelessWidget {
  const MainRoutingScreen({super.key});

  Future loadMainScreen(context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return const VerifyPhoneNumber();
    }
    if (FirebaseAuth.instance.currentUser != null) {
      final sharedRideInfo = Provider.of<SharedRide>(context, listen: false);
      final userAuth = Provider.of<UserAuth>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final isRegistered = prefs.getBool('isRegistered') ?? false;

      final isSharedRequestLive = prefs.getBool('isSharedRequestLive') ?? false;
      await userAuth.getUserProfileFromStorage();
      if (isSharedRequestLive) {
        final city = prefs.getString('city');
        sharedRideInfo.setCity(city!);
        final joinedRideId = prefs.getString('joinedRideId') ?? 'x';
        if (joinedRideId != 'x') {
          return SharedRideRequestSetup(joinedRideId: joinedRideId);
        }
        return const SharedRideRequestSetup();
      }

      if (isRegistered) {
        return HomeScreen();
      }
      return const ProfileSetUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: loadMainScreen(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: SizedBox(),
            );
          }
          return snapshot.data!;
        });
  }
}
