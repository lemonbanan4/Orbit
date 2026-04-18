import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'journey_generation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Map<int, String> surveyAnswers;

  const ProfileSetupScreen({super.key, required this.surveyAnswers});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State Variables to hold user input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String? _selectedIdentity;
  String? _selectedWakeTime;
  bool _optOutEmails = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus(); // Dismiss keyboard when changing pages
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _finishSetup() async {
    HapticFeedback.heavyImpact();
    FocusScope.of(context).unfocus();
    
    // 1. SAVE TO HARD DRIVE
    final prefs = await SharedPreferences.getInstance();
    final String finalName = _nameController.text.trim();
    
    await prefs.setString('orbit_user_name', finalName);
    await prefs.setString('orbit_user_email', _emailController.text.trim());
    await prefs.setString('orbit_user_age', _ageController.text.trim());
    
    if (!mounted) return;

    // 2. PASS IT DOWN THE FUNNEL
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => JourneyGenerationScreen(
        userAnswers: widget.surveyAnswers,
        userName: finalName, // Pass the name forward!
      ))
    );
  }

  @override
  Widget build(BuildContext context) {
    // The deep blue from your screenshots
    //const Color bgColor = Color(0xFF0D47A1); 

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildNameScreen(),
                  _buildAgeScreen(),
                  _buildIdentityScreen(),
                  _buildWakeTimeScreen(),
                  _buildEmailScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. NAME SCREEN ---
  Widget _buildNameScreen() {
    return _buildInputTemplate(
      title: 'Save your progress',
      subtitle: 'My first name is...',
      inputWidget: TextField(
        controller: _nameController,
        autofocus: true,
        style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Enter your name',
          hintStyle: TextStyle(color: Color(0xFF1A1F36).withOpacity(0.3), fontSize: 24, fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
        onChanged: (val) => setState(() {}), // Update UI to enable button
      ),
      buttonText: 'NEXT',
      isButtonEnabled: _nameController.text.trim().isNotEmpty,
      onButtonPressed: _nextPage,
    );
  }

  // --- 2. AGE SCREEN (Your custom request!) ---
  Widget _buildAgeScreen() {
    return _buildInputTemplate(
      title: 'Nice to meet you, ${_nameController.text.trim()}!',
      subtitle: 'How old are you?',
      inputWidget: TextField(
        controller: _ageController,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Enter your age',
          hintStyle: TextStyle(color: Color(0xFF1A1F36).withOpacity(0.3), fontSize: 24, fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
        onChanged: (val) => setState(() {}),
      ),
      buttonText: 'NEXT',
      isButtonEnabled: _ageController.text.trim().isNotEmpty,
      onButtonPressed: _nextPage,
    );
  }

  // --- 3. IDENTITY SCREEN ---
  Widget _buildIdentityScreen() {
    final options = ['Woman', 'Man', 'Non-binary'];
    
    return _buildSelectionTemplate(
      title: 'How do you identify?',
      subtitle: 'At times, we\'ll provide gender specific recommendations',
      options: options,
      selectedValue: _selectedIdentity,
      onSelected: (val) {
        setState(() => _selectedIdentity = val);
        Future.delayed(const Duration(milliseconds: 300), _nextPage); // Auto-advance!
      },
    );
  }

  // --- 4. WAKE TIME SCREEN ---
  Widget _buildWakeTimeScreen() {
    final options = ['07:00', '08:00', '09:00', 'Other time'];
    
    return _buildSelectionTemplate(
      title: 'When do you wake up generally?',
      options: options,
      selectedValue: _selectedWakeTime,
      onSelected: (val) {
        setState(() => _selectedWakeTime = val);
        Future.delayed(const Duration(milliseconds: 300), _nextPage); // Auto-advance!
      },
      isCentered: true, // Centers the buttons like the screenshot
    );
  }

  // --- 5. EMAIL SCREEN ---
  Widget _buildEmailScreen() {
    return _buildInputTemplate(
      title: 'Your email (required)',
      inputWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(color: Color(0xFF1A1F36).withOpacity(0.3), fontSize: 24, fontWeight: FontWeight.bold),
              border: InputBorder.none,
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: _optOutEmails,
                  onChanged: (val) => setState(() => _optOutEmails = val ?? false),
                  side: const BorderSide(color: Colors.white, width: 2),
                  activeColor: const Color(0xFFFFD600), // Fabulous Yellow
                  checkColor: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Please do not send me motivational emails.', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          )
        ],
      ),
      buttonText: 'CONTINUE',
      // Basic email validation
      isButtonEnabled: _emailController.text.contains('@') && _emailController.text.contains('.'),
      onButtonPressed: _finishSetup,
    );
  }

  // --- REUSABLE TEMPLATES ---

  // Template for Text Input screens (Name, Age, Email)
  Widget _buildInputTemplate({required String title, String? subtitle, required Widget inputWidget, required String buttonText, required bool isButtonEnabled, required VoidCallback onButtonPressed}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(title, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 28, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 18, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 32),
          inputWidget,
          const Spacer(),
          // Bottom Button
          ElevatedButton(
            onPressed: isButtonEnabled ? onButtonPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1F36), // Lighter blue for the button
              disabledBackgroundColor: const Color(0xFF1A1F36).withOpacity(0.3),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(buttonText, style: TextStyle(color: isButtonEnabled ? Colors.white : Colors.white54, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  // Template for Button Selection screens (Identity, Wake Time)
  Widget _buildSelectionTemplate({required String title, String? subtitle, required List<String> options, required String? selectedValue, required Function(String) onSelected, bool isCentered = false}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(title, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 28, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 16, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 40),
          ...options.map((option) {
            bool isSelected = selectedValue == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () => onSelected(option),
                child: Container(
                  width: isCentered ? 400 : double.infinity, // Center layout for times
                  margin: isCentered ? const EdgeInsets.symmetric(horizontal: 50) : EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFD600) : const Color(0xFF1A1F36), // Fabulous Yellow when selected
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? const Color(0xFFFFD600) : const Color(0xFF1A1F36).withOpacity(0.3), width: 2),
                  ),
                  alignment: isCentered ? Alignment.center : Alignment.centerLeft,
                  child: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // No "Next" button needed here because selecting an option auto-advances!
        ],
      ),
    );
  }
}