import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yugtalk/Modules/Authentication/Verification_Widget.dart';
import 'package:yugtalk/Modules/Authentication/ForgotPassword_Widget.dart';
import '../../Screens/Home_Screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class Authentication_Mod extends StatefulWidget {
  const Authentication_Mod({Key? key});

  @override
  _Authentication_ModState createState() => _Authentication_ModState();
}

class _Authentication_ModState extends State<Authentication_Mod>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Welcome to YugTalk!',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              tabs: [
                Tab(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _tabController.animateTo(0);
                    },
                    child: Container(
                      decoration: const BoxDecoration(),
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Tab(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _tabController.animateTo(1);
                    },
                    child: Container(
                      decoration: const BoxDecoration(),
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Register',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            LoginWidget(onContinue: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const Home_Mod(),
                  settings: const RouteSettings(name: Home_Mod.routeName),
                ),
              );
            }),
            RegisterWidget(onRegistered: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Verification_Widget(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class LoginWidget extends StatefulWidget {
  final Function onContinue;

  const LoginWidget({Key? key, required this.onContinue}) : super(key: key);

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  bool _isLoading = false;
  bool _obscureText = true;
  late TextEditingController emailController;
  late TextEditingController passwordController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signInWithEmailAndPassword(
      BuildContext context, String email, String password) async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection.'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user != null && user.emailVerified) {
        widget.onContinue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified or user does not exist.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing in: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/images/welcomeLogin.png',
                height: 250,
                width: 250,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: MediaQuery.of(context).size.width * 0.5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscureText,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : FloatingActionButton.extended(
                        onPressed: () {
                          String email = emailController.text.trim();
                          String password =
                          passwordController.text.trim();
                          if (email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please fill in all the fields.'),
                              ),
                            );
                          } else {
                            signInWithEmailAndPassword(
                                context, email, password);
                          }
                        },
                        backgroundColor: const Color(0xFFe8c221),
                        label: const Text('Continue'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const ForgotPassword_Widget(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterWidget extends StatefulWidget {
  final Function onRegistered;

  const RegisterWidget({Key? key, required this.onRegistered})
      : super(key: key);

  @override
  _RegisterWidgetState createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isReenterPasswordVisible = false;
  bool _termsAccepted = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController guardianNoController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController reenterPasswordController =
  TextEditingController();

  @override
  Widget build(BuildContext context) {
    Future<void> _registerUser(BuildContext context) async {
      try {
        setState(() {
          _isLoading = true;
        });

        final String fullName = nameController.text.trim();
        final int age = int.tryParse(ageController.text.trim()) ?? 0;
        final String guardianName = guardianNameController.text.trim();
        final String guardianNo = guardianNoController.text.trim();
        final String email = emailController.text.trim();
        final String password = passwordController.text.trim();

        final String reenteredPassword = reenterPasswordController.text.trim();
        if (password != reenteredPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Passwords don't match")),
          );
          return;
        }

        if (fullName.isEmpty ||
            age == 0 ||
            guardianName.isEmpty ||
            guardianNo.isEmpty ||
            email.isEmpty ||
            password.isEmpty ||
            reenteredPassword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill in all fields")),
          );
          return;
        }

        if (!_termsAccepted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Please accept the Terms and Conditions")),
          );
          return;
        }

        final QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance.collection('user').get();

        int highestId = 0;
        for (final doc in querySnapshot.docs) {
          final int docId = int.tryParse(doc.id) ?? 0;
          if (docId > highestId) {
            highestId = docId;
          }
        }

        final String userId = (highestId + 1).toString();

        UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await FirebaseFirestore.instance.collection('user').doc(userId).set({
          'fullName': fullName,
          'age': age,
          'guardianName': guardianName,
          'guardianNo': guardianNo,
          'email': email,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User registered successfully')),
        );

        widget.onRegistered();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering user: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }

    void _showTermsDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Terms and Conditions'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Welcome to YugTalk, ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'an Augmentative and Alternative Communication (AAC) app designed for academic research to aid pediatric patients aged 3-5 with speech and language disorders, while facilitating assessments and therapeutic sessions. By using this app, users agree to be bound by the following terms and conditions:\n\n',
                        ),
                        TextSpan(
                          text: '1. Purpose of the App:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'YugTalk serves as an AAC tool to assist children diagnosed with speech and language disorders, including apraxia of speech, phonological disorders, and receptive-expressive language disorder. The app facilitates communication using symbols and images in both Filipino and English languages. It also supports guardians in guiding children and allows Speech-Language Pathologists (SLPs) to perform standard assessments such as modified Preschool Language Scale, Fifth Edition (PLS-5) or Brigance.\n\n',
                        ),
                        TextSpan(
                          text: '2. Responsibility:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'Parents or legal guardians must supervise and monitor the use of YugTalk by children aged 3-5. This includes ensuring appropriate usage and providing necessary support during app interactions. Guardians are expected to follow the guidance provided by the research team and SLPs regarding the safe and effective use of the app.\n\n',
                        ),
                        TextSpan(
                          text: '3. Privacy and Data Security:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'The privacy and security of user data are prioritized in compliance with the Data Privacy Act of 2012 (R.A. 10173) and the Cybercrime Prevention Act of 2012 (R.A. 10175). YugTalk uses Firebase authentication to ensure data security. All collected data will be anonymized and aggregated, and will not be shared with third parties without consent, except as required by law. Users have the right to access, correct, or delete their personal data. The validity of testing and results is overseen by the collaborating SLPs.\n\n',
                        ),
                        TextSpan(
                          text: '4. Accessibility:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'In accordance with the Magna Carta for Disabled Persons (R.A. 7277), YugTalk is designed to be accessible to persons with disabilities. The app implements features such as alternative text for images and easy navigation to ensure usability for people with various types of disabilities. YugTalk is intended to be used under the guidance of guardians or SLPs and is not designed for independent use by pediatric patients.\n\n',
                        ),
                        TextSpan(
                          text: '5. Research Purposes:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'YugTalk is developed for academic research and will not be published or distributed commercially. Any data collected will be used solely for research purposes.\n\n',
                        ),
                        TextSpan(
                          text: '6. User Conduct:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'Users agree to use YugTalk in a manner consistent with its intended research purpose and refrain from activities that may disrupt or harm the app\'s functionality or compromise the research integrity.\n\n',
                        ),
                        TextSpan(
                          text: '7. Installation and Updates:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'YugTalk will be sideloaded onto iPads provided by the research team. Parents or legal guardians agree to allow their child to use YugTalk under supervision for the duration of the research study.\n\n',
                        ),
                        TextSpan(
                          text: '8. Feedback and Support:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'For any technical issues or feedback, users should contact the thesis developers who serve as the support team for this research project.\n\n',
                        ),
                        TextSpan(
                          text: '9. Intellectual Property:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'YugTalk respects intellectual property rights as per the Intellectual Property Code of the Philippines (R.A. 8293). All content within YugTalk, including images, symbols, and educational materials, is the property of the research team or used with permission. Licenses have been obtained for all third-party content used in the app to avoid infringing on any copyrights or trademarks. Users may not reproduce, distribute, or create derivative works from this content without explicit permission.\n\n',
                        ),
                        TextSpan(
                          text: '10. Child Protection:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                          'In accordance with the Special Protection of Children Against Abuse, Exploitation and Discrimination Act (R.A. 7610), verifiable parental consent is obtained before collecting, using, or disclosing personal information from children. The privacy policy clearly states data collection practices related to children and how their data is protected.\n\n',
                        ),
                        TextSpan(
                          text: '11. Professional Use:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: 'In accordance with the Speech Language Pathology Act (R.A. 11249), the Activity Mode of the app can only be used and accessed by a Speech Language Pathologist. This ensures that the assessment of the child is conducted correctly by a professional in the field of speech therapy.\n\n',
                        ),
                        TextSpan(
                          text: '12. Governing Law:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: 'These terms and conditions are governed by and construed in accordance with the laws of the Philippines, including but not limited to the Data Privacy Act of 2012 (R.A. 10173), the Cybercrime Prevention Act of 2012 (R.A. 10175), the Magna Carta for Disabled Persons (R.A. 7277), the Intellectual Property Code of the Philippines (R.A. 8293), the Special Protection of Children Against Abuse, Exploitation and Discrimination Act (R.A. 7610), and the Speech Language Pathology Act (R.A. 11249). Any disputes arising from the use of YugTalk or these terms shall be subject to the exclusive jurisdiction of the courts in the Philippines. Users agree to comply with all applicable local, national, and international laws and regulations in their use of YugTalk.\n\n',
                        ),
                        TextSpan(
                          text:
                          'By using YugTalk, users acknowledge that they have read, understood, and agree to abide by these terms and conditions. Users also consent to participate in this academic research study under the specified conditions.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _termsAccepted = true;
                  });
                },
              ),
            ],
          );
        },
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'New user?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: MediaQuery.of(context).size.width * 0.5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name of User',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Age of User',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: guardianNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name of Guardian',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: guardianNoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Guardian Contact Number',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Theme.of(context).primaryColorDark,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reenterPasswordController,
                        obscureText: !_isReenterPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Re-enter Password',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isReenterPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Theme.of(context).primaryColorDark,
                            ),
                            onPressed: () {
                              setState(() {
                                _isReenterPasswordVisible =
                                !_isReenterPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: _termsAccepted,
                            onChanged: (bool? value) {
                              setState(() {
                                _termsAccepted = value ?? false;
                              });
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              _showTermsDialog(context);
                            },
                            child: RichText(
                              text: const TextSpan(
                                text: 'I accept the ',
                                style: TextStyle(color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                        _isLoading ? null : () => _registerUser(context),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all<Color>(
                              const Color(0xFFe8c221)),
                          foregroundColor:
                          WidgetStateProperty.all<Color>(Colors.white),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                            : const Text('Register'),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
