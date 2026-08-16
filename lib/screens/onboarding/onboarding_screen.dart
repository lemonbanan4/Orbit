import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/interest_options.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:orbit_app/theme/glass_button.dart';
import '../../theme/orbit_tokens.dart';
import 'future_letter_screen.dart';
import '../../screens/paywall/clay_button.dart';

// --- UPGRADED DATA MODEL ---
enum QuestionType { singleChoice, multiSelectGrid, textInput }

class SurveyQuestion {
  final String title;
  final String? subtitle; // Added for the grid page
  final List<String> options;
  final QuestionType type;

  SurveyQuestion({
    required this.title,
    this.subtitle,
    required this.options,
    this.type = QuestionType.singleChoice, // Defaults to single choice
  });
}

class OnboardingScreen extends StatefulWidget {
  // Pre-fills the name question when it's already known (email sign-up
  // collects it directly; Apple/Google may supply a profile name) so the
  // user isn't asked to retype something they just gave us. They can still
  // edit it before continuing.
  final String? initialName;

  const OnboardingScreen({super.key, this.initialName});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _capturedUserName = '';
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  // Store single-choice answers
  Map<int, String> userAnswers = {};

  // Store the multiple selections from the final grid!
  Set<String> selectedInterests = {};

  final List<SurveyQuestion> questions = [
    SurveyQuestion(
      title: 'Welcome to Orbit!\nWhat should we call you?',
      options: [], // Not needed for textInput
      type: QuestionType.textInput,
    ),
    SurveyQuestion(
      title: 'Why are you embarking on this journey to build healthy habits?',
      options: [
        'To feel better about myself',
        'To improve my health',
        'To set and achieve goals',
        'To be more like someone who I admire',
      ],
    ),
    SurveyQuestion(
      title: 'How much sleep do you usually get at night?',
      options: [
        '7 hours or less',
        '7-9 hours',
        '9-12 hours',
        '12 hours or more',
      ],
    ),
    SurveyQuestion(
      title: 'Understood! Throughout your day, how are your energy levels?',
      options: [
        'High - energized throughout the day',
        'Medium - I have bursts of energy',
        'Low - my energy fades throughout the day',
      ],
    ),
    SurveyQuestion(
      title: 'How distractable are you?',
      options: [
        'Easily distracted',
        'Sometimes lose focus',
        'Rarely lose focus',
        'Laser focus',
      ],
    ),
    SurveyQuestion(
      title:
          'We hear you. What single change would improve your life right now?',
      options: [
        'More energy',
        'More productivity',
        'More mindfulness',
        'More sleep',
      ],
    ),
    // --- THE NEW MULTI-SELECT GRID PAGE ---
    SurveyQuestion(
      title: 'Almost there! Tell us what you\'re interested in',
      subtitle: 'Pick as many as you like.',
      type: QuestionType.multiSelectGrid,
      // Shared with Settings' interests editor — see interest_options.dart.
      options: interestOptions,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _requestATT();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _capturedUserName = widget.initialName!;
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleSingleChoiceAnswer(String answer) {
    HapticFeedback.lightImpact();
    userAnswers[_currentPage] = answer;

    if (_currentPage < questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    } else {
      _triggerAnalysis();
    }
  }

  Future<void> _saveSurveyToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("Error: No user is signed in. Cannot save survey.");
      return; // Can't save if there's no user
    }

    // Prepare the data for Firestore. Keys here must stay in sync with
    // firestore.rules' isValidUser() allowedKeys, or the write is silently
    // rejected by security rules and this whole function throws before
    // the caller ever reaches Navigator.pushReplacement.
    final Map<String, dynamic> surveyData = {
      'displayName': _capturedUserName,
      'email': user.email, // Capture email from the authenticated user
      'onboarding_completed_at': FieldValue.serverTimestamp(),
      'interests': selectedInterests
          .toList(), // Convert Set to List for Firestore
      // Explicitly typed — an untyped {} here infers as Map<dynamic,
      // dynamic>, which throws when cast to Map<String, dynamic> below and
      // silently aborts this whole save (caught by the caller's try/catch,
      // so nothing outwardly breaks, but no survey data ever got saved).
      'survey_answers': <String, dynamic>{},
    };

    // Map question titles to answers for better readability in Firestore
    userAnswers.forEach((key, value) {
      if (key < questions.length) {
        // Use a shortened/sanitized version of the title as the key
        final questionTitle = questions[key].title
            .substring(0, 20)
            .replaceAll('\n', ' ');
        (surveyData['survey_answers'] as Map<String, dynamic>)[questionTitle] =
            value;
      }
    });

    // Save to the 'users' collection with the document ID set to the user's UID
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(surveyData, SetOptions(merge: true));
    debugPrint("Survey data saved to Firestore for user ${user.uid}");
  }

