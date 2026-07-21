// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'onboarding_screen.dart';
import '../../widgets/common/glow_orb.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/auth_text_field.dart';
import '../../widgets/common/social_auth_button.dart';
import '../../widgets/common/guest_auth_button.dart';
import '../../widgets/common/primary_button.dart';
import '../../theme/orbit_tokens.dart';

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchURL('https://orbitroutine.com/terms.html');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchURL('https://orbitroutine.com/privacy.html');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
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
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
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
      if (context.mounted) _showErrorSnackBar(context, 'Could not open link.');
    }
  }

  // Returns null on failure; otherwise the "isNewUser" flag from
  // signInMethod, so callers can tell a genuine sign-up from a returning
  // user signing back in.
  Future<bool?> _performSignIn(
    Future<bool> Function() signInMethod,
    String provider,
    void Function(bool) setLoading,
  ) async {
    HapticFeedback.mediumImpact();
    setLoading(true);
    try {
      return await signInMethod();
    } catch (e, stackTrace) {
      if (!context.mounted) return null;

      // Log the error securely to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Sign-in failed for $provider',
        fatal: false,
      );

      String errorMessage =
          'Failed to sign in with $provider. Please try again.';
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('network') || errorString.contains('internet')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('cancel')) {
        errorMessage = 'Sign-in was cancelled.';
      } else if (errorString.contains(
        'account-exists-with-different-credential',
      )) {
        errorMessage =
            'An account already exists with the same email but different sign-in method.';
      }

      _showErrorSnackBar(context, errorMessage);
      return null;
    } finally {
      if (context.mounted) setLoading(false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r"^[\w.!#$%&'*+\-/=?^`{|}~]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
    ).hasMatch(email);
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
    // Letters-only (a-zA-Z) rejected any hyphenated name (Mary-Jane),
    // apostrophe (O'Brien), or non-ASCII name (José, François, Björn) --
    // \p{L} matches any Unicode letter, so this now covers real names
    // worldwide instead of just plain ASCII.
    return RegExp(r"^[\p{L}\s\-']+$", unicode: true).hasMatch(name);
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    String? emailErr;
    String? passwordErr;
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
    }

    if (hasError) {
      final firstError =
          emailErr ?? nameErr ?? passwordErr ?? 'Please check your inputs.';
      _showErrorSnackBar(context, firstError);
      return;
    }

    final isNewUser = await _performSignIn(
      () async {
        if (_isSignUp) {
          await context.read<AppAuthProvider>().createUserWithEmailAndPassword(
            email,
            password,
            name,
          );
        } else {
          await context.read<AppAuthProvider>().signInWithEmailAndPassword(
            email,
            password,
          );
        }
        return _isSignUp;
      },
      _isSignUp ? 'Sign Up' : 'Email',
      (v) => setState(() => _isLoadingEmail = v),
    );

    if (isNewUser != null && context.mounted) {
      if (isNewUser) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(initialName: name),
          ),
        );
      } else {
        // Returning users will be auto-routed to MainNavigationScreen by AuthWrapper!
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showErrorSnackBar(
        context,
        'Please enter a valid email to reset your password.',
      );
      return;
    }

    setState(() => _isLoadingReset = true);
    try {
      await context.read<AppAuthProvider>().sendPasswordResetEmail(email);
      if (context.mounted) {
        _showSuccessSnackBar(context, 'Password reset link sent to $email.');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Failed to send reset email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.7),
            radius: 1.3,
            colors: [
              OrbitTokens.teal.withValues(alpha: 0.16),
              OrbitTokens.ground,
            ],
            stops: const [0.0, 0.75],
          ),
        ),
        child: Stack(
          children: [
            // --- 3D POP BACKGROUND ---
            GlowOrb(
              color: OrbitTokens.teal.withValues(alpha: 0.12),
              size: 400,
              top: -100,
              left: -50,
            ),
            GlowOrb(
              color: OrbitTokens.violet.withValues(alpha: 0.18),
              size: 300,
              bottom: 50,
              right: -50,
            ),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 40.0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // BRANDING
                    const Icon(
                          Icons.blur_on_rounded,
                          size: 80,
                          color: OrbitTokens.teal,
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 2.seconds),
                    const SizedBox(height: 16),
                    const Text(
                      'Orbit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const Text(
                      'Master your day.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 50),

                    // THE GLASS LOGIN BOX
                    GlassContainer(
                      child: Column(
                        children: [
                          if (_isSignUp) ...[
                            AuthTextField(
                              controller: _nameController,
                              hintText: "Name",
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                          ],
                          AuthTextField(
                            controller: _emailController,
                            hintText: "Email",
                            prefixIcon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _passwordController,
                            hintText: "Password",
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          if (!_isSignUp) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoadingReset
                                    ? null
                                    : _handleForgotPassword,
                                child: _isLoadingReset
                                    ? const SizedBox(
                                        height: 12,
                                        width: 12,
                                        child: CircularProgressIndicator(
                                          color: Colors.white54,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Forgot Password?",
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 16),
                          PrimaryButton(
                            text: _isSignUp ? "Create Orbit" : "Sign In",
                            onPressed: _handleEmailSignIn,
                            isLoading: _isLoadingEmail,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // SOCIAL BUTTONS
                    SocialAuthButton(
                      onPressed: () async {
                        final isNewUser = await _performSignIn(
                          () =>
                              context.read<AppAuthProvider>().signInWithApple(),
                          'Apple',
                          (v) => setState(() => _isLoadingApple = v),
                        );
                        // Only genuinely new sign-ups see onboarding — a
                        // returning user signing back in goes straight into
                        // the app via AuthWrapper.
                        if (isNewUser == true && context.mounted) {
                          final displayName =
                              FirebaseAuth.instance.currentUser?.displayName;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OnboardingScreen(initialName: displayName),
                            ),
                          );
                        }
                      },
                      isLoading: _isLoadingApple,
                      text: 'Continue with Apple',
                      icon: const Icon(Icons.apple, color: Colors.white),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      animationDelay: 100,
                    ),
                    const SizedBox(height: 12),
                    SocialAuthButton(
                      onPressed: () async {
                        final isNewUser = await _performSignIn(
                          () => context
                              .read<AppAuthProvider>()
                              .signInWithGoogle(),
                          'Google',
                          (v) => setState(() => _isLoadingGoogle = v),
                        );
                        // Only genuinely new sign-ups see onboarding — a
                        // returning user signing back in goes straight into
                        // the app via AuthWrapper.
                        if (isNewUser == true && context.mounted) {
                          final displayName =
                              FirebaseAuth.instance.currentUser?.displayName;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OnboardingScreen(initialName: displayName),
                            ),
                          );
                        }
                      },
                      isLoading: _isLoadingGoogle,
                      text: 'Continue with Google',
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 38,
                        color: Colors.black,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      animationDelay: 200,
                    ),

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? "Already have an account? Sign In"
                            : "New to Orbit? Create Account",
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GuestAuthButton(
                      onPressed: () async {
                        await _performSignIn(
                          () async {
                            await context
                                .read<AppAuthProvider>()
                                .signInAsGuest();
                            return false;
                          },
                          'Guest',
                          (v) => setState(() => _isLoadingGuest = v),
                        );
                      },
                      isLoading: _isLoadingGuest,
                      animationDelay: 300,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
