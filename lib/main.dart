import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as Path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Earthy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            padding: MaterialStateProperty.all<EdgeInsets>(
              EdgeInsets.symmetric(vertical: 12.0),
            ),
          ),
        ),
      ),
      home: const SignInScreen(),
      routes: {
        HomeScreen.routeName: (context) => HomeScreen(),
        OrdersScreen.routeName: (context) => OrdersScreen(),
        CartScreen.routeName: (context) => CartScreen(),
      },
    );
  }
}

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamController<ConnectivityResult> connectivityController = StreamController<ConnectivityResult>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      connectivityController.add(result);
    });
  }

  void disposeStream() => connectivityController.close();
}


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();

  bool _isSignUpEnabled = false;
  bool _isEmailValid = true;
  String _selectedRole = 'consumer';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_checkIfSignUpEnabled);
    _emailController.addListener(_checkIfSignUpEnabled);
    _passwordController.addListener(_checkIfSignUpEnabled);
    _businessNameController.addListener(_checkIfSignUpEnabled);
    _businessAddressController.addListener(_checkIfSignUpEnabled);
    _taxIdController.addListener(_checkIfSignUpEnabled);
  }


  void _checkIfSignUpEnabled() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final isEmailValid = EmailValidator.validate(email);

    bool isProducerInfoValid = true;
    if (_selectedRole == 'producer') {
      final businessName = _businessNameController.text.trim();
      final businessAddress = _businessAddressController.text.trim();
      final taxId = _taxIdController.text.trim();
      isProducerInfoValid = businessName.isNotEmpty && businessAddress.isNotEmpty && taxId.isNotEmpty;
    }

    setState(() {
      if (email.isEmpty) {
        _isSignUpEnabled = false;
        _isEmailValid = true;
      } else {
        _isSignUpEnabled = name.isNotEmpty && isEmailValid && password.isNotEmpty && isProducerInfoValid;
        _isEmailValid = isEmailValid;
      }
    });
  }

  Future<void> _signUpWithEmailAndPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final createdAt = Timestamp.now();

    setState(() {
      _isLoading = true;  // Start loading
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create document in 'users'
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'createdAt': createdAt,
          'profilePictureUrl': 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/default_profile_pic.png?alt=media&token=549eda7d-a11f-4a30-9b4f-ddebd15b8d48', // Default value for profile picture URL
          'role': _selectedRole,
        });

        // If the user is a producer, also create a document in 'producers' collection
        if (_selectedRole == 'producer') {
          final businessName = _businessNameController.text.trim();
          final businessAddress = _businessAddressController.text.trim();
          final taxId = _taxIdController.text.trim();

          await FirebaseFirestore.instance.collection('producers').doc(userCredential.user!.uid).set({
            'userId': userCredential.user!.uid,
            'businessName': businessName,
            'businessAddress': businessAddress,
            'taxId': taxId,
            'createdAt': createdAt,
          });
        }

        // Create document in settings collection
        await FirebaseFirestore.instance.collection('settings').doc(userCredential.user!.uid).set({
          'notifications': true, // Default value for notifications
          'language': 'en', // Default language
        });

        // Go to the sign-up success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SignUpSuccessScreen()),
        );
      }
      setState(() {
        _isLoading = false;  // Stop loading
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;  // Stop loading
      });
      String errorMessage = "An error occurred during sign up. Please try again later.";

      if (e.code == 'email-already-in-use') {
        errorMessage = "The email address is already in use by another account.";
      } else if (e.code == 'weak-password') {
        errorMessage = "The password provided is too weak.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is not valid.";
      }


      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Sign Up Failed"),
            content: Text(errorMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Sign Up Failed"),
            content: Text("An unexpected error occurred. Please try again later."),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/images/food_pyramid.jpg'),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email),
                  errorText: _isEmailValid ? null : 'Please enter a valid email address.',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24.0),
              ToggleButtons(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart),
                        SizedBox(width: 4.0),
                        Text('Consumer'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.business),
                        SizedBox(width: 4.0),
                        Text('Producer'),
                      ],
                    ),
                  ),
                ],
                isSelected: [
                  _selectedRole == 'consumer',
                  _selectedRole == 'producer',
                ],
                onPressed: (int index) {
                  setState(() {
                    _selectedRole = index == 0 ? 'consumer' : 'producer';
                    _checkIfSignUpEnabled();
                  });
                },
              ),
              SizedBox(height: 24.0),
              if (_selectedRole == 'producer') ...[
                TextField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: 'Business Name',
                    errorText: !_isSignUpEnabled && _selectedRole == 'producer' ? 'This field is required' : null,
                  ),
                ),
                SizedBox(height: 16.0),
                TextField(
                  controller: _businessAddressController,
                  decoration: InputDecoration(
                    labelText: 'Business Address',
                    errorText: !_isSignUpEnabled && _selectedRole == 'producer' ? 'This field is required' : null,
                  ),
                ),
                SizedBox(height: 16.0),
                TextField(
                  controller: _taxIdController,
                  decoration: InputDecoration(
                    labelText: 'Tax ID',
                    errorText: !_isSignUpEnabled && _selectedRole == 'producer' ? 'This field is required' : null,
                  ),
                ),
              ],
              SizedBox(height: 24.0),
              Opacity(
                opacity: _isSignUpEnabled ? 1.0 : 0.5,
                child: ElevatedButton(
                  onPressed: _isLoading || !_isSignUpEnabled ? null : _signUpWithEmailAndPassword,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign up'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    backgroundColor: _isSignUpEnabled ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 36.0),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SignInScreen()),
                  );
                },
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}



class OrdersScreen extends StatefulWidget {
  @override
  _OrdersScreenState createState() => _OrdersScreenState();
  static const String routeName = '/orders';
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedIndex = 1;

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    var ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid) // Filter orders by userId
        .orderBy('createdAt', descending: true) // Order by createdAt, newest first
        .get();

    return ordersSnapshot.docs.map((doc) => {
      "orderId": doc.id,
      ...doc.data()
    }).toList();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orders'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No orders found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var order = snapshot.data![index];
              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(Icons.receipt_long, color: Colors.green),
                  title: Text('Order ID: ${order['orderId']}'),
                  subtitle: Text('Total: ${order['amount'].toStringAsFixed(2)}€\nStatus: ${order['status']}\nDate: ${DateFormat('yyyy-MM-dd – kk:mm').format(order['createdAt'].toDate())}'),
                  isThreeLine: true,
                  onTap: () {
                    // Go to OrderDetailsScreen on tap
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: order['orderId'])),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),
    );
  }
}



