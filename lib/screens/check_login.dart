import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:try_auth/Functions/auth.dart';
import 'package:try_auth/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckLoginPage extends StatefulWidget {
  const CheckLoginPage({super.key});

  @override
  State<CheckLoginPage> createState() => _CheckLoginPageState();
}

class _CheckLoginPageState extends State<CheckLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? mtoken = " ";
  late User? _user;
  final String _loginMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    setState(() {
      _user = currentUser;
    });
  }

  void saveToken(String token, user) async {
    String googleUserName = user?.displayName ?? 'temp';
    await FirebaseFirestore.instance
        .collection("UserTokens")
        .doc(googleUserName)
        .set({'token': token});
  }

  void getToken() async {
    await FirebaseMessaging.instance.getToken().then((token) {
      setState(() {
        mtoken = token;
        print("My token is $mtoken");
      });
      saveToken(token!, _user);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible:
                        false, // Prevents user from dismissing the dialog
                    builder: (BuildContext context) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    },
                  );

                  await signInWithGoogle();
                  _fetchUser();
                  getToken();
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },

                // () {
                //   Navigator.pushReplacement(
                //     context,
                //     MaterialPageRoute(
                //       builder: (context) => const LoginPage(),
                //     ),
                //   );
                // },
                child: Text("Login"))
          ],
        ),
      ),
    );
  }
}
