import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_lo/Utilities/colors_typography.dart';
import 'package:local_lo/Utilities/info_dialogs.dart';
import 'package:local_lo/providers/user_auth.dart';
import 'package:local_lo/widgets/ticking_clock.dart';
import 'package:provider/provider.dart';

class VerifyPhoneNumber extends StatefulWidget {
  const VerifyPhoneNumber({super.key});

  @override
  State<VerifyPhoneNumber> createState() => _VerifyPhoneNumberState();
}

class _VerifyPhoneNumberState extends State<VerifyPhoneNumber> {
  final phoneNumbercontroller = TextEditingController();
  final codeController = TextEditingController();
  @override
  void dispose() {
    // TODO: implement dispose
    phoneNumbercontroller.dispose();
    codeController.dispose();
    super.dispose();
  }

  void onSendCode(UserAuth userAuth) async {
    if (phoneNumbercontroller.text.length < 7) {
      InfoDialogs.showErrorDialog(context, 'Please enter a valid phone number');
      return;
    }
    FocusScope.of(context).unfocus();

    final phoneNumber = userAuth.formatPhoneNumber(phoneNumbercontroller.text);
    try {
      await userAuth.getVerificationCode(phoneNumber, onVerificationFailure);
    } catch (_) {
      InfoDialogs.showErrorDialog(
          context, 'Make sure your device has a working internet connection');
      return;
    }
  }

  void onVerifyCode(UserAuth userAuth) async {
    if (codeController.text.length < 6) {
      InfoDialogs.showErrorDialog(
        context,
        'Please provide a valid code',
      );
      return;
    }
    try {
      FocusScope.of(context).unfocus();
      await userAuth.verifyCode(codeController.text);
      userAuth.setIsVerificationLoading(false);
      onVerificationComplete(userAuth);
    } catch (e) {
      userAuth.setIsVerificationLoading(false);
      if (e is FirebaseAuthException) {
        if (e.code == 'invalid-verification-code') {
          InfoDialogs.showErrorDialog(context, 'Please provide a valid code');

          return;
        } else if (e.code == 'expired-action-code') {
          InfoDialogs.showErrorDialog(
              context, 'Code has Expired. Please provide latest code');
          return;
        }
      }
      print(e.toString());

      InfoDialogs.showErrorDialog(
          context, 'Make sure your device has a working internet connection');
      return;
    }
  }

  void onVerificationFailure(error) {
    InfoDialogs.showErrorDialog(context, error);
  }

  void onVerificationComplete(UserAuth userAuth) async {
    try {
      bool status = false;
      try {
        status = await userAuth.checkIfUserExists();
      } catch (e) {
        userAuth.setIsVerificationLoading(false);
        Navigator.of(context).pushReplacementNamed('/profilesetup');
        return;
      }
      if (status) {
        userAuth.setIsVerificationLoading(false);
        Navigator.of(context).pushReplacementNamed('/homescreen');
        return;
      } else {
        userAuth.setIsVerificationLoading(false);
        Navigator.of(context).pushReplacementNamed('/profilesetup');
        return;
      }
    } catch (e) {
      InfoDialogs.showErrorDialog(
          context, 'Make sure your device has a working internet connection');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final userAuth = Provider.of<UserAuth>(context, listen: false);
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: 40,
            ),
            Image.asset(
              'assets/logos/150X150.png',
              width: 150 - (screenKeyboardHeight / 10),
              height: 150 - (screenKeyboardHeight / 10),
            ),
            SizedBox(
              height: 60 - (screenKeyboardHeight / 10),
            ),
            Container(
              alignment: Alignment.center,
              child: Text(
                'Verify Phone Number',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          //Country Code
                          // SizedBox(
                          //   width: 50,
                          //   child: TextField(
                          //     style: Theme.of(context).textTheme.bodyMedium,
                          //     keyboardType: TextInputType.phone,
                          //     decoration: const InputDecoration(
                          //       hintText: 'Phone Number',
                          //     ),
                          //     controller: codeController,
                          //   ),
                          // ),
                          // const SizedBox(
                          //   width: 5,
                          // ),
                          Expanded(
                            child: TextField(
                              style: Theme.of(context).textTheme.bodyMedium,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'Phone Number',
                              ),
                              controller: phoneNumbercontroller,
                            ),
                          ),
                        ],
                      ),
                      Consumer<UserAuth>(
                        builder: (context, value, child) {
                          if (value.codeSent == true &&
                              !value.resendCodeAllowed == true) {
                            return CountdownPage();
                          }
                          return const SizedBox();
                        },
                      ),
                      Consumer<UserAuth>(
                        builder: (context, value, child) => TextButton(
                          onPressed: (value.codeSent == true &&
                                  !value.resendCodeAllowed == true)
                              ? null
                              : () async {
                                  onSendCode(userAuth);
                                },
                          child: value.isLoadingSend
                              ? const SizedBox(
                                  height: 25,
                                  width: 25,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text('Send Code'),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      TextField(
                        style: Theme.of(context).textTheme.bodyMedium,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Verification Code',
                        ),
                        controller: codeController,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Consumer<UserAuth>(
                        builder: (context, value, child) => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              fixedSize: ColorsTypography.formButtonSize,
                            ),
                            onPressed: value.codeSent == true
                                ? () async {
                                    onVerifyCode(userAuth);
                                  }
                                : null,
                            child: value.isVerificationLoading
                                ? const CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  )
                                : const Text('Verify')),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