class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSignInEnabled = false;
  bool _isEmailValid = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_checkIfSignInEnabled);
    _passwordController.addListener(_checkIfSignInEnabled);
  }

  void _checkIfSignInEnabled() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final isEmailValid = EmailValidator.validate(email);
    setState(() {
      _isSignInEnabled = isEmailValid && password.isNotEmpty;
      _isEmailValid = isEmailValid;
    });
  }

  Future<void> _signInWithEmailAndPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;  // Start loading
    });

    if (!EmailValidator.validate(email)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Invalid Email"),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline, color: Colors.red, size: 24.0),
                SizedBox(width: 10),
                Expanded(
                  child: Text("Please enter a valid email address."),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Fetch user data
        final doc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        final userData = doc.data();

        if (userData != null) {
          // Go to the correct screen based on user role
          if (userData['role'] == 'producer') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => ProducerHomeScreen()), // Producer home screen
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomeScreen()), // Consumer home screen
            );
          }
        }
        setState(() {
          _isLoading = false;  // Stop loading
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;  // Stop loading
      });
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Sign In Failed"),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline, color: Colors.red, size: 24.0),
                SizedBox(width: 10),
                Expanded(
                  child: Text("The email address or password is incorrect. Please try again."),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome Back!',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0),
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/images/tomato_hands.jpg'),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email),
                  errorText: _isEmailValid ? null : 'Please enter a valid email address.',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24.0),
              Opacity(
                opacity: _isSignInEnabled ? 1.0 : 0.5,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_isSignInEnabled ? _signInWithEmailAndPassword : null),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign in'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    backgroundColor: _isSignInEnabled ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 36.0),
                  ),
                ),
              ),

              SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                },
                child: Text(
                  'Don\'t have an account? Sign up',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}



class SignUpSuccessScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sign Up Successful'),
          automaticallyImplyLeading: false, // Remove the back button
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 100, color: Colors.green),
              SizedBox(height: 20),
              Text(
                'Sign Up Successful!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => SignInScreen()),
                      );
                    },
                    child: Text('Sign in'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
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



class ProducerCard extends StatelessWidget {
  final Map<String, dynamic> producerData;
  final VoidCallback onTap;

  const ProducerCard({
    Key? key,
    required this.producerData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 160,
          height: 250,
          child: ListView(
            shrinkWrap: true,
            children: [
              Image.network(
                (producerData['profilePictureUrl'] == null || producerData['profilePictureUrl'].isEmpty)
                    ? 'https://cdn-icons-png.flaticon.com/512/6522/6522516.png'
                    : producerData['profilePictureUrl'],
                height: 100,
                width: 160,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      producerData['name'],
                      style: Theme.of(context).textTheme.subtitle1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'from ${producerData['businessAddress']}',
                      style: Theme.of(context).textTheme.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProducerProductsScreen(producerId: producerData['userId']),
                          ),
                        );
                      },
                      child: Text(
                        'Explore Products',
                        textAlign: TextAlign.center,
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        alignment: Alignment.center,
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  static const String routeName = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  late Future<Map<String, dynamic>?> userData;
  late Future<List<Map<String, dynamic>>> productsData;
  Future<List<Map<String, dynamic>>>? producersData;
  int _selectedIndex = 0;

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (user != null) {
      userData = getUserData(user!.uid);
      productsData = getProductsData();
      producersData = getProducersData();
    }
  }

  Future<List<Map<String, dynamic>>> getProducersData() async {
    // Fetch producers
    var producersSnapshot = await FirebaseFirestore.instance.collection('producers').get();

    List<Map<String, dynamic>> producersList = [];

    // Go over producers to fetch their user details
    for (var producerDoc in producersSnapshot.docs) {
      var producerData = producerDoc.data();

      // Fetch user data using the userId from the producer data
      var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(producerData['userId']).get();
      var userData = userSnapshot.data();

      var combinedData = {
        'userId': producerData['userId'],
        'businessName': producerData['businessName'],
        'businessAddress': producerData['businessAddress'],
        'profilePictureUrl': userData?['profilePictureUrl'],
        'name': userData?['name'],
        'email': userData?['email'],
      };

      producersList.add(combinedData);
    }

    return producersList;
  }


  void navigateToProductListScreen(String categoryName) {
    bool isNewCategory = categoryName == "New"; // Determine if the category is "New"
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductListScreen(categoryName: categoryName, isNewCategory: isNewCategory),
      ),
    );
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    var snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return snapshot.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: FutureBuilder<Map<String, dynamic>?>(
          future: userData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return buildUserGreeting(snapshot.data);
            }
            return Container();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            color: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
          SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SearchResultsScreen(searchQuery: _searchController.text),
                  ));
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25.0)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            BrowseCategories(navigateToCategory: navigateToProductListScreen),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Browse by Producer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: producersData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (snapshot.hasData) {
                      return Container(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            var producer = snapshot.data![index];
                            return ProducerCard(
                              producerData: producer,
                              onTap: () {
                              },
                            );
                          },
                        ),
                      );
                    } else {
                      return SizedBox();
                    }
                  }
                  return Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),

    );
  }

  Widget buildUserGreeting(Map<String, dynamic>? data) {
    String name = data?['name'] ?? 'Guest';
    return Text('Hi, $name!',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}


class ProducerProductsScreen extends StatefulWidget {
  final String producerId;

  const ProducerProductsScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  _ProducerProductsScreenState createState() => _ProducerProductsScreenState();
}

class _ProducerProductsScreenState extends State<ProducerProductsScreen> {
  late Future<List<Map<String, dynamic>>> products;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    products = getProducerProducts(widget.producerId);
  }

  Future<List<Map<String, dynamic>>> getProducerProducts(String producerId) async {
    // Fetch products from the 'products' collection where 'producerId' matches
    var productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('producerId', isEqualTo: producerId)
        .get();

    // Fetch the producer's details from the 'users' collection using the producerId
    var producerSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(producerId)
        .get();

    // If the producer does not exist or has no data, return an empty list
    if (!producerSnapshot.exists || producerSnapshot.data() == null) {
      return [];
    }

    // Extract the producer's name and image URL
    var producerData = producerSnapshot.data()!;
    var producerName = producerData['name'];
    var producerImageUrl = producerData['profilePictureUrl'];

    // Map each product to include the producer's name and image URL
    return productsSnapshot.docs.map((doc) {
      var productData = doc.data();
      return {
        ...productData,
        'producerName': producerName,
        'producerImageUrl': producerImageUrl,
        'id': doc.id,
      };
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Producer Products'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData && snapshot.data!.isEmpty) {
              return Center(
                child: Text('No products available from this producer'),
              );
            } else if (snapshot.hasData) {
              var productsList = snapshot.data!;
              return ListView.builder(
                itemCount: productsList.length,
                itemBuilder: (context, index) {
                  var product = productsList[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(productData: product),
                        ),
                      );
                    },
                    child: Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  (product['producerImageUrl'] != null && product['producerImageUrl'].isNotEmpty)
                                      ? product['producerImageUrl']
                                      : 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/default_profile_pic.png?alt=media&token=549eda7d-a11f-4a30-9b4f-ddebd15b8d48'),
                              radius: 24,
                            ),
                            title: Text(product['producerName'] ?? 'Unknown Producer'),
                            subtitle: Text(product['name']),
                            trailing: Text('€${product['price'].toStringAsFixed(2)}/kg'),
                          ),
                          Image.network(
                            product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                                ? product['imageUrl']
                                : 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/defaultProductImage.jpeg?alt=media&token=a152dc4e-2514-437d-8862-f6f6ced8627f',
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );

            }
          }
          // Show loading
          return Center(child: CircularProgressIndicator());
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),
    );
  }
}


