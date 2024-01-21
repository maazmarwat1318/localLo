import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserAuth with ChangeNotifier {
  Map _userData = {};

  Map? get userData => _userData;

  String? _verificationId;

  File? imageFile;

  bool isLoadingSend = false;
  bool codeSent = false;
  bool resendCodeAllowed = false;
  bool isVerificationLoading = false;

  void setImageFile(File image) {
    imageFile = image;
    notifyListeners();
  }

  void setResendCode(bool status) {
    resendCodeAllowed = status;
    notifyListeners();
  }

  void setIsVerificationLoading(bool status) {
    isVerificationLoading = status;
    notifyListeners();
  }

  String formatPhoneNumber(String phoneNumber) {
    String formattedPhoneNumber = '+92${phoneNumber.replaceFirst('0', '')}';
    return formattedPhoneNumber;
  }

  Future getVerificationCode(
      String phoneNumber, Function onVerificationFailure) async {
    isLoadingSend = true;
    try {
      await FirebaseAppCheck.instance.activate(
        webRecaptchaSiteKey: 'recaptcha-v3-site-key',
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
    } catch (_) {}
    final auth = FirebaseAuth.instance;
    try {
      codeSent = false;
      resendCodeAllowed = false;

      notifyListeners();
      await auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 10),
          verificationCompleted: (_) {},
          verificationFailed: (FirebaseAuthException e) {
            isLoadingSend = false;
            notifyListeners();
            if (e.code == 'invalid-phone-number') {
              onVerificationFailure('Please Enter a Valid Phone Number');
              return;
            }
            onVerificationFailure(
                'Make sure your device has a working internet connection');
          },
          codeSent: (verificationId, resendToken) {
            setResendCode(false);
            _verificationId = verificationId;
            isLoadingSend = false;
            codeSent = true;
            notifyListeners();
            Future.delayed(const Duration(seconds: 180), () {
              setResendCode(true);
            });
          },
          codeAutoRetrievalTimeout: (_) {});
    } catch (e) {
      isLoadingSend = false;
      notifyListeners();
      rethrow;
    }
  }

  Future verifyCode(String verificationCode) async {
    final auth = FirebaseAuth.instance;
    try {
      setIsVerificationLoading(true);
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: verificationCode);
      await auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> checkIsUserRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('isRegistered') ?? false;
    return isRegistered;
  }

  Future setRegisteredInDb() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isRegistered', true);
  }

  Future saveUserProfileToLocalStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('userData', jsonEncode(_userData));
    setRegisteredInDb();
  }

  Future getUserProfileFromStorage() async {
    return SharedPreferences.getInstance().then((prefs) {
      final data = prefs.getString('userData');
      if (data != null) {
        _userData = jsonDecode(data);
      }
    });
  }

  Future<bool> checkIfUserExists() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      if (docSnapshot.exists) {
        setRegisteredInDb();
        _userData['username'] = docSnapshot['username'];
        _userData['email'] = docSnapshot['email'];
        _userData['gender'] = docSnapshot['gender'];
        _userData['imageUrl'] = docSnapshot['imageUrl'];
        saveUserProfileToLocalStorage();

        return true;
      } else {
        return false;
      }
    } catch (_) {
      rethrow;
    }
  }

  Future saveUserProfileToDB({
    required String name,
    required String gender,
    String? email,
  }) async {
    isLoadingSend = true;
    notifyListeners();
    String? imageUrl;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    if (imageFile != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('userImages')
            .child('$userId.jpg');
        await storageRef.putFile(imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      } catch (e) {
        isLoadingSend = false;
        notifyListeners();
        rethrow;
      }
      final db = FirebaseFirestore.instance;
      final path = db.collection('users').doc(userId);
      try {
        await db.runTransaction((transaction) async {
          transaction.set(path, {
            'username': name,
            'email': email,
            'imageUrl': imageUrl,
            'gender': gender,
          });
        }).then((value) {
          _userData = {
            'username': name,
            'email': email,
            'imageUrl': imageUrl,
            'gender': gender,
          };
        }).timeout(const Duration(seconds: 10), onTimeout: () {
          throw 'timeout';
        });
        await saveUserProfileToLocalStorage();

        isLoadingSend = false;
        notifyListeners();
      } catch (e) {
        isLoadingSend = false;
        notifyListeners();
        rethrow;
      }
      return;
    }
    if (imageFile == null) {
      final db = FirebaseFirestore.instance;
      final path = db.collection('users').doc(userId);
      imageUrl = 'gs://locallo-17fec.appspot.com/userImages/default.png';
      try {
        await db.runTransaction((transaction) async {
          transaction.set(path, {
            'username': name,
            'email': email,
            'imageUrl': imageUrl,
            'gender': gender,
          });
        }).then((value) {
          _userData = {
            'username': name,
            'email': email,
            'imageUrl': imageUrl,
            'gender': gender,
          };
        }).timeout(const Duration(seconds: 10), onTimeout: () {
          throw 'timeout';
        });
        await saveUserProfileToLocalStorage();

        isLoadingSend = false;
        notifyListeners();
        return;
      } catch (e) {
        isLoadingSend = false;
        notifyListeners();
        rethrow;
      }
    }
  }
}
