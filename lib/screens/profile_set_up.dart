import 'package:flutter/material.dart';
import 'package:local_lo/Utilities/colors_typography.dart';
import 'package:local_lo/Utilities/common_functions.dart';
import 'package:local_lo/Utilities/info_dialogs.dart';
import 'package:local_lo/providers/user_auth.dart';
import 'package:provider/provider.dart';

enum Gender { Male, Female }

Gender gender = Gender.Male;

class ProfileSetUp extends StatefulWidget {
  const ProfileSetUp({super.key});

  @override
  State<ProfileSetUp> createState() => _ProfileSetUpState();
}

class _ProfileSetUpState extends State<ProfileSetUp> {
  final _formKey = GlobalKey<FormState>();
  late FocusNode _nameFocusNode;
  late FocusNode _emailFocusNode;
  String? name;
  String? email;

  void onUserRegisterationComplete() {
    Navigator.of(context).pushReplacementNamed('/homescreen');
  }

  @override
  void initState() {
    // TODO: implement initState
    _nameFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final userAuth = Provider.of<UserAuth>(context, listen: false);
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 40 - (screenKeyboardHeight / 15),
            ),
            Container(
              alignment: Alignment.center,
              child: Text(
                'Set Up your Profile',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            SizedBox(
              height: 40 - (screenKeyboardHeight / 15),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Consumer<UserAuth>(
                                    builder: (context, value, child) {
                                  if (value.imageFile == null) {
                                    return const CircleAvatar(
                                      backgroundColor: ColorsTypography
                                          .formInputBackgroundColor,
                                      maxRadius: 44,
                                    );
                                  }
                                  return CircleAvatar(
                                    maxRadius: 44,
                                    backgroundImage: Image.file(
                                      value.imageFile!,
                                      fit: BoxFit.cover,
                                    ).image,
                                  );
                                }),
                                const SizedBox(
                                  width: 10,
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final photo = await CommonFunctions
                                        .getImageFromCamera();
                                    if (photo != null) {
                                      userAuth.setImageFile(photo);
                                      return;
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 25),
                                  label: const Text(
                                    'Add Image',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 25,
                            ),
                            TextFormField(
                              onChanged: (value) {
                                name = value;
                              },
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return 'Provide a Name';
                                }
                                if (value.contains(RegExp(r'[0-9]'))) {
                                  return 'Names can not have Numbers in them';
                                }
                                if (value.length < 3) {
                                  return 'Provide a valid Name';
                                }
                                return null;
                              },
                              focusNode: _nameFocusNode,
                              style: Theme.of(context).textTheme.bodyMedium,
                              decoration:
                                  const InputDecoration(hintText: 'Name'),
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              onEditingComplete: () {
                                _nameFocusNode.unfocus();
                                FocusScope.of(context)
                                    .requestFocus(_emailFocusNode);
                              },
                            ),
                            const SizedBox(
                              height: 25,
                            ),
                            TextFormField(
                              onChanged: (value) {
                                email = value;
                              },
                              validator: (value) {
                                if (value!.isEmpty) {
                                  email = null;
                                  return null;
                                }

                                if (value.contains('@') &&
                                    value.contains('.') &&
                                    value.length > 5) {
                                  return null;
                                }
                                return 'Enter a Valid Email or Leave Empty';
                              },
                              focusNode: _emailFocusNode,
                              style: Theme.of(context).textTheme.bodyMedium,
                              decoration:
                                  const InputDecoration(hintText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(
                              height: 25,
                            ),
                            const GenderOptions(),
                            const SizedBox(
                              height: 25,
                            ),
                            Consumer<UserAuth>(
                              builder: (context, value, child) =>
                                  ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  fixedSize: ColorsTypography.formButtonSize,
                                ),
                                onPressed: () async {
                                  _nameFocusNode.unfocus();
                                  _emailFocusNode.unfocus();
                                  if (_formKey.currentState!.validate()) {
                                    if (email == null) {
                                      email = 'not-provided';
                                    }
                                    try {
                                      await userAuth.saveUserProfileToDB(
                                        name: name!,
                                        gender: gender.name,
                                        email: email,
                                      );
                                      onUserRegisterationComplete();
                                    } catch (_) {
                                      InfoDialogs.showErrorDialog(context,
                                          'Make sure your device has a working internet connection');
                                    }
                                  }
                                },
                                child: value.isLoadingSend == true
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      )
                                    : const Text(
                                        'Confirm',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenderOptions extends StatefulWidget {
  const GenderOptions({
    Key? key,
  }) : super(key: key);

  @override
  State<GenderOptions> createState() => _GenderOptionsState();
}

class _GenderOptionsState extends State<GenderOptions> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: gender != Gender.Male
                  ? ColorsTypography.formInputBackgroundColor
                  : ColorsTypography.messageBubbleColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(
                  20,
                ),
              ),
            ),
            child: RadioListTile(
                contentPadding: const EdgeInsets.all(0),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      20,
                    ),
                  ),
                ),
                title: Text(
                  'Male',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                value: Gender.Male,
                groupValue: gender,
                onChanged: (value) {
                  setState(() {
                    gender = value!;
                  });
                }),
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: gender == Gender.Male
                  ? ColorsTypography.formInputBackgroundColor
                  : ColorsTypography.messageBubbleColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(
                  20,
                ),
              ),
            ),
            child: RadioListTile(
                contentPadding: const EdgeInsets.all(0),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      20,
                    ),
                  ),
                ),
                title: Text(
                  'Female',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                value: Gender.Female,
                groupValue: gender,
                onChanged: (value) {
                  setState(() {
                    gender = value!;
                  });
                }),
          ),
        )
      ],
    );
  }
}