Future<List<Map<String, dynamic>>> getProductsData([String? searchQuery]) async {
  Query<Map<String, dynamic>> productsQuery = FirebaseFirestore.instance.collection('products');

  if (searchQuery != null && searchQuery.isNotEmpty) {
    var searchQueryLowerCase = searchQuery.toLowerCase();

    var usersSnapshot = await FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'producer')
        .get();

    var filteredUsers = usersSnapshot.docs.where((doc) {
      var name = doc['name'];
      var lowercaseName = name.toLowerCase();
      return lowercaseName.contains(searchQueryLowerCase);
    });

    List<String> userIds = filteredUsers.map((doc) => doc.id).toList();

    List<Map<String, dynamic>> results = [];

    if (userIds.isNotEmpty) {
      var productsByProducer = await productsQuery.where('producerId', whereIn: userIds).get();
      results.addAll(productsByProducer.docs.map((doc) {
        var productData = doc.data();
        return {
          ...productData,
          'id': doc.id,
        };
      }).toList());
    }

    var allProductsSnapshot = await productsQuery.get();
    var productsByName = allProductsSnapshot.docs.where((doc) {
      var name = doc['name'];
      var lowercaseName = name.toLowerCase();
      return lowercaseName.contains(searchQueryLowerCase);
    });

    results.addAll(productsByName.map((doc) {
      var productData = doc.data();
      return {
        ...productData,
        'id': doc.id,
      };
    }).toList());

    for (var product in results) {
      var producerId = product['producerId'];
      if (producerId != null) {
        var producerSnapshot = await FirebaseFirestore.instance.collection('users').doc(producerId).get();
        var producerData = producerSnapshot.data();
        if (producerData != null) {
          product['producerName'] = producerData['name'];
          product['producerImageUrl'] = producerData['profilePictureUrl'];
        } else {
          product['producerName'] = 'Unknown Producer';
          product['producerImageUrl'] = 'https://cdn-icons-png.flaticon.com/512/6522/6522516.png';
        }
      }
    }

    return results;
  } else {
    // Return empty list if searchQuery is null or empty
    return [];
  }
}



class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;
  const SearchResultsScreen({Key? key, required this.searchQuery}) : super(key: key);

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> searchResults;

  @override
  void initState() {
    super.initState();
    searchController.text = widget.searchQuery;
    searchResults = getProductsData(widget.searchQuery);
    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (searchController.text.isNotEmpty) {
      setState(() {
        searchResults = getProductsData(searchController.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Search Results"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              autofocus: true,
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: searchResults,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  var productsList = snapshot.data!;
                  return ListView.builder(
                    itemCount: productsList.length,
                    itemBuilder: (context, index) {
                      var product = productsList[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(productData: product),
                            ),
                          );
                        },
                        child: Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      (product['producerImageUrl'] != null && product['producerImageUrl'].isNotEmpty)
                                          ? product['producerImageUrl']
                                          : 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/default_profile_pic.png?alt=media&token=549eda7d-a11f-4a30-9b4f-ddebd15b8d48'),
                                ),
                                title: Text(product['producerName'] ?? 'Unknown Producer'),
                              ),
                              Image.network(
                                product['imageUrl'] ?? 'https://via.placeholder.com/150',
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                              ListTile(
                                title: Text(product['name']),
                                subtitle: Text('\€${product['price'].toString()}/kg'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}


class BrowseCategories extends StatelessWidget {
  final Function(String) navigateToCategory;

  const BrowseCategories({Key? key, required this.navigateToCategory}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Browse by Category',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Categories(navigateToCategory: navigateToCategory),
      ],
    );
  }
}

class Categories extends StatelessWidget {
  final Function(String) navigateToCategory;

  const Categories({Key? key, required this.navigateToCategory}) : super(key: key);


  final double cardWidth = 70;
  final double cardHeight = 70;
  final double iconSize = 43;
  final double textSize = 16;

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> categories = [
      {"icon": Icons.new_releases, "text": "New"},
      {"icon": Icons.local_florist, "text": "Fruits"},
      {"icon": Icons.grass, "text": "Vegetables"},
      {"icon": Icons.eco, "text": "Greens"},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        children: List.generate(
          categories.length,
              (index) => CategoryCard(
                icon: categories[index]["icon"],
                text: categories[index]["text"],
                press: navigateToCategory,
                width: cardWidth,
                height: cardHeight,
                iconSize: iconSize,
                textSize: textSize,
                categoryName: categories[index]["text"],
              ),
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    Key? key,
    required this.icon,
    required this.text,
    required this.press,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.textSize,
    required this.categoryName,
  }) : super(key: key);

  final IconData icon;
  final String text;
  final Function(String) press;
  final double width;
  final double height;
  final double iconSize;
  final double textSize;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => press(categoryName),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all((height - iconSize) / 4),
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: iconSize),
          ),
          SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: textSize),
          ),
        ],
      ),
    );
  }
}


// Products Category Screen
class ProductListScreen extends StatefulWidget {
  final String categoryName;
  final bool isNewCategory;

  const ProductListScreen({Key? key, required this.categoryName, required this.isNewCategory}) : super(key: key);

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> products;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    products = getProductsByCategory(widget.categoryName, widget.categoryName == 'New');
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(String categoryName, bool isNewCategory) async {
    Query<Map<String, dynamic>> productQuery = FirebaseFirestore.instance
        .collection('products');

    if (!isNewCategory) {
      // If it's not the "New" category, filter by the provided category
      productQuery = productQuery.where('category', isEqualTo: categoryName);
    } else {
      // If it's the "New" category, filter by newFlag being true
      productQuery = productQuery.where('newFlag', isEqualTo: true);
    }

    var productSnapshot = await productQuery.get();

    List<Map<String, dynamic>> productList = [];
    for (var productDoc in productSnapshot.docs) {
      var productData = productDoc.data();
      productData['id'] = productDoc.id;

      // Fetch producer's data
      var producerSnapshot = await FirebaseFirestore.instance.collection('users').doc(productData['producerId']).get();
      var producerData = producerSnapshot.data();

      // Combine product and producer data
      productData['producerName'] = producerData?['name'];
      productData['producerImageUrl'] = producerData?['profilePictureUrl'];

      productList.add(productData);
    }

    return productList;
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            var productsList = snapshot.data!;
            return ListView.builder(
              itemCount: productsList.length,
              itemBuilder: (context, index) {
                var product = productsList[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(productData: product),
                      ),
                    );
                  },
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                                (product['producerImageUrl'] != null && product['producerImageUrl'].isNotEmpty)
                                    ? product['producerImageUrl']
                                    : 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/default_profile_pic.png?alt=media&token=549eda7d-a11f-4a30-9b4f-ddebd15b8d48'
                            ),
                          ),
                          title: Text(product['producerName'] ?? 'Unknown Producer'),
                          subtitle: Text(product['name']),
                          trailing: Text('€${product['price'].toStringAsFixed(2)}/kg'),
                        ),
                        Image.network(
                          product['imageUrl'] ?? 'https://via.placeholder.com/150',
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ],
                    ),
                  ),
                );
              },

            );

          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),


    );
  }
}



