import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'profile_setup_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';


// --- UPGRADED DATA MODEL ---
enum QuestionType { singleChoice, multiSelectGrid }

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
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Store single-choice answers
  Map<int, String> userAnswers = {};
  
  // Store the multiple selections from the final grid!
  Set<String> selectedInterests = {};

  final List<SurveyQuestion> questions = [
    SurveyQuestion(
      title: 'Why are you embarking on this journey to build healthy habits?',
      options: ['To feel better about myself', 'To improve my health', 'To set and achieve goals', 'To be more like someone who I admire'],
    ),
    SurveyQuestion(
      title: 'How much sleep do you usually get at night?',
      options: ['7 hours or less', '7-9 hours', '9-12 hours', '12 hours or more'],
    ),
    SurveyQuestion(
      title: 'Understood! Throughout your day, how are your energy levels?',
      options: ['High - energized throughout the day', 'Medium - I have bursts of energy', 'Low - my energy fades throughout the day'],
    ),
    SurveyQuestion(
      title: 'How distractable are you?',
      options: ['Easily distracted', 'Sometimes lose focus', 'Rarely lose focus', 'Laser focus'],
    ),
    SurveyQuestion(
      title: 'We hear you. What single change would improve your life right now?',
      options: ['More energy', 'More productivity', 'More mindfulness', 'More sleep'],
    ),
    // --- THE NEW MULTI-SELECT GRID PAGE ---
    SurveyQuestion(
      title: 'Almost there! Tell us what you\'re interested in',
      subtitle: 'Pick as many as you like.',
      type: QuestionType.multiSelectGrid,
      options: [
        'Stoicism', 'Emotional Wellness', 'Pet Lovers', 'Structure & Organisation',
        'Reading & Studying', 'The Environment', 'Mindful Eating', 'Self-discipline',
        'Behavior Change', 'Gratitude', 'Creativity', 'Aging',
        'Financial Habits', 'Self-love', 'Parenthood', 'Productivity',
        'Better Relationships', 'Mindfulness', 'Physical Wellness', 'Anxiety & Stress',
        'Detox Bad Habits', 'Purpose & Motivation', 'Better Sleep', 'Balanced Life'
      ],
    ),
  ];

  void _handleSingleChoiceAnswer(String answer) {
    HapticFeedback.lightImpact();
    userAnswers[_currentPage] = answer;

    if (_currentPage < questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
    } else {
      _triggerAnalysis();
    }
  }

  void _toggleGridSelection(String option) {
    HapticFeedback.selectionClick();
    setState(() {
      if (selectedInterests.contains(option)) {
        selectedInterests.remove(option);
      } else {
        selectedInterests.add(option);
      }
    });
  }

  void _triggerAnalysis() async {
    HapticFeedback.heavyImpact();
    // We can pass BOTH userAnswers and selectedInterests to the generation screen later!
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProfileSetupScreen(surveyAnswers: userAnswers)));
  }

  @override
  Widget build(BuildContext context) {

    // final backgroundGradient = LinearGradient(
    //   begin: Alignment.topCenter,
    //   end: Alignment.bottomCenter,
    //   colors: [
    //     const Color(0xFFFF512F).withOpacity(0.8),
    //     const Color(0xFFDD2476).withOpacity(0.9),
    //     const Color(0xFF13002B),
    //   ],
    // );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F7FA)),
        child: SafeArea(
          child: Column(
            children: [
              // --- PROGRESS BAR & BACK BUTTON ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
                      onPressed: () {
                        if (_currentPage > 0) {
                          _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                      },
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_currentPage + 1) / questions.length,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          color: Colors.white,
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
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    
                    if (question.type == QuestionType.multiSelectGrid) {
                      return _buildMultiSelectGridPage(question);
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

  // --- UI FOR SINGLE CHOICE (The White Cards) ---
  Widget _buildSingleChoicePage(SurveyQuestion question) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(question.title, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 32, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 40),
          ...question.options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: GestureDetector(
              onTap: () => _handleSingleChoiceAnswer(option),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]),
                child: Text(option, style: const TextStyle(color: Color(0xFF13002B), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          )),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- UI FOR MULTI-SELECT GRID (The Image Cards) ---
  Widget _buildMultiSelectGridPage(SurveyQuestion question) {
    // Beautiful placeholder gradients to use until you insert real images!
    final List<List<Color>> placeholderGradients = [
      [const Color(0xFF00c6ff), const Color(0xFF0072ff)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
      [const Color(0xFFa18cd1), const Color(0xFFfbc2eb)],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.title, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
              if (question.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(question.subtitle!, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 16, fontWeight: FontWeight.w600)),
              ]
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
              childAspectRatio: 0.85 // Taller cards to fit images later
            ),
            itemCount: question.options.length,
            itemBuilder: (context, index) {
              final option = question.options[index];

              final isSelected = selectedInterests.contains(option);
              // Assuming image assets are named like 'assets/interests/stoicism.png'
              // You'll need to create these assets!
              final safeName = option.toLowerCase()
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
              .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
            },
          ),
        ),
        

        // --- THE FIXED CONTINUE BUTTON ---
        // THE Premium Glassmorphism Bottom Bar
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // The intense frosty glass
            child: Container(
              padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
              decoration: BoxDecoration(
                // A subtle white gradient to give the glass some lighting
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                // The crisp icy top edge of the glass
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _triggerAnalysis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1F36), // Deep premium navy button
                    foregroundColor: Colors.white,
                    elevation: 0, // No shadow needed, the glass does the work
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),           
            ),
          ),
        )
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
    required this.onTap
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
        scale:  _isPressed ? 0.93 : 1.0, // Shrinks by 7% when pressed
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,

        // The frosty glass design
        // Inside your FrostyCategoryCard...
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // clipBehavior is crucial so the big image doesn't spill out of the rounded corners!
          clipBehavior: Clip.antiAlias, 
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFF1A1F36) : Colors.white,
              width: widget.isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.08),
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
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 40),
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