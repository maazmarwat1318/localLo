import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:local_lo/Utilities/colors_typography.dart';
import 'package:local_lo/firebase_options.dart';
import 'package:local_lo/providers/loading_controller.dart';
import 'package:local_lo/providers/ride_route.dart';
import 'package:local_lo/providers/shared_ride.dart';
import 'package:local_lo/providers/user_auth.dart';
import 'package:local_lo/providers/widget_front.dart';
import 'package:local_lo/screens/home_screen.dart';
import 'package:local_lo/screens/main_routing_screen.dart';
import 'package:local_lo/screens/profile_set_up.dart';
import 'package:local_lo/screens/shared_ride_request_setup.dart';
import 'package:local_lo/screens/verify_phone_number.dart';
import 'package:local_lo/widgets/main_func_error.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);
  //Remove it if you are using Connectivity Checking;
  //or using timeout for setting

  FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 10));

  // try {
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  // } catch (_) {
  //   runApp(const OnError());
  //   return;
  // }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    FlutterNativeSplash.remove();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => UserAuth(),
        ),
        ChangeNotifierProvider(
          create: (context) => RideRoute(),
        ),
        ChangeNotifierProvider(
          create: (context) => SharedRide(),
        ),
        ChangeNotifierProvider(
          create: (context) => WidgetFront(),
        ),
        ChangeNotifierProvider(
          create: (context) => LoadControl(),
        )
      ],
      child: MaterialApp(
        title: 'Local Lo',
        theme: ThemeData(
          primarySwatch: const MaterialColor(0xFF4E68FB, <int, Color>{
            50: ColorsTypography.formInputBackgroundColor,
            100: ColorsTypography.formInputBackgroundColor,
            200: ColorsTypography.infoBlockColor,
            300: ColorsTypography.messageBubbleColor,
            400: ColorsTypography.primarySelectionColor,
            500: ColorsTypography.primarySelectionColor,
            600: ColorsTypography.secondaryColor,
            700: ColorsTypography.secondaryColor,
            900: ColorsTypography.primaryColor,
          }),
          cardTheme: const CardTheme(
            clipBehavior: Clip.antiAlias,
            color: ColorsTypography.infoBlockColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(20),
              ),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: ColorsTypography.formInputBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(20),
              ),
            ),
          ),
          radioTheme: const RadioThemeData(
            fillColor: MaterialStatePropertyAll(
              ColorsTypography.primaryColor,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                width: 2,
                color: ColorsTypography.warningColor,
              ),
            ),
            fillColor: ColorsTypography.formInputBackgroundColor,
            prefixIconColor: ColorsTypography.secondaryColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: ColorsTypography.formInputBackgroundColor,
              ),
            ),
            border: OutlineInputBorder(
              borderSide: const BorderSide(
                color: ColorsTypography.formInputBackgroundColor,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            hintStyle: const TextStyle(
              fontSize: ColorsTypography.hintFont,
              color: ColorsTypography.hintColor,
            ),
          ),
          tabBarTheme: const TabBarTheme(
              labelColor: ColorsTypography.primaryColor,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: ColorsTypography.defaultSmallButtonFont,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: ColorsTypography.defaultSmallButtonFont,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelColor: ColorsTypography.secondaryColor,
              indicator: BoxDecoration(
                  color: ColorsTypography.primarySelectionColor,
                  borderRadius: BorderRadius.all(Radius.circular(20)))),
          checkboxTheme: const CheckboxThemeData(
              fillColor:
                  MaterialStatePropertyAll(ColorsTypography.primaryColor)),
          textTheme: const TextTheme(
            titleSmall: TextStyle(
              fontSize: ColorsTypography.defaultBodyFont,
              fontWeight: ColorsTypography.primaryMainContentBold,
            ),
            titleMedium: TextStyle(
              fontSize: ColorsTypography.defaultLargeButtonFont,
              fontWeight: ColorsTypography.secondaryMainContentBold,
              color: Colors.white,
            ),
            bodyMedium: TextStyle(
              fontSize: ColorsTypography.defaultBodyFont,
              fontWeight: FontWeight.normal,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
            textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: ColorsTypography.primaryMainContentBold),
            foregroundColor: ColorsTypography.primaryColor,
          )),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: ColorsTypography.primaryMainContentBold),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(15),
                ),
              ),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            contentTextStyle: TextStyle(
              fontSize: ColorsTypography.defaultBodyFont,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            behavior: SnackBarBehavior.floating,
            elevation: 0,
          ),
        ),
        routes: {
          '/verifyphonenumber': (context) => const VerifyPhoneNumber(),
          '/profilesetup': (context) => const ProfileSetUp(),
          '/mainroutingscreen': (context) => const MainRoutingScreen(),
          '/homescreen': (context) => HomeScreen(),
          '/sharedriderequestsetup': (context) =>
              const SharedRideRequestSetup(),
        },
        home: const MainRoutingScreen(),
      ),
    );
  }
}

class OnError extends StatelessWidget {
  const OnError({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Local Lo',
      home: MainFuncError(),
    );
  }
}