class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
  static const String routeName = '/cart';
}

class _CartScreenState extends State<CartScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  late Future<List<CartItemModel>> cartItems;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      cartItems = getCartItems(user!.uid);
    }
  }



  int _parseToInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value) ?? 0;
    } else {
      return 0;
    }
  }

  double _parseToDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  Future<void> _updateCartItemQuantity(CartItemModel item, double newQuantity) async {
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('carts').doc(user!.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      List items = snapshot.data()!['items'];
      int index = items.indexWhere((itemData) => itemData['productId'] == item.productId);

      if (index != -1) {
        setState(() {
          item.quantityInKgs = newQuantity;
        });

        items[index]['quantityInKgs'] = newQuantity;
        await docRef.update({'items': items});
      }
    }
  }

  Future<void> _removeCartItem(CartItemModel item) async {
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('carts').doc(user!.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      List items = snapshot.data()!['items'];
      items.removeWhere((itemData) => itemData['productId'] == item.productId);

      await docRef.update({'items': items});

      // Update the UI
      setState(() {
        cartItems = getCartItems(user!.uid);
      });
    }
  }

  Future<List<CartItemModel>> getCartItems(String userId) async {
    var cartSnapshot = await FirebaseFirestore.instance.collection('carts').doc(userId).get();
    if (cartSnapshot.data() == null) return [];

    List items = cartSnapshot.data()!['items'];
    List<CartItemModel> cartItems = [];

    for (var item in items) {
      var productSnapshot = await FirebaseFirestore.instance.collection('products').doc(item['productId']).get();
      var productData = productSnapshot.data();

      if (productData != null) {
        double quantityInKgs = item['quantityInKgs'] != null ? _parseToDouble(item['quantityInKgs']) : 0.0;
        cartItems.add(CartItemModel(
          productId: item['productId'],
          quantityInKgs: quantityInKgs,
          name: productData['name'],
          price: _parseToDouble(productData['price']),
          imageUrl: productData['imageUrl'],
        ));
      }
    }

    return cartItems;
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Your Cart"),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: FutureBuilder<List<CartItemModel>>(
          future: cartItems,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error loading cart items"));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, size: 50, color: Colors.grey),
                    SizedBox(height: 20),
                    Text("Your cart is empty", style: TextStyle(fontSize: 20)),
                  ],
                ),
              );
            }
            final items = snapshot.data!;
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => CartItemWidget(
                      item: items[index],
                      updateQuantity: _updateCartItemQuantity,
                      removeQuantity: _removeCartItem,
                    ),
                  ),
                ),
                _buildCartSummary(items),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),
    );
  }


  Widget _buildCartSummary(List<CartItemModel> items) {
    double total = items.fold(0, (sum, item) => sum + (item.price * item.quantityInKgs));
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Items: ${items.length}", style: TextStyle(fontSize: 16)),
              SizedBox(height: 4),
              Text("Total: €${total.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton(
            onPressed: () async {
              bool result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CheckoutScreen(cartItems: items)),
              ) ?? false;

              if (result) {
                setState(() {
                  // Reset the cart items
                  cartItems = getCartItems(user!.uid);
                });
              }
            },
            child: Text('Checkout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          )

        ],
      ),
    );
  }

}

class CartItemModel {
  final String productId;
  final String name;
  final String imageUrl;
  final double price;
  double quantityInKgs;

  CartItemModel({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    double? quantityInKgs,
  }) : quantityInKgs = quantityInKgs ?? 0.0;
}




class CartItemWidget extends StatefulWidget {
  final CartItemModel item;
  final Function(CartItemModel, double) updateQuantity;
  final Function(CartItemModel) removeQuantity;

  CartItemWidget({
    required this.item,
    required this.updateQuantity,
    required this.removeQuantity,
  });

  @override
  _CartItemWidgetState createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  @override
  Widget build(BuildContext context) {
    double totalPrice = widget.item.price * widget.item.quantityInKgs;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                widget.item.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '€${widget.item.price.toStringAsFixed(2)} per kg',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.remove, color: Theme.of(context).primaryColor),
              onPressed: () {
                if (widget.item.quantityInKgs > 0.5) {
                  setState(() {
                    widget.item.quantityInKgs -= 0.5;
                    totalPrice = widget.item.price * widget.item.quantityInKgs;
                  });
                  widget.updateQuantity(widget.item, widget.item.quantityInKgs);
                }
              },
            ),
            Text('${widget.item.quantityInKgs.toStringAsFixed(2)} kg'),
            IconButton(
              icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
              onPressed: () {
                setState(() {
                  widget.item.quantityInKgs += 0.5;
                  totalPrice = widget.item.price * widget.item.quantityInKgs;
                });
                widget.updateQuantity(widget.item, widget.item.quantityInKgs);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                widget.removeQuantity(widget.item);
              },
            ),
          ],
        ),
      ),
    );
  }
}



class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel> cartItems;

  const CheckoutScreen({Key? key, required this.cartItems}) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _detailsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _selectedIndex = 2;

  Future<void> _submitOrder(List<CartItemModel> cartItems, String address, String details, String phoneNum) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }

    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantityInKgs));

    final orderData = {
      'userId': user.uid,
      'amount': totalAmount,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'deliveryAddress': address,
      'deliveryDetails': details,
      'phoneNum': int.tryParse(phoneNum)
    };

    final orderRef = await FirebaseFirestore.instance.collection('orders').add(orderData);

    for (var cartItem in cartItems) {
      await FirebaseFirestore.instance.collection('orderItems').add({
        'orderId': orderRef.id,
        'productId': cartItem.productId,
        'quantity': cartItem.quantityInKgs,
        'price': cartItem.price,
      });
    }

    await FirebaseFirestore.instance.collection('carts').doc(user.uid).set({'items': []});

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
              Text("Order placed successfully!"),
            ],
          ),
        );
      },
    );

    Future.delayed(Duration(seconds: 2), () {
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    });
  }

  Future<void> _placeOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final address = _addressController.text.trim();
      final details = _detailsController.text.trim();
      final phoneNum = _phoneController.text.trim();
      await _submitOrder(widget.cartItems, address, details, phoneNum);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = widget.cartItems.fold(0, (sum, item) => sum + (item.price * item.quantityInKgs));

    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.cartItems.length,
                itemBuilder: (context, index) {
                  final item = widget.cartItems[index];
                  return ListTile(
                    leading: Image.network(item.imageUrl, width: 50, height: 50),
                    title: Text(item.name),
                    subtitle: Text('Quantity: ${item.quantityInKgs} kg'),
                    trailing: Text('€${(item.price * item.quantityInKgs).toStringAsFixed(2)}'),
                  );
                },
              ),
              Divider(),
              Text(
                'Total: €${total.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Delivery Address',
                  hintText: '123 Example St, City, Country',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _detailsController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Delivery Details',
                  hintText: 'e.g., Delivery after 5 p.m, Do not ring bell',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter delivery details';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g., 99385571, 24639583',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  // Validation for Cypriot phone numbers (8 digits)
                  if (!RegExp(r'^\d{8}$').hasMatch(value)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _placeOrder,
                child: Text('Place Order'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),
    );
  }
}



