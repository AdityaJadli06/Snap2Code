import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Request permissions on first launch
  await _requestInitialPermissions();

  // Initialize cameras
  try {
    if (!kIsWeb) {
      _cameras = await availableCameras();
    } else {
      _cameras = [];
    }
  } catch (e) {
    _cameras = [];
    debugPrint('Error initializing cameras: $e');
  }

  // Check login status
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');

  bool isLoggedIn = false;

  if (token != null) {
    isLoggedIn = await ApiService.verifyToken(token);

    if (!isLoggedIn) {
      await prefs.clear();
    }
  }

  runApp(Snap2NotesApp(isLoggedIn: isLoggedIn));
  FlutterNativeSplash.remove();
}

Future<void> _requestInitialPermissions() async {
  if (kIsWeb) return;

  Map<Permission, PermissionStatus> statuses = await [
    Permission.camera,
    Permission.storage,
    // For Android 13+ support
    Permission.photos,
    Permission.videos,
  ].request();

  debugPrint("Permissions statuses: $statuses");
}

class Snap2NotesApp extends StatefulWidget {
  final bool isLoggedIn;
  const Snap2NotesApp({super.key, required this.isLoggedIn});

  @override
  State<Snap2NotesApp> createState() => _Snap2NotesAppState();
}

class _Snap2NotesAppState extends State<Snap2NotesApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snap2Notes',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: widget.isLoggedIn
          ? MainNavigationScreen(onThemeChanged: toggleTheme, currentThemeMode: _themeMode)
          : LoginScreen(onThemeChanged: toggleTheme, currentThemeMode: _themeMode),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode currentThemeMode;
  const LoginScreen({super.key, required this.onThemeChanged, required this.currentThemeMode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.loginUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result["status"] == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('token', result["data"]["token"]);
      await prefs.setString('email', result["data"]["email"]);
      await prefs.setString('name', result["data"]["name"]);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(
              onThemeChanged: widget.onThemeChanged,
              currentThemeMode: widget.currentThemeMode,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["data"]["message"])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.document_scanner_rounded, size: 80, color: Colors.indigo),
                const SizedBox(height: 24),
                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue to Snap2Notes',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForgotPasswordScreen(
                            onThemeChanged: widget.onThemeChanged,
                            currentThemeMode: widget.currentThemeMode,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignUpScreen(
                          onThemeChanged: widget.onThemeChanged,
                          currentThemeMode: widget.currentThemeMode,
                        ),
                      ),
                    );
                  },
                  child: const Text('Don\'t have an account? Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode currentThemeMode;
  const SignUpScreen({super.key, required this.onThemeChanged, required this.currentThemeMode});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.registerUser(
      email: _emailController.text.trim(),
      name: _nameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result["status"] == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('name', _nameController.text.trim());

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(
              onThemeChanged: widget.onThemeChanged,
              currentThemeMode: widget.currentThemeMode,
            ),
          ),
              (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["data"]["message"])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add_outlined, size: 80, color: Colors.indigo),
                const SizedBox(height: 24),
                const Text(
                  'Join Us',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode currentThemeMode;
  const ForgotPasswordScreen({super.key, required this.onThemeChanged, required this.currentThemeMode});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _isOtpVerified = false;

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO: Implement API call to send OTP
    await Future.delayed(const Duration(seconds: 2)); // Simulate network
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP sent to your email")),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the OTP")),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO: Implement API call to verify OTP
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    setState(() {
      _isLoading = false;
      _isOtpVerified = true;
    });
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO: Implement API call to reset password
    await Future.delayed(const Duration(seconds: 2)); // Simulate network
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset successfully. Please login.")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _isOtpVerified ? Icons.lock_reset_rounded : Icons.mark_email_read_outlined,
                  size: 80,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 24),
                Text(
                  _isOtpVerified ? 'Set New Password' : 'Reset Password',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                if (!_isOtpVerified) ...[
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading && !_otpSent
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_otpSent ? 'Resend OTP' : 'Send OTP'),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        prefixIcon: const Icon(Icons.security),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Next'),
                    ),
                  ],
                ] else ...[
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Reset Password'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode currentThemeMode;
  const MainNavigationScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();
  final GlobalKey<_LibraryScreenState> _libraryKey = GlobalKey<_LibraryScreenState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh the screen being switched to
    if (index == 0) {
      _homeKey.currentState?._loadDashboardData();
    } else if (index == 1) {
      _libraryKey.currentState?._loadItems();
    }
  }

  // Method to navigate to library and open a specific folder
  void navigateToFolder(String path) {
    setState(() {
      _selectedIndex = 1;
    });
    // Give time for the tab to switch then set the path
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _libraryKey.currentState?.openPath(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(key: _homeKey),
      LibraryScreen(key: _libraryKey),
      const SearchScreen(),
      ProfileSettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.currentThemeMode == ThemeMode.dark,
        currentThemeMode: widget.currentThemeMode,
      ),
    ];

    String title = 'Snap2Notes';
    if (_selectedIndex == 1) title = 'Library';
    if (_selectedIndex == 2) title = 'Search';
    if (_selectedIndex == 3) title = 'Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedIndex != 2)
            IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _selectedIndex = 2)
            ),
          if (_selectedIndex == 1)
            IconButton(icon: const Icon(Icons.sort), onPressed: () {}),
          if (_selectedIndex != 3)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScanScreen()),
        ),
        tooltip: 'Quick Scan',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.camera_alt, size: 30),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FileSystemEntity> _recentFiles = [];
  List<Directory> _folders = [];
  File? _lastEditedFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final snapPath = path.join(directory.path, "Snap2notes");
      final snapDir = Directory(snapPath);

      if (!await snapDir.exists()) {
        await snapDir.create(recursive: true);
      }

      // Check if directory exists before listing
      if (await snapDir.exists()) {
        final allItems = snapDir.listSync(recursive: true);

        // Folders (Subjects)
        _folders = allItems
            .whereType<Directory>()
            .where((d) => d.existsSync() && path.dirname(d.path) == snapPath)
            .toList();

        // Files
        final files = allItems
            .whereType<File>()
            .where((f) => f.existsSync() && f.path.endsWith('.txt'))
            .toList();

        // Sort by last modified - wrap in try/catch for safety
        files.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });

        _recentFiles = files.take(5).toList();
        if (files.isNotEmpty) {
          _lastEditedFile = files.first;
        } else {
          _lastEditedFile = null;
        }
      }
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      _folders = [];
      _recentFiles = [];
      _lastEditedFile = null;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createFolder() async {
    String folderName = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Subject Folder'),
        content: TextField(
          onChanged: (value) => folderName = value,
          decoration: const InputDecoration(hintText: "Enter subject name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (folderName.isNotEmpty) {
                try {
                  final directory = await getApplicationDocumentsDirectory();
                  final snapPath = path.join(directory.path, "Snap2notes");
                  final snapDir = Directory(snapPath);

                  // Ensure parent Snap2notes exists first
                  if (!await snapDir.exists()) {
                    await snapDir.create(recursive: true);
                  }

                  final newDir = Directory(path.join(snapPath, folderName));
                  if (!await newDir.exists()) {
                    await newDir.create(recursive: true);
                    _loadDashboardData();
                  }
                } catch (e) {
                  debugPrint("Error creating folder: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanScreen()));
              _loadDashboardData();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.indigo.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.document_scanner_rounded, size: 50, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Quick Scan Board',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Convert board notes to text instantly',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_recentFiles.isNotEmpty) ...[
            _buildSectionHeader('Recent Notes', () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recentFiles.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildRecentNoteCard(context, _recentFiles[index]);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],

          _buildSectionHeader('Subjects / Folders', _createFolder, actionIcon: Icons.add),
          const SizedBox(height: 12),
          _folders.isEmpty
              ? Center(
                  child: TextButton.icon(
                    onPressed: _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text("Create your first subject folder"),
                  ),
                )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: _folders.length,
            itemBuilder: (context, index) {
              return _buildCategoryItem(_folders[index]);
            },
          ),
          const SizedBox(height: 32),

          if (_lastEditedFile != null) ...[
            _buildSectionHeader('Continue Editing', () {}),
            const SizedBox(height: 12),
            _buildContinueEditingCard(context, _lastEditedFile!),
          ],
          if (_recentFiles.isEmpty && _folders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text("No notes yet. Start scanning!", style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAction, {IconData? actionIcon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (actionIcon != null)
          IconButton(onPressed: onAction, icon: Icon(actionIcon, size: 20, color: Colors.indigo))
        else
          TextButton(onPressed: onAction, child: const Text('See All')),
      ],
    );
  }

  Widget _buildRecentNoteCard(BuildContext context, FileSystemEntity file) {
    final fileName = path.basename(file.path);
    final modified = (file as File).lastModifiedSync();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(
              fileName: fileName,
              extractedText: file.readAsStringSync(),
            ),
          ),
        );
        _loadDashboardData();
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.description_outlined, color: Colors.indigo.shade200, size: 40),
            ),
            const SizedBox(height: 8),
            Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${modified.day}/${modified.month}/${modified.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Directory folder) {
    return GestureDetector(
      onTap: () {
        // Find the main navigation state to trigger tab switch
        final navState = context.findAncestorStateOfType<_MainNavigationScreenState>();
        navState?.navigateToFolder(folder.path);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder, color: Colors.amber),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                path.basename(folder.path),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueEditingCard(BuildContext context, File file) {
    final fileName = path.basename(file.path);
    final modified = file.lastModifiedSync();
    final difference = DateTime.now().difference(modified);
    String timeAgo = "${difference.inMinutes} mins ago";
    if (difference.inHours > 0) timeAgo = "${difference.inHours} hours ago";
    if (difference.inDays > 0) timeAgo = "${difference.inDays} days ago";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.edit_note, color: Colors.indigo),
        ),
        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Last edited $timeAgo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditorScreen(
                fileName: fileName,
                extractedText: file.readAsStringSync(),
              ),
            ),
          );
          _loadDashboardData();
        },
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {



  CameraController? _controller;
  bool _isPermissionGranted = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0; // for smooth pinch
  bool _isInitializing = true;
  FlashMode _flashMode = FlashMode.off;
  int _cameraIndex = 0;
  bool _isAutoMode = true;
  final ImagePicker _picker = ImagePicker();

  List<String> extractTopics(String text) {
    final lines = text.split("\n");

    return lines
        .where((line) =>
    line.trim().isNotEmpty &&
        line.length > 5 &&
        line.length < 60)
        .take(3)
        .toList();
  }

// store multiple images
  List<String> capturedImages = [];
  //CropFunction
  Future<String?> cropImage(String path) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            hideBottomControls: false,

            // 🔥 ADD THESE
            cropFrameStrokeWidth: 2,
            cropGridStrokeWidth: 1,
            showCropGrid: true,
          ),
        ],
      );

      return croppedFile?.path;
    } catch (e) {
      debugPrint("Crop error: $e");
      return path;
    }
  }

  void _processImages() async {
    if (capturedImages.isEmpty) return;

    // 🔥 SHOW LOADING
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<String> processedImages = [];

    for (int i = 0; i < capturedImages.length; i++) {
      String path = capturedImages[i];

      final croppedPath = await cropImage(path);
      if (croppedPath != null) {
        processedImages.add(croppedPath);
      }
    }

    // 🔍 OCR IN PARALLEL (FAST)
    List<Future<String>> futures = processedImages
        .map((path) => extractTextFromImage(path))
        .toList();

    List<String> results = await Future.wait(futures);



    String finalText = '';

    for (int i = 0; i < results.length; i++) {
      finalText += "Image ${i + 1}:\n${results[i]}\n\n";
    }

    if (!mounted) return;

    Navigator.pop(context); // ❗ CLOSE LOADING

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          fileName: 'Scanned_$timestamp',
          imagePath: processedImages.isNotEmpty ? processedImages.last : null,
          extractedText: finalText,
        ),
      ),
    ).then((_) {
      // Refresh logic if needed, but usually handled by pop or the home screen refresh
    });

    capturedImages.clear();
  }
  Future<String> extractTextFromImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText =
    await textRecognizer.processImage(inputImage);

    String text = recognizedText.text;

    await textRecognizer.close();

    return text;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _isPermissionGranted = true;
      _initializeWebCamera();
    } else {
      _checkPermissionAndInitialize();
    }
  }

  Future<void> _initializeWebCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _initializeCameraController(cameras[0]);
      } else {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('Error initializing web camera: $e');
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
    }
  }

  Future<void> _checkPermissionAndInitialize() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
      if (_cameras.isNotEmpty) {
        _initializeCameraController(_cameras[0]);
      } else {
        setState(() => _isInitializing = false);
      }
    } else {
      setState(() {
        _isPermissionGranted = false;
        _isInitializing = false;
      });
      _requestPermission();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
        _isInitializing = true;
      });
      if (_cameras.isNotEmpty) {
        _initializeCameraController(_cameras[0]);
      } else {
        setState(() => _isInitializing = false);
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionSettingsDialog();
      }
    }
  }

  Future<void> _initializeCameraController(CameraDescription cameraDescription) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = cameraController;
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        debugPrint('Camera error ${cameraController.value.errorDescription}');
      }
    });
    try {
      await cameraController.initialize();
      _minZoom = await cameraController.getMinZoomLevel();
      _maxZoom = await cameraController.getMaxZoomLevel();
      _currentZoom = _minZoom;
    } on CameraException catch (e) {
      debugPrint('Camera exception $e');
    }
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('This app needs camera access to scan board notes. Please enable it in settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('SETTINGS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),

          /// 🔝 TOP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),

                  if (_isPermissionGranted &&
                      _controller != null &&
                      _controller!.value.isInitialized)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _setAutoMode,
                          icon: Icon(
                            Icons.hdr_auto,
                            color: _isAutoMode ? Colors.green : Colors.white,
                          ),
                          label: Text(
                            _isAutoMode ? 'AUTO' : 'MANUAL',
                            style: TextStyle(
                              color: _isAutoMode ? Colors.green : Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : Icons.flash_on,
                            color: _isAutoMode ? Colors.grey : Colors.white,
                          ),
                          onPressed: _isAutoMode ? null : _toggleFlash,
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          onPressed: _switchCamera,
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: _openSettings,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Count Text
          if (capturedImages.isNotEmpty)
            Positioned(
              bottom: 210,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "${capturedImages.length} images selected",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 160,
            left: 20,
            right: 20,
            child: Slider(
              value: _currentZoom,
              min: _minZoom,
              max: _maxZoom,
              activeColor: Colors.white,
              inactiveColor: Colors.grey,
              onChanged: (value) async {
                setState(() {
                  _currentZoom = value;
                });
                await _controller?.setZoomLevel(value);
              },
            ),
          ),

          //Thumbnail
          if (capturedImages.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: capturedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 70,
                          height: 90,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(capturedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        //Delete Button
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                capturedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          //Neeche ke Control
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [

                //Capture Button
                GestureDetector(
                  onTap: () => _takePicture(),
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

                //Galleryy
                Positioned(
                  left: 30,
                  child: IconButton(
                    icon: const Icon(Icons.photo_library,
                        color: Colors.white, size: 32),
                    onPressed: _pickMultipleImages,
                  ),
                ),

                //Next Button
                Positioned(
                  right: 30,
                  child: ElevatedButton(
                    onPressed:
                    capturedImages.isEmpty ? null : _processImages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        "Next",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!_isPermissionGranted) {
      return const Center(
        child: Text('No camera access', style: TextStyle(color: Colors.white)),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text('Camera error', style: TextStyle(color: Colors.white)),
      );
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover, // 🔥 KEY LINE
          child: SizedBox(
            width: _controller!.value.previewSize!.height,
            height: _controller!.value.previewSize!.width,
            child: GestureDetector(
              onScaleStart: (details) {
                _baseZoom = _currentZoom;
              },
              onScaleUpdate: (details) async {
                double zoom = _baseZoom + (details.scale - 1) * 1.5;
                zoom = zoom.clamp(_minZoom, _maxZoom);

                await _controller!.setZoomLevel(zoom);

                setState(() {
                  _currentZoom = zoom;
                });
              },
              child: CameraPreview(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  void _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_isAutoMode) {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      final image = await _controller!.takePicture();

      setState(() {
        capturedImages.add(image.path);
      });

    } catch (e) {
      debugPrint("Capture error: $e");
    } finally {
      await _controller?.setFlashMode(FlashMode.off);
    }
  }

  void _toggleFlash() async {
    if (_controller == null) return;

    if (_flashMode == FlashMode.off) {
      _flashMode = FlashMode.torch;
    } else {
      _flashMode = FlashMode.off;
    }

    await _controller!.setFlashMode(_flashMode);
    setState(() {});
  }

  void _setAutoMode() async {
    if (_controller == null) return;

    _flashMode = FlashMode.off;
    await _controller!.setFlashMode(_flashMode);

    setState(() {
      _isAutoMode = !_isAutoMode;
    });
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;

    _cameraIndex = (_cameraIndex + 1) % _cameras.length;

    await _controller?.dispose();
    _initializeCameraController(_cameras[_cameraIndex]);
  }

  void _pickMultipleImages() async {
    final images = await _picker.pickMultiImage();

    if (images.isNotEmpty && mounted) {
      for (var img in images) {
        capturedImages.add(img.path);
      }

      setState(() {});
    }
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Camera Settings'),
        content: const Text('You can add filters, grid, etc here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}



class EditorScreen extends StatefulWidget {
  final String? extractedText;
  final String fileName;
  final String? imagePath;
  final List<String>? videoLinks;

  const EditorScreen({
    super.key,
    required this.fileName,
    this.imagePath,
    this.extractedText,
    this.videoLinks,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {

  Future<void> _generateNotes() async {
    final rawText = _controller.text;

    if (rawText.trim().isEmpty) return;

    // 🔥 SHOW LOADING
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final notes = await ApiService.generateNotes(rawText);

    Navigator.pop(context); // close loading

    setState(() {
      _controller.text = notes;
    });
  }
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.extractedText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final directory = await getApplicationDocumentsDirectory();
              final snapPath = path.join(directory.path, "Snap2notes");
              final snapDir = Directory(snapPath);
              if (!await snapDir.exists()) {
                await snapDir.create(recursive: true);
              }

              // Load available folders
              List<Directory> folders = snapDir.listSync().whereType<Directory>().toList();

              if (!mounted) return;

              String selectedFolder = snapPath;

              await showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Save to Subject'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(
                                  title: const Text("Main Folder (Snap2notes)"),
                                  leading: Radio<String>(
                                    value: snapPath,
                                    groupValue: selectedFolder,
                                    onChanged: (val) => setDialogState(() => selectedFolder = val!),
                                  ),
                                ),
                                ...folders.map((folder) => ListTile(
                                  title: Text(path.basename(folder.path)),
                                  leading: Radio<String>(
                                    value: folder.path,
                                    groupValue: selectedFolder,
                                    onChanged: (val) => setDialogState(() => selectedFolder = val!),
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                            title: const Text("Create New Subject", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                            onTap: () async {
                              String newFolderName = "";
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('New Subject'),
                                  content: TextField(
                                    onChanged: (value) => newFolderName = value,
                                    decoration: const InputDecoration(hintText: "Enter subject name"),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () async {
                                        if (newFolderName.isNotEmpty) {
                                          final newDir = Directory(path.join(snapPath, newFolderName));
                                          if (!await newDir.exists()) {
                                            await newDir.create(recursive: true);
                                          }
                                          Navigator.pop(context);
                                          // Refresh the folder list in the parent dialog
                                          setDialogState(() {
                                            folders = snapDir.listSync().whereType<Directory>().toList();
                                            selectedFolder = newDir.path;
                                          });
                                        } else {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text('Create'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () async {
                          // Extract Topic Heading from # (First line starting with #)
                          String topicHeading = "";
                          final lines = _controller.text.split('\n');
                          for (var line in lines) {
                            if (line.trim().startsWith('#')) {
                              topicHeading = line.replaceAll('#', '').trim();
                              break;
                            }
                          }

                          if (topicHeading.isEmpty) {
                            topicHeading = widget.fileName;
                          }

                          // Clean filename (remove special chars)
                          topicHeading = topicHeading.replaceAll(RegExp(r'[^\w\s-]'), '');

                          String folderName = path.basename(selectedFolder);
                          if (folderName == "Snap2notes") folderName = "General";

                          final finalFileName = "${folderName}_$topicHeading.txt";

                          final filePath = path.join(selectedFolder, finalFileName);
                          final file = File(filePath);
                          await file.writeAsString(_controller.text);
                          Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Saved as $finalFileName")),
                            );
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /// IMAGE
          if (widget.imagePath != null)
            Expanded(
              flex: 1,
              child: Image.file(File(widget.imagePath!), fit: BoxFit.cover),
            ),

          /// TEXT
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Recognized text will appear here...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          ElevatedButton(
            onPressed: _generateNotes,
            child: const Text("Generate Notes"),
          ),


          /// VIDEOS
          if (widget.videoLinks != null && widget.videoLinks!.isNotEmpty)
            SizedBox(
              height: 150,
              child: ListView(
                children: widget.videoLinks!.map((link) {
                  return ListTile(
                    leading: const Icon(Icons.play_circle),
                    title: const Text("Watch Explanation"),
                    subtitle: Text(link),
                    onTap: () async {
                      final uri = Uri.parse(link);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<FileSystemEntity> _items = [];
  String _currentPath = "";
  bool _isLoading = true;

  void openPath(String path) {
    setState(() {
      _currentPath = path;
      _loadItems();
    });
  }

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    setState(() => _isLoading = true);
    final directory = await getApplicationDocumentsDirectory();
    final snapPath = path.join(directory.path, "Snap2notes");
    final snapDir = Directory(snapPath);
    if (!await snapDir.exists()) {
      await snapDir.create(recursive: true);
    }
    _currentPath = snapPath;
    _loadItems();
  }

  void _loadItems() {
    final dir = Directory(_currentPath);
    if (!dir.existsSync()) {
      setState(() {
        _items = [];
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _items = dir.listSync().toList();
      _isLoading = false;
    });
  }

  Future<void> _createFolder() async {
    String folderName = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          onChanged: (value) => folderName = value,
          decoration: const InputDecoration(hintText: "Enter folder name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (folderName.isNotEmpty) {
                final newDir = Directory(path.join(_currentPath, folderName));
                if (!await newDir.exists()) {
                  await newDir.create();
                  _loadItems();
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(FileSystemEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete ${path.basename(item.path)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      if (item is Directory) {
        await item.delete(recursive: true);
      } else {
        await item.delete();
      }
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          FutureBuilder<Directory>(
            future: getApplicationDocumentsDirectory(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final rootSnapPath = path.join(snapshot.data!.path, "Snap2notes");
              if (_currentPath != rootSnapPath) {
                return ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: const Text(".."),
                  onTap: () {
                    setState(() {
                      _currentPath = Directory(_currentPath).parent.path;
                      _loadItems();
                    });
                  },
                );
              }
              return const SizedBox();
            },
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text("Empty"))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isFolder = item is Directory;
                      return ListTile(
                        leading: Icon(
                          isFolder ? Icons.folder : Icons.insert_drive_file,
                          color: isFolder ? Colors.amber : Colors.blue,
                        ),
                        title: Text(path.basename(item.path)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteItem(item),
                        ),
                        onTap: () {
                          if (isFolder) {
                            setState(() {
                              _currentPath = item.path;
                              _loadItems();
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditorScreen(
                                  fileName: path.basename(item.path),
                                  extractedText: (item as File).readAsStringSync(),
                                ),
                              ),
                            ).then((_) => _loadItems());
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _createFolder,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            leading: const Icon(Icons.search),
            hintText: 'Search your notes...',
            onChanged: (value) {},
          ),
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No results found', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileSettingsScreen extends StatelessWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  final ThemeMode currentThemeMode;
  const ProfileSettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
    required this.currentThemeMode,
  });

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            onThemeChanged: onThemeChanged,
            currentThemeMode: currentThemeMode,
          ),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.edit, size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final prefs = snapshot.data!;
            final name = prefs.getString('name') ?? 'User';
            final email = prefs.getString('email') ?? '';

            return Center(
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 32),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Toggle app theme'),
          value: isDarkMode,
          onChanged: (value) {
            onThemeChanged(value);
          },
        ),
        _buildSettingsItem(Icons.notifications_outlined, 'Notifications'),
        _buildSettingsItem(Icons.security, 'Privacy & Security'),
        _buildSettingsItem(Icons.help_outline, 'Help & Support'),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _logout(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}