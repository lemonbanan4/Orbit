import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoadingGoogle = false;
  bool _isLoadingGuest = false;
  bool _isLoadingApple = false;
  bool _isLoadingEmail = false;
  bool _isLoadingReset = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _nameError;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final Map<String, String> _documentCache = {};
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showDocumentDialog('Terms of Service', 'https://gistcdn.githack.com/lemonbanan4/ca02585eabe38bde5c6513cf71c44f10/raw/d695d037b8dc54f002b5dcdbe256b6bf11373f69/terms_and_conditions.html');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showDocumentDialog('Privacy Policy', 'https://gistcdn.githack.com/lemonbanan4/f40ab2f143dcc1574afdb5f5a98289ed/raw/privacy_policy.html');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => messenger.hideCurrentSnackBar(),
          child: Row(
            children: [
              Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
        elevation: 10,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => messenger.hideCurrentSnackBar(),
          child: Row(
            children: [
              Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
        elevation: 10,
      ),
    );
  }

  void _launchURL(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar(context, 'Could not open link.');
    }
  }

  void _showDocumentDialog(String title, String url) async {
    // Show a loading indicator while fetching
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String content;
      // 1. Check the cache first
      if (_documentCache.containsKey(url)) {
        content = _documentCache[url]!;
      } else {
        // 2. If not cached, fetch from network with a timeout
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          content = response.body;
          _documentCache[url] = content; // 3. Store in cache for next time
        } else {
          if (!mounted) return;
          Navigator.pop(context); // Dismiss loading indicator
          _showErrorSnackBar(context, 'Could not load document.');
          return;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading indicator

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0A102A),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Html(
                data: content,
                onLinkTap: (tappedUrl, _, __) => _launchURL(tappedUrl),
                style: {
                  "body": Style(color: Colors.white70, fontSize: FontSize(15.0), margin: Margins.zero),
                  "h1": Style(color: Colors.white, fontSize: FontSize(22.0)),
                  "h2": Style(color: Colors.white, fontSize: FontSize(18.0)),
                  "h3": Style(color: Colors.white, fontSize: FontSize(16.0)),
                  "a": Style(color: const Color(0xFF00E5FF), textDecoration: TextDecoration.underline),
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading indicator
      _showErrorSnackBar(context, 'Could not load document. Check your internet connection.');
    }
  }

  Future<void> _performSignIn(
    Future<void> Function() signInMethod,
    String provider,
    void Function(bool) setLoading,
  ) async {
    HapticFeedback.mediumImpact();
    setLoading(true);
    try {
      await signInMethod();
    } catch (e, stackTrace) {
      if (!mounted) return;
      
      // Log the error securely to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Sign-in failed for $provider',
        fatal: false,
      );

      String errorMessage = 'Failed to sign in with $provider. Please try again.';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('network') || errorString.contains('internet')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('cancel')) {
        errorMessage = 'Sign-in was cancelled.';
      } else if (errorString.contains('account-exists-with-different-credential')) {
        errorMessage = 'An account already exists with the same email but different sign-in method.';
      }
      
      _showErrorSnackBar(context, errorMessage);
    } finally {
      if (mounted) setLoading(false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
  }

  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password needs at least one special character.';
    }
    return null; // Password is valid
  }

  bool _isValidName(String name) {
    return RegExp(r"^[a-zA-Z\s]+$").hasMatch(name);
  }

  void _handleEmailSignIn() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();

    String? emailErr;
    String? passwordErr;
    String? confirmPasswordErr;
    String? nameErr;
    bool hasError = false;

    if (!_isValidEmail(email)) {
      emailErr = 'Please enter a valid email address.';
      hasError = true;
    }

    if (_isSignUp) {
      if (name.isEmpty) {
        nameErr = 'Please enter your name.';
        hasError = true;
      } else if (!_isValidName(name)) {
        nameErr = 'Name can only contain letters and spaces.';
        hasError = true;
      }
      final passwordValidationError = _validatePassword(password);
      if (passwordValidationError != null) {
        passwordErr = passwordValidationError;
        hasError = true;
      }
      if (password != confirmPassword) {
        confirmPasswordErr = 'Passwords do not match.';
        hasError = true;
      }
    }

    // Batch all state changes into a single rebuild
    setState(() {
      _emailError = emailErr;
      _passwordError = passwordErr;
      _confirmPasswordError = confirmPasswordErr;
      _nameError = nameErr;
    });

    if (hasError) return;
    
    _performSignIn(
      () => _isSignUp
          ? context.read<AppAuthProvider>().createUserWithEmailAndPassword(email, password, name)
          : context.read<AppAuthProvider>().signInWithEmailAndPassword(email, password),
      _isSignUp ? 'Sign Up' : 'Email',
      (v) => setState(() => _isLoadingEmail = v),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Please enter a valid email to reset your password.');
      return;
    }
    
    setState(() {
      _emailError = null;
      _isLoadingReset = true;
    });

    try {
      await context.read<AppAuthProvider>().sendPasswordResetEmail(email);
      if (mounted) _showSuccessSnackBar(context, 'Password reset link sent to $email.');
    } catch (e) {
      if (mounted) _showErrorSnackBar(context, 'Failed to send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoadingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity, // Ensure the container fills the screen
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0A102A), Color(0xFF051024)],
          ),
        ),
        child: SafeArea(
          // 1. ADDED SINGLE CHILDS CROLL VIEW to fix the yellow overflow tape
          child: SingleChildScrollView(
            // physics: const BouncingScrollPhysics(), // Optional: adds a nice bounce effect
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- PREMIUM SAAS LOGO DISPLAY ---
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.4), 
                          blurRadius: 40, 
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .slideY(begin: -0.05, end: 0.05, duration: 2000.ms, curve: Curves.easeInOutSine),
                   
                  const SizedBox(height: 32),
                  const Text(
                    'Orbit',
                    style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Master your habits.\nCommand your day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
                  ),

                  const SizedBox(height: 48), // Replaced Spacer() with a fixed height

                  // APPLE LOGIN BUTTON
                  SocialAuthButton(
                    onPressed: _isLoadingGoogle || _isLoadingGuest || _isLoadingApple || _isLoadingEmail || _isLoadingReset || (_isSignUp && !_agreedToTerms) 
                        ? null 
                        : () => _performSignIn(context.read<AppAuthProvider>().signInWithApple, 'Apple', (v) => setState(() => _isLoadingApple = v)),
                    isLoading: _isLoadingApple,
                    text: 'Continue with Apple',
                    icon: const Icon(Icons.apple, size: 28, color: Colors.white),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    animationDelay: 200,
                  ),
                  const SizedBox(height: 16),

                  // GOOGLE LOGIN BUTTON
                  // 2. FIXED MISSING ASSET ERROR by swapping the image for a Material Icon
                  SocialAuthButton(
                    onPressed: _isLoadingGoogle || _isLoadingGuest || _isLoadingApple || _isLoadingEmail || _isLoadingReset || (_isSignUp && !_agreedToTerms) 
                        ? null 
                        : () => _performSignIn(context.read<AppAuthProvider>().signInWithGoogle, 'Google', (v) => setState(() => _isLoadingGoogle = v)),
                    isLoading: _isLoadingGoogle,
                    text: 'Continue with Google',
                    icon: const Icon(Icons.g_mobiledata, size: 36, color: Color(0xFF1F1F1F)), // <--- Changed this line!
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F1F1F),
                    animationDelay: 300,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white24)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('OR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                  ).animate().fade(delay: 350.ms),

                  // --- TERMS OF SERVICE (Sign-up only) ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: _isSignUp
                          ? Padding(
                              key: const ValueKey('terms'),
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Theme(
                                    data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white38),
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (bool? value) {
                                        HapticFeedback.lightImpact();
                                        setState(() => _agreedToTerms = value ?? false);
                                      },
                                      activeColor: const Color(0xFF00E5FF),
                                      checkColor: Colors.black,
                                    ),
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        children: [
                                          const TextSpan(text: 'I agree to the '),
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: const TextStyle(color: Color(0xFF00E5FF), decoration: TextDecoration.underline),
                                            recognizer: _termsRecognizer,
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: const TextStyle(color: Color(0xFF00E5FF), decoration: TextDecoration.underline),
                                            recognizer: _privacyRecognizer,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty_terms')),
                    ),
                  ),

                  // EMAIL / PASSWORD UI
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: _isSignUp
                          ? Padding(
                              key: const ValueKey('name_field'),
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: AuthTextField(
                                controller: _nameController,
                                hintText: 'Your Name',
                                prefixIcon: Icons.person,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                errorText: _nameError,
                                onChanged: (val) => { if (_nameError != null) setState(() => _nameError = null) },
                              textInputAction: TextInputAction.next,
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty_name')),
                    ),
                  ),
                  AuthTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                    onChanged: (val) => { if (_emailError != null) setState(() => _emailError = null) },
                    autofocus: false, // Turned off autofocus to prevent keyboard from hiding the screen on startup
                  textInputAction: TextInputAction.next,
                  ).animate().fade(delay: 100.ms),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    prefixIcon: Icons.lock,
                    obscureText: _obscurePassword,
                    errorText: _passwordError,
                    onChanged: (val) => { if (_passwordError != null) setState(() => _passwordError = null) },
                  textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: _isSignUp ? null : (_) => _handleEmailSignIn(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ).animate().fade(delay: 150.ms),
                  
                  // CONFIRM PASSWORD (Sign-up only)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: _isSignUp
                          ? Padding(
                              key: const ValueKey('confirm_password_field'),
                              padding: const EdgeInsets.only(top: 12.0),
                              child: AuthTextField(
                                controller: _confirmPasswordController,
                                hintText: 'Confirm Password',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                errorText: _confirmPasswordError,
                                onChanged: (val) => { if (_confirmPasswordError != null) setState(() => _confirmPasswordError = null) },
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleEmailSignIn(),
                                suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty_confirm_password')),
                    ),
                  ),

                  // FORGOT PASSWORD
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoadingGoogle || _isLoadingGuest || _isLoadingApple || _isLoadingEmail || _isLoadingReset
                            ? null 
                            : _handleForgotPassword,
                        child: _isLoadingReset
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2))
                            : const Text('Forgot Password?', style: TextStyle(color: Colors.white70)),
                      ),
                    ).animate().fade(delay: 160.ms)
                  else if (_isSignUp)
                    const SizedBox(height: 24),
                  
                  // EMAIL LOGIN BUTTON
                  SocialAuthButton(
                    onPressed: _isLoadingGoogle || _isLoadingGuest || _isLoadingApple || _isLoadingEmail || _isLoadingReset || (_isSignUp && !_agreedToTerms) 
                        ? null 
                        : _handleEmailSignIn,
                    isLoading: _isLoadingEmail,
                    text: _isSignUp ? 'Create Account' : 'Sign In with Email',
                    icon: const Icon(Icons.login, size: 28, color: Colors.black),
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    animationDelay: 150,
                  ),
                  
                  // TOGGLE SIGN UP / SIGN IN
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _emailError = null; 
                        _passwordError = null;
                        _confirmPasswordError = null;
                        _nameError = null;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : 'Don\'t have an account? Sign Up',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ).animate().fade(delay: 165.ms),

                  const SizedBox(height: 32),
                  // THE NEW GUEST BUTTON
                  GuestAuthButton(
                    onPressed: _isLoadingGoogle || _isLoadingGuest || _isLoadingApple || _isLoadingEmail || _isLoadingReset || (_isSignUp && !_agreedToTerms) 
                        ? null 
                        : () => _performSignIn(context.read<AppAuthProvider>().signInAsGuest, 'Guest', (v) => setState(() => _isLoadingGuest = v)),
                    isLoading: _isLoadingGuest,
                    animationDelay: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fade(duration: 1200.ms),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;
  final Widget icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final int animationDelay;

  const SocialAuthButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.text,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(double.infinity, 54),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: foregroundColor, strokeWidth: 3))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 12),
                Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
              ],
            ),
    ).animate()
     .fade(duration: 500.ms, delay: animationDelay.ms)
     .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(prefixIcon, color: Colors.white54),
        suffixIcon: suffixIcon,
        errorText: errorText,
      ),
    );
  }
}

class GuestAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final int animationDelay;

  const GuestAuthButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2))
          : const Text(
              'Continue as Guest',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
    ).animate()
     .fade(duration: 500.ms, delay: animationDelay.ms)
     .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
  }
}