class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailScreen({Key? key, required this.productData}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final TextEditingController _weightController = TextEditingController(text: '0.5');
  final FocusNode _weightFocus = FocusNode();
  List<Map<String, dynamic>> reviews = [];
  String _producerName = '';
  String _producerProfilePictureUrl = '';
  int _selectedIndex = 0;


  @override
  void initState() {
    super.initState();
    fetchReviews();
    fetchProducerDetails();
    _weightController.addListener(onWeightChanged);
  }


  void incrementWeight() {
    double currentWeight = double.tryParse(_weightController.text) ?? 0.5;
    setState(() {
      currentWeight += 0.25;
      _weightController.text = currentWeight.toStringAsFixed(2);
    });
  }

  void decrementWeight() {
    double currentWeight = double.tryParse(_weightController.text) ?? 0.5;
    if (currentWeight > 0.5) {
      setState(() {
        currentWeight -= 0.25;
        if (currentWeight < 0.5) {
          currentWeight = 0.5;
        }
        _weightController.text = currentWeight.toStringAsFixed(2);
      });
    }
  }
  void enforceMinimumValue() {
    double currentWeight = double.tryParse(_weightController.text) ?? 0;
    if (currentWeight < 0.5) {
      setState(() {
        _weightController.text = '0.5';
        _weightController.selection = TextSelection.fromPosition(TextPosition(offset: _weightController.text.length));
      });
    }
  }

  void onWeightChanged() {
  }

  Future<bool> addProducerReview(int rating, String comment) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        print("User is not logged in.");
        return false;
      }

      String producerId = widget.productData['producerId'];
      String productId = widget.productData['id'];

      await FirebaseFirestore.instance.collection('reviews').add({
        'userId': userId,
        'producerId': producerId,
        // 'productId': productId,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error adding review: $e');
      return false;
    }
  }


  void showReviewDialog(BuildContext context) {
    final TextEditingController commentController = TextEditingController();
    int tempRating = 0; // Rating before submission

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Review'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Rating:'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < tempRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setState(() => tempRating = index + 1);
                          },
                        );
                      }),
                    ),
                    TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Enter your comment here',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Submit'),
                  onPressed: () async {
                    bool success = await addProducerReview(tempRating, commentController.text);
                    Navigator.of(context).pop();

                    if (success) {
                      final snackBar = SnackBar(
                        content: Text('Review added successfully'),
                        behavior: SnackBarBehavior.fixed,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      // Refresh the reviews
                      await fetchReviews();
                    } else {
                      final snackBar = SnackBar(
                        content: Text('Failed to add review'),
                        behavior: SnackBarBehavior.fixed,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> fetchProducerDetails() async {
    String producerId = widget.productData['producerId'];
    var producerSnapshot = await FirebaseFirestore.instance.collection('users').doc(producerId).get();

    if (producerSnapshot.exists) {
      var producerData = producerSnapshot.data();
      setState(() {
        _producerName = producerData?['name'] ?? 'Unknown Producer';
        _producerProfilePictureUrl = producerData?['profilePictureUrl'] ?? 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/default_profile_pic.png?alt=media&token=549eda7d-a11f-4a30-9b4f-ddebd15b8d48';
      });
    }
  }


  Future<void> fetchReviews() async {
    try {
      String producerId = widget.productData['producerId'];

      var reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('producerId', isEqualTo: producerId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> fetchedReviews = [];

      for (var doc in reviewsSnapshot.docs) {
        var data = doc.data();

        // Fetch user details based on userId in review
        var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(data['userId']).get();
        var userData = userSnapshot.data() ?? {};

        fetchedReviews.add({
          'author': userData['name'] ?? 'Unknown',
          'comment': data['comment'],
          'rating': data['rating'],
        });
      }

      setState(() {
        reviews = fetchedReviews;
      });
    } catch (e) {
      print('Error fetching reviews: $e');
    }
  }

  Future<void> showSuccessDialog() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Do not dismiss the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Added to Cart'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    // Wait for a few seconds and then close the dialog and navigate back
    await Future.delayed(const Duration(seconds: 1));
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }


  void addToCart() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        print("user is not logged in");
        return;
      }

      double weightToAdd = double.tryParse(_weightController.text) ?? 0;
      if (weightToAdd <= 0) {
        print("invalid input");
        return;
      }

      String productId = widget.productData['id'];
      var cartDoc = FirebaseFirestore.instance.collection('carts').doc(userId);
      var cartSnapshot = await cartDoc.get();

      if (cartSnapshot.exists) {
        var cartData = cartSnapshot.data();
        List items = cartData?['items'] ?? [];

        var existingItemIndex = items.indexWhere((item) => item['productId'] == productId);

        if (existingItemIndex != -1) {
          // If the product already exists in the cart, increase the quantity
          double currentWeight = items[existingItemIndex]['quantityInKgs'] as double;
          items[existingItemIndex]['quantityInKgs'] = currentWeight + weightToAdd;
        } else {
          // If not, add the new item
          items.add({
            'productId': productId,
            'quantityInKgs': weightToAdd,
          });
        }

        // Update the cart
        await cartDoc.update({'items': items});
      } else {
        // Create a new cart if it doesn't exist
        await cartDoc.set({
          'userId': userId,
          'items': [{
            'productId': productId,
            'quantityInKgs': weightToAdd,
          }],
        });
      }
      await showSuccessDialog();
    } catch (e) {
      print('Error adding to cart: $e');
    }
  }



  @override
  void dispose() {
    _weightController.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  Widget buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating ? Colors.amber : Colors.grey,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final product = widget.productData;

    return Scaffold(
      appBar: AppBar(
        title: Text(product['name'], style: TextStyle(color: theme.primaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: IconThemeData(color: theme.primaryColor),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              child: Image.network(
                product['imageUrl'],
                fit: BoxFit.cover,
                height: 250,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _producerProfilePictureUrl.isNotEmpty
                        ? NetworkImage(_producerProfilePictureUrl)
                        : null,
                    radius: 30,
                    backgroundColor: Colors.grey,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _producerName,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'], style: theme.textTheme.headline5?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('€${product['price']}/kg', style: theme.textTheme.subtitle1?.copyWith(color: Colors.grey[600])),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Weight (kg)', style: theme.textTheme.subtitle1),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove, color: theme.primaryColor),
                        onPressed: decrementWeight,
                      ),
                      Container(
                        width: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5.0),
                          border: Border.all(color: theme.primaryColor),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${_weightController.text} kg',
                          style: theme.textTheme.subtitle1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: theme.primaryColor),
                        onPressed: incrementWeight,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: addToCart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('Add to cart', style: TextStyle(fontSize: 18)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text('Producer Reviews', style: theme.textTheme.headline6),
                  ...reviews.map((review) => Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ListTile(
                      title: Text(
                        review['author'],
                        style: theme.textTheme.subtitle1?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            review['comment'],
                            style: theme.textTheme.bodyText2,
                          ),
                          SizedBox(height: 4),
                          buildStarRating(review['rating']),
                        ],
                      ),
                    ),
                  )),
                  if (reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text("No reviews yet", style: theme.textTheme.subtitle1)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        context: context,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showReviewDialog(context),
        tooltip: 'Add Review',
        child: Icon(Icons.add_comment),
      ),

    );
  }


}