  void _triggerAnalysis() async {
    // Guards against a fast double-tap firing this twice -- unlike the
    // sheet/journal save flows, this button had no lock, so two taps could
    // fire two overlapping survey writes and two navigations in a row.
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    // Notification permission used to be requested right here, uncontextually,
    // before the user has even reached the dashboard or the paywall -- iOS
    // only ever shows that system dialog once per install, so this "used up"
    // the ask on a bare survey transition. MainNavigationScreen's
    // showNotificationPrePrompt (a custom "Stay on track!" explainer first,
    // then the real OS prompt) already fires the first time every user
    // lands on the dashboard, so this call was both premature and redundant.

    // Save the data to Firestore before navigating. This is best-effort:
    // a write failure shouldn't strand the user on the onboarding survey.
    try {
      await _saveSurveyToFirestore();
    } catch (e) {
      debugPrint('Error saving survey to Firestore: $e');
    }

    if (!mounted) return;

    // Onward to the welcome letter -> commitment contract -> paywall flow,
    // same as every other sign-up path.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FutureLetterScreen(userName: _capturedUserName),
      ),
    );
  }

  Future<void> _requestATT() async {
    try {
      // Wait a brief moment to ensure the UI is fully rendered before popping the ATT dialog
      await Future.delayed(const Duration(milliseconds: 1000));

      final TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      // if the system can prompt them, do it
      if (status == TrackingStatus.notDetermined) {
        final TrackingStatus newStatus =
            await AppTrackingTransparency.requestTrackingAuthorization();

        if (newStatus == TrackingStatus.notDetermined) {
          debugPrint('User dismissed the ATT prompt without making a choice.');
        } else if (newStatus == TrackingStatus.authorized) {
          debugPrint('User granted tracking permission.');
          FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
        } else {
          debugPrint('User denied tracking permission.');
        }
      } else if (status == TrackingStatus.authorized) {
        debugPrint('Tracking permission already granted.');
      } else {
        debugPrint('Tracking permission already denied.');
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get ATT status: $e");
    } catch (e) {
      debugPrint('Error requesting tracking authorization: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.3,
            colors: [
              OrbitTokens.violet.withValues(alpha: 0.20),
              OrbitTokens.ground,
            ],
            stops: const [0.0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- PROGRESS BAR & BACK BUTTON ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        if (_currentPage > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_currentPage + 1) / questions.length,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: OrbitTokens.teal,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // --- THE SURVEY ENGINE ---
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];

                    if (question.type == QuestionType.multiSelectGrid) {
                      return _buildMultiSelectGridPage(question);
                    } else if (question.type == QuestionType.textInput) {
                      return _buildTextInputPage(question);
                    } else {
                      return _buildSingleChoicePage(question);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI FOR TEXT INPUT (The Name Slide) ---
  Widget _buildTextInputPage(SurveyQuestion question) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            question.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _nameController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Your name',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: OrbitTokens.teal, width: 2),
              ),
            ),
            onChanged: (val) => setState(() => _capturedUserName = val.trim()),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutQuart,
                );
              }
            },
          ),
          const SizedBox(height: 40),
          AnimatedOpacity(
            opacity: _capturedUserName.isNotEmpty ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: ClayButton(
              text: 'CONTINUE',
              onPressed: () {
                if (_capturedUserName.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutQuart,
                  );
                }
              },
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- UI FOR SINGLE CHOICE (The White Cards) ---
  Widget _buildSingleChoicePage(SurveyQuestion question) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            question.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () => _handleSingleChoiceAnswer(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: OrbitTokens.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    option,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- UI FOR MULTI-SELECT GRID (The Image Cards) ---
  Widget _buildMultiSelectGridPage(SurveyQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              if (question.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  question.subtitle!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85, // Taller cards to fit images later
            ),
            itemCount: question.options.length,
            itemBuilder: (context, index) {
              final option = question.options[index];

              final isSelected = selectedInterests.contains(option);
              // Assuming image assets are named like 'assets/interests/stoicism.png'
              // You'll need to create these assets!
              final safeName = option
                  .toLowerCase()
                  .replaceAll(' & ', '_and_') // Fix the ampersand first
                  .replaceAll('-', '_') // Fixes Self-love and Self-discipline
                  .replaceAll(' ', '_'); // Then fix the spaces
              final imagePath = 'assets/interests/$safeName.png';

              return FrostyCategoryCard(
                    title: option,
                    imagePath: imagePath,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedInterests.remove(option);
                        } else {
                          selectedInterests.add(option);
                        }
                      });
                    },
                  )
                  // THE MAGIC WATERFALL ANIMATION
                  // Each card waits 50ms longer than the previous one before sliding up
                  .animate()
                  .fade(duration: 400.ms, delay: (index * 50).ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad,
                  );
            },
          ),
        ),

        // --- THE FIXED CONTINUE BUTTON ---
        // THE Premium Glassmorphism Bottom Bar
        //GlassDockButton(text: 'CONTINUE', onPressed: _triggerAnalysis),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20.0,
              sigmaY: 20.0,
            ), // The intense frosty glass
            child: Container(
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 40,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                // A subtle white gradient to give the glass some lighting
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.2),
                  ],
                ),
                // The crisp icy top edge of the glass
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,

                child: GlassButton(
                  text: 'CONTINUE',
                  onPressed: _isSubmitting ? null : _triggerAnalysis,
                ),
                // child: ElevatedButton(
                //   onPressed: _triggerAnalysis,
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: const Color(
                //       //0xFF00E5FF,
                //       0xFF1A1F36,
                //     ), // Deep premium navy button
                //     foregroundColor: Colors.white,
                //     elevation: 0, // No shadow needed, the glass does the work
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(16),
                //     ),
                //   ),
                //   child: const Text(
                //     'CONTINUE',
                //     style: TextStyle(
                //       fontSize: 16,
                //       fontWeight: FontWeight.bold,
                //       letterSpacing: 1.5,
                //     ),
                //   ),
                // ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FrostyCategoryCard extends StatefulWidget {
  final String title;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const FrostyCategoryCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<FrostyCategoryCard> createState() => _FrostyCategoryCardState();
}

class _FrostyCategoryCardState extends State<FrostyCategoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 1. Trigger the "shrink" effect when they push down
      onTapDown: (_) => setState(() => _isPressed = true),
      // 2. Trigger the "bounce back", haptic vibration, and selection on release
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact(); // The premium "tick" vibration!
        widget.onTap();
      },
      // 3. cancel the shrink if they drag their finger away
      onTapCancel: () => setState(() => _isPressed = false),

      // The smooth bounce animation
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0, // Shrinks by 7% when pressed
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,

        // The frosty glass design
        // Inside your FrostyCategoryCard...
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // clipBehavior is crucial so the big image doesn't spill out of the rounded corners!
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFF1A1F36) : Colors.white,
              width: widget.isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // THE MASSIVE CENTERED 3D ASSET
                Expanded(
                  child: Center(
                    child: Image.asset(
                      widget.imagePath,
                      // Boxfit.contain ensures it gets as big as possible
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8), // breathiing room
                // THE CENTERED TEXT
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Color(0xFF1A1F36),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