// Producer app screens:

class ProducerHomeScreen extends StatefulWidget {
  @override
  _ProducerHomeScreenState createState() => _ProducerHomeScreenState();
}

class _ProducerHomeScreenState extends State<ProducerHomeScreen> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> reviews = [];
  String producerName = '';
  String producerId = '';

  bool _isOrdersExpanded = false; // To track expansion state

  @override
  void initState() {
    super.initState();
    fetchProducerName();
    fetchProducts();
    fetchOrders();
    fetchReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Producer Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Hello $producerName!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            _manageProductsSection(),
            Divider(),
            _viewOrdersSection(),
            Divider(),
            _reviewsSection(),
          ],
        ),
      ),
    );
  }


  Widget _manageProductsSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manage Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              IconButton(
                icon: Icon(Icons.add, color: Colors.deepPurple),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddProductScreen()),
                  );
                  if (result == true) {
                    fetchProducts();
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          products.isNotEmpty
              ? ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              var product = products[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: Image.network(product['imageUrl'], width: 100, height: 100, fit: BoxFit.cover),
                  title: Text(product['name'], style: TextStyle(color: Colors.deepPurple)),
                  subtitle: Text('Price: \n${product['price'].toStringAsFixed(2)}€/kg', style: TextStyle(color: Colors.black54)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.orange),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EditProductScreen(product: product)),
                          );
                          if (result == true) {
                            fetchProducts(); // Refresh the products list
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteProduct(product['productId']),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
              : Center(child: Text("No products found.", style: TextStyle(color: Colors.deepPurple))),
        ],
      ),
    );
  }



  Widget _viewOrdersSection() {
    int displayCount = _isOrdersExpanded ? orders.length : min(orders.length, 4);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          SizedBox(height: 10),
          orders.isNotEmpty
              ? Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: displayCount,
                itemBuilder: (context, index) {
                  var order = orders[index];
                  return Card(
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text('Order ID: ${order['orderId']}', style: TextStyle(color: Colors.deepPurple)),
                      subtitle: Text('Total amount: \€${double.parse(order['amount'].toString()).toStringAsFixed(2)}\nPlaced on: ${order['createdAt']}', style: TextStyle(color: Colors.black54)),
                      trailing: Icon(Icons.arrow_forward, color: Colors.deepPurple),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProducerOrderDetailsScreen(orderId: order['orderId'], producerId: producerId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              if (orders.length > 4) // Show the button only if there are more than 4 orders
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isOrdersExpanded = !_isOrdersExpanded; // Toggle the expansion state
                    });
                  },
                  child: Text(_isOrdersExpanded ? 'Show less' : 'Show more'), // Change button text based on state
                ),
            ],
          )
              : Center(child: Text("No orders found.", style: TextStyle(color: Colors.deepPurple))),
        ],
      ),
    );
  }





  Widget _reviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          SizedBox(height: 10),
          reviews.isNotEmpty
              ? ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              var review = reviews[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                        review['userProfilePictureUrl'].isEmpty
                            ? 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/default_profile_pic.png?alt=media&token=549eda7d-a11f-4a30-9b4f-ddebd15b8d48'
                            : review['userProfilePictureUrl']
                    ),
                  ),
                  title: Text(review['userName'] ?? 'Anonymous', style: TextStyle(color: Colors.deepPurple)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review['comment'] ?? 'No comment', style: TextStyle(color: Colors.black54)),
                      SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            starIndex < review['rating'] ? Icons.star : Icons.star_border,
                            size: 20,
                            color: starIndex < review['rating'] ? Colors.amber : Colors.grey,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
              : Center(child: Text("No reviews found.", style: TextStyle(color: Colors.deepPurple))),
        ],
      ),
    );
  }


  void deleteProduct(String productId) async {
    // Show a confirmation
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false; // If the dialog is -> Cancel

    // If the user confirmed, delete the product
    if (confirmDelete) {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      setState(() {
        products.removeWhere((product) => product['productId'] == productId);
      });
    }
  }


  void fetchProducerName() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      var userData = userDoc.data();
      if (userData != null && userData.containsKey('name')) {
        setState(() {
          producerName = userData['name'];
          producerId = currentUser.uid;
        });
      }
    }
  }

  void fetchProducts() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String producerId = currentUser.uid;

      FirebaseFirestore.instance
          .collection('products')
          .where('producerId', isEqualTo: producerId)
          .get()
          .then((QuerySnapshot querySnapshot) {
        List<Map<String, dynamic>> fetchedProducts = [];
        for (var doc in querySnapshot.docs) {
          Map<String, dynamic> product = doc.data() as Map<String, dynamic>;
          product['productId'] = doc.id;
          fetchedProducts.add(product);
        }
        setState(() {
          products = fetchedProducts;
        });
      });
    }
  }


  void fetchOrders() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String producerId = currentUser.uid;

      // Fetch all products belonging to the producer
      var productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('producerId', isEqualTo: producerId)
          .get();

      var productIds = productsSnapshot.docs.map((doc) => doc.id).toList();

      // Fetch all order items that have a productId in the productIds list
      var allOrderItems = await FirebaseFirestore.instance
          .collection('orderItems')
          .where('productId', whereIn: productIds)
          .get();

      var orderIds = allOrderItems.docs.map((doc) => doc.data()['orderId'] as String).toSet().toList();

      // Fetch all orders using the orderIds
      List<Map<String, dynamic>> fetchedOrders = [];
      for (String orderId in orderIds) {
        var orderSnapshot = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
        if (orderSnapshot.exists) {
          Map<String, dynamic> order = orderSnapshot.data()!;
          order['orderId'] = orderSnapshot.id; // Include the order ID in the order data
          // Include the createdAt field to display the date
          // Format the createdAt field to exclude seconds
          DateTime createdAtDate = orderSnapshot.data()!['createdAt']?.toDate() ?? DateTime.now();
          String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(createdAtDate);
          order['createdAt'] = formattedDate;
          fetchedOrders.add(order);
        }
      }

      // Sort the orders from most recent to oldest
      fetchedOrders.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

      setState(() {
        orders = fetchedOrders;
      });
    }
  }






  void fetchReviews() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String producerId = currentUser.uid;

      FirebaseFirestore.instance
          .collection('reviews')
          .where('producerId', isEqualTo: producerId)
          .get()
          .then((QuerySnapshot querySnapshot) async {
        List<Map<String, dynamic>> fetchedReviews = [];
        for (var doc in querySnapshot.docs) {
          Map<String, dynamic> review = doc.data() as Map<String, dynamic>;
          String userId = review['userId'];

          // Fetch user details for each review
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          var userData = userDoc.data();
          print(userData);
          // Add user details to the review data
          review['userName'] = userData?['name'] ?? 'Anonymous';
          review['userProfilePictureUrl'] = userData?['profilePictureUrl'] ?? 'https://cdn-icons-png.flaticon.com/512/6522/6522516.png';

          fetchedReviews.add(review);
        }

        setState(() {
          reviews = fetchedReviews;
        });
      }).catchError((error) {
        print('Error fetching reviews: $error');
      });
    }
  }


}

class ProducerOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String producerId;

  ProducerOrderDetailsScreen({Key? key, required this.orderId, required this.producerId}) : super(key: key);

  @override
  _ProducerOrderDetailsScreenState createState() => _ProducerOrderDetailsScreenState();
}

class _ProducerOrderDetailsScreenState extends State<ProducerOrderDetailsScreen> {
  Map<String, dynamic>? orderDetails;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> orderItems = [];
  List<Map<String, dynamic>> productDetails = [];

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  double getTotalAmountForProducer() {
    double total = 0.0;
    for (int i = 0; i < orderItems.length; i++) {
      total += orderItems[i]['quantity'] * orderItems[i]['price'];
    }
    return total;
  }

  fetchOrderDetails() async {
    // Fetch order details
    var orderSnapshot = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    if (orderSnapshot.exists) {
      orderDetails = orderSnapshot.data();
      setState(() {});

      // Fetch user data
      var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(orderDetails!['userId']).get();
      if (userSnapshot.exists) {
        userData = userSnapshot.data();
        setState(() {});
      }

      // Fetch order items
      var orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('orderItems')
          .where('orderId', isEqualTo: widget.orderId)
          .get();

      List<Map<String, dynamic>> tempOrderItems = orderItemsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      List<Map<String, dynamic>> filteredOrderItems = [];

      // Check each order item's product for the producerId
      for (var item in tempOrderItems) {
        var productSnapshot = await FirebaseFirestore.instance.collection('products').doc(item['productId']).get();
        if (productSnapshot.exists) {
          var productData = productSnapshot.data() as Map<String, dynamic>;
          if (productData['producerId'] == widget.producerId) {
            filteredOrderItems.add(item);
            productDetails.add(productData); // Add product details for matching items
          }
        }
      }

      // Update the state with the filtered order items and their product details
      setState(() {
        orderItems = filteredOrderItems;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Calculate the total for the items requested from the producer
    double totalProducerItems = orderItems.fold(0, (previousValue, element) => previousValue + (element['quantity'] * element['price']));

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details'),
        elevation: 4.0,
        backgroundColor: Colors.deepPurple,
      ),
      body: orderDetails == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Order ID: ${widget.orderId}',
                        style: TextStyle(fontSize: 20, color: Colors.deepPurple),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text('Total Amount: ${orderDetails!['amount']}€', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      SizedBox(height: 5),
                      Text('Status: ${orderDetails!['status']}', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      SizedBox(height: 5),
                      Text('Delivery Address: ${orderDetails!['deliveryAddress']}', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      SizedBox(height: 5),
                      Text('Phone Number: ${orderDetails!['phoneNum'] ?? 'N/A'}', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                    ],
                  ),
                ),
              ),
              Divider(thickness: 2, height: 32, color: Colors.grey.shade400),
              Text('Customer Details', style: Theme.of(context).textTheme.headline5?.copyWith(color: Colors.deepPurple)),
              SizedBox(height: 8),
              _buildDetailItem('Name: ${userData?['name'] ?? 'N/A'}'),
              _buildDetailItem('Email: ${userData?['email'] ?? 'N/A'}'),
              Divider(thickness: 2, height: 32, color: Colors.grey.shade400),
              Text('Order items requested from you', style: Theme.of(context).textTheme.headline5?.copyWith(color: Colors.deepPurple)),
              ..._buildOrderItems(),
              // Display the total for the producer's items
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Amount you should collect: ${totalProducerItems.toStringAsFixed(2)}€',
                  style: TextStyle(fontSize: 20, color: Colors.deepPurple, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildDetailItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: TextStyle(fontSize: 16, color: Colors.black87)),
  );

  List<Widget> _buildOrderItems() => orderItems.asMap().map((index, item) {
    final product = productDetails.isNotEmpty ? productDetails[index] : null;
    return MapEntry(
      index,
      Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          title: Text(
            product != null ? product['name'] : 'Product',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          subtitle: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black54),
              children: <TextSpan>[
                TextSpan(text: 'Quantity: ${item['quantity']} kgs\n'),
                TextSpan(text: 'Price at time of order: ${item['price']}€ / kg\n'),
                TextSpan(
                  text: 'Final Price: ${item['quantity'] * item['price']}€',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }).values.toList();
}


class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String description = '';
  double price = 0.0;
  String category = '';
  bool newFlag = false;
  bool _isLoading = false;
  File? _image;



  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    // Use the ImagePicker to pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path); // Update the _image File with the picked file
      });
    } else {
      print("No image selected");
    }
  }

  Future<String?> _uploadProductImage(User currentUser) async {
    // If no image is picked, return default image URL
    if (_image == null) {
      return 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/products%2Fdefault_product_image.png?alt=media&token=a6b9c257-dce9-4402-9a98-efe63198c9d8';
    }

    String fileName = 'products/${currentUser.uid}/${Path.basename(_image!.path)}';
    FirebaseStorage storage = FirebaseStorage.instance;

    try {
      TaskSnapshot uploadTask = await storage.ref(fileName).putFile(_image!);
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading product image: $e");
      // In case of error, return the default image URL
      return 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/products%2Fdefault_product_image.png?alt=media&token=a6b9c257-dce9-4402-9a98-efe63198c9d8';
    }
  }

  Future<void> _addProduct(String imageUrl) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection('products').add({
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'newFlag': newFlag,
      'producerId': currentUser.uid,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Product'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(12.0),
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Product Name',
                prefixIcon: Icon(Icons.edit_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
              validator: (value) => value!.isEmpty ? 'Please enter the product name' : null,
              onSaved: (value) => name = value ?? '',
            ),
            SizedBox(height: 15),

            TextFormField(
              decoration: InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
              validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              onSaved: (value) => description = value ?? '',
            ),
            SizedBox(height: 15),

            TextFormField(
              decoration: InputDecoration(
                labelText: 'Price',
                prefixIcon: Icon(Icons.euro),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              onSaved: (value) => price = double.tryParse(value!) ?? 0.0,
            ),
            SizedBox(height: 15),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
              validator: (value) => value!.isEmpty ? 'Please enter a category' : null,
              onSaved: (value) => category = value ?? '',
            ),
            SizedBox(height: 15),
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.deepPurple, width: 2),
              ),
              child: InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _image != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.file(_image!, width: 100, height: 100, fit: BoxFit.cover),
                      )
                          : Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.grey[300],
                        ),
                        child: Icon(Icons.camera_alt, size: 50, color: Colors.deepPurple),
                      ),
                      SizedBox(width: 20),
                      Text(
                        'Tap to select product image',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true; // Start loading
                });

                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  String imageUrl = _image == null
                      ? 'https://firebasestorage.googleapis.com/v0/b/earthy-72f98.appspot.com/o/products%2Fdefault_product_image.png?alt=media&token=a6b9c257-dce9-4402-9a98-efe63198c9d8'
                      : await _uploadProductImage(FirebaseAuth.instance.currentUser!) ?? '';

                  if (imageUrl.isNotEmpty) {
                    await _addProduct(imageUrl);
                    Navigator.pop(context, true); // Return true if the product was added
                  } else {
                    if (_image != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image')));
                    }
                  }
                }

                setState(() {
                  _isLoading = false; // End loading
                });
              },
              child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('Add Product', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white, // Text color
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}


class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = false;
  User? currentUser = FirebaseAuth.instance.currentUser;
  File? _image;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _loadNotificationSetting();
    }
  }

  Future<void> _loadNotificationSetting() async {
    if (currentUser == null) return;
    try {
      var settingsDoc = await FirebaseFirestore.instance.collection('settings').doc(currentUser!.uid).get();
      if (settingsDoc.exists) {
        setState(() {
          notificationsEnabled = settingsDoc.data()?['notifications'] ?? false;
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('settings').doc(currentUser!.uid).set({
        'notifications': value,
      }, SetOptions(merge: true));
      setState(() {
        notificationsEnabled = value;
      });
    } catch (e) {
      print("Error updating settings: $e");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    // Pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path); // Update the _image File with the picked file
      });
    } else {
      print("No image selected");
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_image == null || currentUser == null) return;
    String fileName = Path.basename(_image!.path);
    FirebaseStorage storage = FirebaseStorage.instance;

    try {
      TaskSnapshot uploadTask = await storage.ref('profilePictures/${currentUser!.uid}/$fileName').putFile(_image!);
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({'profilePictureUrl': downloadUrl});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile picture updated successfully')));
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile picture')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: _image != null ? Image.file(_image!, width: 100, height: 100) : Icon(Icons.image),
            title: Text('Change Profile Picture'),
            onTap: () async {
              await _pickImage();
              if (_image != null) {
                await _uploadProfilePicture();
              }
            },
          ),
          SwitchListTile(
            title: Text('Enable Notifications'),
            value: notificationsEnabled,
            onChanged: (bool value) {
              _updateNotificationSetting(value);
            },
            secondary: Icon(
              notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => SignInScreen()),
                    (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}


class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  EditProductScreen({Key? key, required this.product}) : super(key: key);

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['name']);
    _descriptionController = TextEditingController(text: widget.product['description']);
    _priceController = TextEditingController(text: widget.product['price'].toString());
    _categoryController = TextEditingController(text: widget.product['category']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void saveProduct() async {
    if (_formKey.currentState!.validate()) {
      print(widget.product);
      print(widget.product['productId']);
      await FirebaseFirestore.instance.collection('products').doc(widget.product['productId']).update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'category': _categoryController.text.trim(),
      }).then((_) {
        Navigator.of(context).pop(true); // True -> success
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $error')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Product'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price per kg',
                  prefixIcon: Icon(Icons.euro),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: saveProduct,
                child: Text('Save Changes', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple, // Button color
                  foregroundColor: Colors.white, // Text color
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  OrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? orderDetails;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> orderItems = [];
  List<Map<String, dynamic>> productDetails = [];

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  fetchOrderDetails() async {
    // Fetch order details
    var orderSnapshot = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    if (orderSnapshot.exists) {
      orderDetails = orderSnapshot.data();
      setState(() {});

      // Fetch user data
      var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(orderDetails!['userId']).get();
      if (userSnapshot.exists) {
        userData = userSnapshot.data();
        setState(() {});
      }

      // Fetch order items
      var orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('orderItems')
          .where('orderId', isEqualTo: widget.orderId)
          .get();
      orderItems = orderItemsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Fetch product details for each order
      for (var item in orderItems) {
        var productSnapshot = await FirebaseFirestore.instance.collection('products').doc(item['productId']).get();
        if (productSnapshot.exists) {
          productDetails.add(productSnapshot.data() as Map<String, dynamic>);
        }
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details'),
        elevation: 4.0,
        backgroundColor: Colors.deepPurple,
      ),
      body: orderDetails == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Order ID: ${widget.orderId}',
                        style: TextStyle(fontSize: 20, color: Colors.deepPurple),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text('Total Amount: ${orderDetails!['amount']}€', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      SizedBox(height: 5),
                      Text('Status: ${orderDetails!['status']}', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      SizedBox(height: 5),
                      Text('Delivery Address: ${orderDetails!['deliveryAddress']}', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      SizedBox(height: 5),
                      Text('Phone Number: ${orderDetails!['phoneNum'] ?? 'N/A'}', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                    ],
                  ),
                ),
              ),
              Divider(thickness: 2, height: 32, color: Colors.grey.shade400),
              Text('Customer Details', style: Theme.of(context).textTheme.headline5?.copyWith(color: Colors.deepPurple)),
              SizedBox(height: 8),
              _buildDetailItem('Name: ${userData?['name'] ?? 'N/A'}'),
              _buildDetailItem('Email: ${userData?['email'] ?? 'N/A'}'),
              Divider(thickness: 2, height: 32, color: Colors.grey.shade400),
              Text('Order Items', style: Theme.of(context).textTheme.headline5?.copyWith(color: Colors.deepPurple)),
              ..._buildOrderItems(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: TextStyle(fontSize: 16, color: Colors.black87)),
  );

  List<Widget> _buildOrderItems() => orderItems.asMap().map((index, item) {
    final product = productDetails.isNotEmpty ? productDetails[index] : null;
    return MapEntry(
      index,
      Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          title: Text(
            product != null ? product['name'] : 'Product',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          subtitle: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black54),
              children: <TextSpan>[
                TextSpan(text: 'Quantity: ${item['quantity']} kgs\n'),
                TextSpan(text: 'Price at time of order: ${item['price']}€ / kg\n'),
                TextSpan(
                  text: 'Final Price: ${item['quantity'] * item['price']}€',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }).values.toList();
}


class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final BuildContext context;

  const CustomBottomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.context,
  }) : super(key: key);

  void _onItemTapped(int index) {
    final currentRoute = ModalRoute.of(context)!.settings.name;

    switch (index) {
      case 0:
        if (currentRoute != HomeScreen.routeName) {
          Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (route) => false);
        }
        break;
      case 1:
        if (currentRoute != OrdersScreen.routeName) {
          Navigator.pushNamedAndRemoveUntil(context, OrdersScreen.routeName, (route) => false);
        }
        break;
      case 2:
        if (currentRoute != CartScreen.routeName) {
          Navigator.pushNamedAndRemoveUntil(context, CartScreen.routeName, (route) => false);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Cart',
        ),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: Colors.amber[800],
      onTap: _onItemTapped,
    );
  }
}

