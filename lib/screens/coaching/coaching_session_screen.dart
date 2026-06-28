import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- DIALOGUE DATA MODELS ---
class CoachingNode {
  final String id;
  final List<String> fairyMessages;
  final List<CoachingOption> options;
  final bool isInput;

  CoachingNode({
    required this.id,
    required dynamic fairyMessage,
    this.options = const [],
    this.isInput = false,
  }) : fairyMessages = fairyMessage is List<String>
           ? fairyMessage
           : [fairyMessage.toString()];

  // This getter dynamically pulsl a message when the node is displayed
  String get displayMessage {
    if (fairyMessages.isEmpty) return '';
    if (fairyMessages.length == 1) return fairyMessages.first;

    // Pick a truly random message from the pool
    final random = Random();
    return fairyMessages[random.nextInt(fairyMessages.length)];
  }
}

class CoachingOption {
  final String text;
  final String nextNodeId;

  CoachingOption({required this.text, required this.nextNodeId});
}

// --- THE SCREEN ---
class CoachingSessionScreen extends StatefulWidget {
  final String sessionType; // 'daily', 'workday', or 'nightly'

  const CoachingSessionScreen({super.key, required this.sessionType});

  @override
  State<CoachingSessionScreen> createState() => _CoachingSessionScreenState();
}

class _CoachingSessionScreenState extends State<CoachingSessionScreen> {
  late RoutineProvider _routineProvider;
  late Map<String, CoachingNode> _currentTree;
  String _currentNodeId = 'start';
  final TextEditingController _noteController = TextEditingController();
  final AudioPlayer _hypnoticAudioPlayer = AudioPlayer();

  // --- HARDCODED TREES ---
  final Map<String, CoachingNode> _dailyTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'Good morning, Commander. A new solar cycle begins. How are your systems calibrating today?',
      options: [
        CoachingOption(text: 'Ready to launch', nextNodeId: 'launch'),
        CoachingOption(text: 'A bit sluggish', nextNodeId: 'sluggish'),
      ],
    ),
    'launch': CoachingNode(
      id: 'launch',
      fairyMessage: [
        'Momentum is on your side. Let\'s channel that energy.',
        'A perfect start sequence. Let\'s lock in your coordinates.',
      ],
      options: [
        CoachingOption(text: 'Set my intention', nextNodeId: 'input_dynamic'),
      ],
    ),
    'sluggish': CoachingNode(
      id: 'sluggish',
      fairyMessage: [
        'Even the brightest stars take time to ignite. Let\'s start with a gentle engine warm-up. Take a slow, deep breath in... and out.',
        'Gravity feels heavier some mornings. Let\'s lower the thrusters and ease into orbit. Just breathe.',
      ],
      options: [
        CoachingOption(text: 'I\'m ready now', nextNodeId: 'input_dynamic'),
      ],
    ),
    'input_dynamic': CoachingNode(
      id: 'input_dynamic',
      fairyMessage: [
        'What is the single most vital intention you want to set for this solar cycle?',
        'If you could accomplish just one meaningful thing today, what would it be?',
      ],
      isInput: true,
    ),
    'done_dynamic': CoachingNode(
      id: 'done_dynamic',
      fairyMessage: [
        'Morning alignment complete. Your intention to "[INTENTION]" is locked in. Have a stellar day, Commander.',
        'Trajectory set. Carry "[INTENTION]" with you as you navigate the stars today. End of transmission.',
      ],
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };

  final Map<String, CoachingNode> _workdayTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'Mid-flight check-in, Commander. How are the atmospheric conditions out there?',
      options: [
        CoachingOption(text: 'Cruising smoothly', nextNodeId: 'smooth'),
        CoachingOption(text: 'Navigating turbulence', nextNodeId: 'turbulence'),
      ],
    ),
    'smooth': CoachingNode(
      id: 'smooth',
      fairyMessage: [
        'Excellent. Keep your velocity steady and maintain your heading.',
        'Clear skies ahead. Let\'s keep the thrusters humming at optimal efficiency.',
      ],
      options: [
        CoachingOption(text: 'Lock it in', nextNodeId: 'input_dynamic'),
      ],
    ),
    'turbulence': CoachingNode(
      id: 'turbulence',
      fairyMessage: [
        'Turbulence is normal. Let\'s run a quick diagnostic. Are you feeling overwhelmed by tasks, or distracted by noise?',
      ],
      options: [
        CoachingOption(text: 'Too many tasks', nextNodeId: 'overwhelmed'),
        CoachingOption(text: 'Too much noise', nextNodeId: 'distracted'),
      ],
    ),
    'overwhelmed': CoachingNode(
      id: 'overwhelmed',
      fairyMessage: [
        'When the dashboard lights up with warnings, focus on the single most critical system. Pick one task. Ground yourself. Everything else can wait.',
      ],
      options: [
        CoachingOption(text: 'Recalibrating...', nextNodeId: 'input_dynamic'),
      ],
    ),
    'distracted': CoachingNode(
      id: 'distracted',
      fairyMessage: [
        'Cosmic static can scramble your sensors. Take 60 seconds to step away from the monitors, close your eyes, and reset your frequency.',
      ],
      options: [
        CoachingOption(text: 'Frequency reset', nextNodeId: 'input_dynamic'),
      ],
    ),
    'input_dynamic': CoachingNode(
      id: 'input_dynamic',
      fairyMessage: [
        'To stabilize your orbit for the rest of the day, what is your primary focus from here?',
        'Write down the one thing you need to prioritize before power-down today.',
      ],
      isInput: true,
    ),
    'done_dynamic': CoachingNode(
      id: 'done_dynamic',
      fairyMessage: [
        'Course corrected. Focus on "[INTENTION]". You have the navigation data you need. Godspeed.',
        'Mid-day alignment complete. Remember your commitment to "[INTENTION]". Returning you to the helm.',
      ],
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };

  // --- UPGRADED HARDCODED TREES ---
  final Map<String, CoachingNode> _nightlyTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'What kind of support do you need for consulting the mirror right now?',
      options: [
        CoachingOption(text: 'Motivate me', nextNodeId: 'motivate'),
        CoachingOption(text: 'Adjust to how I feel', nextNodeId: 'adjust'),
      ],
    ),

    'motivate': CoachingNode(
      id: 'motivate',
      fairyMessage: 'Choose your cosmic focus tonight:',
      options: [
        CoachingOption(
          text: 'To improve my mental health',
          nextNodeId: 'mental',
        ),
        CoachingOption(text: 'To feel more relaxed', nextNodeId: 'relaxed'),
        CoachingOption(text: 'To enhance my focus', nextNodeId: 'focused'),
      ],
    ),

    'adjust': CoachingNode(
      id: 'adjust',
      fairyMessage:
          'It is okay to slow down. Let us lower the gravity, dim the starlight, and take a gentle approach tonight.',
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    // --- MENTAL HEALTH BRANCH ---
    'mental': CoachingNode(
      id: 'mental',
      fairyMessage:
          'When you feel your mental space getting crowded, what is the very first signal your system gives you?',
      options: [
        CoachingOption(text: 'A tightness in my chest', nextNodeId: 'mental_2'),
        CoachingOption(text: 'A racing heart', nextNodeId: 'mental_dynamic'),
        CoachingOption(text: 'A wandering mind', nextNodeId: 'mental_dynamic'),
      ],
    ),

    'mental_2': CoachingNode(
      id: 'mental_2',
      fairyMessage:
          'When the pressure builds, it helps to visualize your thoughts as unmapped stars in a vast galaxy. They don\'t define the sky; they are just passing through it. Let\'s cultivate a constellation of calm.',
      options: [
        CoachingOption(
          text: 'Tap to continue',
          nextNodeId: 'mental_followup_2',
        ),
      ],
    ),

    'mental_dynamic': CoachingNode(
      id: 'mental_dynamic',
      fairyMessage: [
        'Taking care of your mind isn\'t a fixed destination; it\'s a daily trajectory. Even a tiny 2% shift in your evening routine can completely alter your baseline orbit. Let\'s build that foundation.',
        'Mind altering practices are like cosmic fertilizers for your mental ecosystem. They help your inner garden flourish even when the external weather is stormy. What practice calls to you tonight?',
        'The ancient practice of mindfulness meditation is like a cosmic anchor for your wandering thoughts. Just a few minutes of focused breathing can create a ripple effect of calm throughout your entire system. Let\'s claim that stillness tonight.',
        'Marcus Aurelius said, "You have power over your mind - not outside events. Realize this, and you will find strength." Let\'s find that strength together.',
        'Your mind is like a vast universe, full of untapped potential and hidden beauty. Sometimes it just needs a little guidance to navigate through the cosmic noise. Let\'s chart a course to mental clarity.',
        'In the darkest nights, the stars shine the brightest. When your mental space feels overwhelming, it\'s a sign that you\'re on the verge of a breakthrough. Let\'s harness that energy and turn it into a supernova of calm and focus.',
        'Science shows that even a brief evening ritual can significantly improve sleep quality and reduce stress. It\'s like setting a cosmic alarm clock for your nervous system. What small ritual can you commit to tonight?',
        'Dr. Andrew Huberman, a renowned neuroscientist, emphasizes the importance of light exposure in regulating our circadian rhythms. Dimming the lights and reducing screen time in the evening can help signal to your brain that it\'s time to wind down. Let\'s create a sleep-friendly environment together.',
        'The ancient practice of mindfulness meditation is like a cosmic anchor for your wandering thoughts. Just a few minutes of focused breathing can create a ripple effect of calm throughout your entire system. Let\'s claim that stillness tonight.',
        'Philosopher Alan Watts said, "The only way to make sense out of change is to plunge into it, move with it, and join the dance." When your mental space feels chaotic, it\'s an invitation to dance with the present moment. Let\'s find the rhythm together.',
        'Your mental health is the foundation of your entire orbit. Just like a spaceship needs a stable core to navigate through space, you need a stable mind to navigate through life. Let\'s fortify that core with some intentional practices tonight.',
        'The cosmic mirror reflects not just what is, but what can be. By taking care of your mental space, you\'re not just surviving the stormy weather; you\'re learning to dance in the rain and even find beauty in it. Let\'s cultivate that resilience together.',
        'When you feel mentally overwhelmed, it\'s like being caught in a cosmic storm. But remember, even the fiercest storms eventually pass, and they often leave behind clearer skies and brighter stars. Let\'s weather this together and find the calm on the other side.',
        'Your mind is a powerful tool, but it can also be a tricky one to manage. It\'s like trying to hold onto stardust - the more you try to grasp it tightly, the more it slips through your fingers. Let\'s learn how to gently hold and guide your thoughts instead.',
        'The journey to mental well-being is not a straight path; it\'s more like navigating through a complex galaxy. There will be twists, turns, and unexpected discoveries along the way. Let\'s embrace the adventure together and find the stars that guide you to a calmer, clearer mind.',
        'Remember, even the most brilliant stars need darkness to shine. When your mental space feels overwhelming, it\'s a sign that you\'re on the verge of a breakthrough. Let\'s harness that energy and turn it into a supernova of calm and focus.',
      ],
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'mental_followup'),
      ],
    ),

    'mental_followup': CoachingNode(
      id: 'mental_followup',
      fairyMessage:
          'What is one tiny, non-negotiable ritual you want to anchor into your morning routine this week?',
      options: [
        CoachingOption(
          text: 'Mindfulness meditation',
          nextNodeId: 'meditation_dynamic',
        ),
        CoachingOption(
          text: 'Journaling to clear the noise',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'A short walk under the open sky',
          nextNodeId: 'fact_dynamic',
        ),
      ],
    ),

    'mental_followup_2': CoachingNode(
      id: 'mental_followup_2',
      fairyMessage: 'What do you struggle with more heavily right now?',
      options: [
        CoachingOption(
          text: 'Feeling overwhelmed by static',
          nextNodeId: 'mental_space',
        ),
        CoachingOption(
          text: 'Powering down to fall asleep',
          nextNodeId: 'relaxed',
        ),
      ],
    ),

    'mental_space': CoachingNode(
      id: 'mental_space',
      fairyMessage:
          'A mirror reflects what is, but a cosmic mirror reveals what can be. Prioritizing your inner landscape is the ultimate form of personal alchemy.',
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    // --- RELAXED BRANCH ---
    'relaxed': CoachingNode(
      id: 'relaxed',
      fairyMessage:
          'When the atmospheric pressure gets too high, what classic anchor brings you back down to Earth?',
      options: [
        CoachingOption(
          text: 'Sinking into audio or music',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'Moving my body in nature',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'Complete silence and meditation',
          nextNodeId: 'meditation_dynamic',
        ),
      ],
    ),

    // --- FOCUS BRANCH ---
    'focused': CoachingNode(
      id: 'focused',
      fairyMessage:
          'In a universe full of continuous noise, deep focus is your ultimate superpower—it is the lens that directs your light. Let\'s fine-tune your frequency.',
      options: [
        CoachingOption(
          text: 'Calibrate my environment',
          nextNodeId: 'focus_dynamic',
        ),
        CoachingOption(
          text: 'Isolate my attention flaws',
          nextNodeId: 'focus_followup',
        ),
      ],
    ),

    'focus_dynamic': CoachingNode(
      id: 'focus_dynamic',
      fairyMessage: [
        'Focus isn\'t about forcing raw concentration; it\'s about ruthlessly eliminating internal and external friction. Your environment dictates your attention.',
        'Your attention is like a beam of light. It can illuminate your path or scatter into a million directions. The key to mastering focus is learning how to direct that beam with precision and intention.',
        'In the age of endless digital distractions, your ability to focus is like a rare cosmic gem. It requires intentional cultivation and protection from the noise that seeks to fragment it.',
        'The quality of your focus is directly tied to the quality of your environment. Just like a plant needs the right soil and light to thrive, your attention needs the right conditions to flourish. Let\'s optimize your environment for deep focus.',
        'Your attention is a powerful force, but it can also be easily hijacked by low-value loops and distractions. It\'s like trying to hold onto stardust - the more you try to grasp it tightly, the more it slips through your fingers. Let\'s learn how to gently hold and guide your attention instead.',
        'Your focus is like a beam of starlight cutting through the cosmic darkness.',
        'In a universe full of noise, focus is your superpower—it is the lens that directs your light.',
        'Focus is the cosmic glue that binds your intentions to your actions.',
        'Focus is the cosmic compass that guides you through the vast expanse of possibilities.',
        'Focus is the cosmic lens that brings your goals into sharp clarity.',
        'Focus is the cosmic engine that propels you towards your dreams.',
        'Focus is the cosmic anchor that keeps you grounded amidst the chaos.',
        'Focus is the cosmic key that unlocks your potential and opens doors to new dimensions of achievement.',
        'Focus is the cosmic force that transforms your aspirations into reality.',
        'Focus is the cosmic rhythm that synchronizes your efforts with the flow of the universe.',
      ],
      options: [
        CoachingOption(
          text: 'Let\'s optimize it',
          nextNodeId: 'focus_followup',
        ),
      ],
    ),

    'focus_followup': CoachingNode(
      id: 'focus_followup',
      fairyMessage: 'Where does your beam of attention usually break down?',
      options: [
        CoachingOption(
          text: 'Initiating: Actually starting a task',
          nextNodeId: 'focus_followup_dynamic',
        ),
        CoachingOption(
          text: 'Sustaining: Staying on it once started',
          nextNodeId: 'focus_followup_dynamic',
        ),
      ],
    ),

    'focus_followup_dynamic': CoachingNode(
      id: 'focus_followup_dynamic',
      fairyMessage: [
        'Energy flows where attention goes. Mastering your deep focus means safeguarding your morning and deep-work blocks from low-value loops.',
        'Your attention is a powerful force, but it can also be easily hijacked by low-value loops and distractions. It\'s like trying to hold onto stardust - the more you try to grasp it tightly, the more it slips through your fingers. Let\'s learn how to gently hold and guide your attention instead.',
        'The quality of your focus is directly tied to the quality of your environment. Just like a plant needs the right soil and light to thrive, your attention needs the right conditions to flourish. Let\'s optimize your environment for deep focus.',
        'In a universe full of endless digital distractions, your ability to focus is like a rare cosmic gem. It requires intentional cultivation and protection from the noise that seeks to fragment it.',
        'Your environment dictates your attention.',
      ],
      options: [
        CoachingOption(text: 'Lock it in', nextNodeId: 'fact_dynamic'),
        CoachingOption(
          text: 'I\'m still searching for clarity',
          nextNodeId: 'not_sure_dynamic',
        ),
      ],
    ),

    // --- NOT SURE / GENERAL UTILITY BRANCH ---
    'not_sure_dynamic': CoachingNode(
      id: 'not_sure_dynamic',
      fairyMessage: [
        'That\'s completely fine. Sometimes clarity isn\'t found through thinking, but through a tiny, practical physical experiment. Where should we start tomorrow?',
        'When you\'re not sure where to start, the best thing you can do is take a small action that creates a powerful feedback loop. It\'s like throwing a pebble into a pond and watching the ripples unfold. What small action can you take tomorrow to create some momentum?',
        'That\'s okay. Sometimes the best way to find clarity is to take a small step and see how it feels. It\'s like exploring a new planet - you have to take a few steps on the surface to really understand the terrain. What small step can you take tomorrow to start exploring?',
      ],
      options: [
        CoachingOption(
          text: 'A 5-minute mental reset',
          nextNodeId: 'meditation_dynamic',
        ),
        CoachingOption(
          text: 'Physical exertion and movement',
          nextNodeId: 'exercise_dynamic',
        ),
      ],
    ),

    'meditation_dynamic': CoachingNode(
      id: 'meditation_dynamic',
      fairyMessage: [
        'Meditation is a literal cosmic reset button for an overheated processor. Even just 5 minutes cuts the noise. Let\'s claim that stillness.',
        'The beauty of meditation is that it creates a powerful feedback loop of calm. The more you practice, the easier it becomes to access that state of presence and clarity, even in the midst of chaos.',
        'Science shows that meditation can significantly reduce symptoms of anxiety and depression, improve focus, and even increase gray matter in the brain. It\'s like a superpower for your mental well-being.',
        'The great philosopher Lao Tzu said, "To the mind that is still, the whole universe surrenders." By cultivating a still mind through meditation, you\'re opening yourself up to the infinite possibilities of the cosmos.',
        'Meditation is not about escaping reality; it\'s about fully embracing it with a clear and calm mind. It\'s like cleaning the lens through which you view the world, allowing you to see things as they truly are.',
        'The cosmic mirror reflects not just what is, but what can be. By taking care of your inner space with meditation, you\'re not just surviving the stormy weather; you\'re learning to dance in the rain and even find beauty in it. Let\'s cultivate that resilience together.',
      ],
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    'exercise_dynamic': CoachingNode(
      id: 'exercise_dynamic',
      fairyMessage: [
        'Movement is like fueling a rocket engine. It flushes cortisol and completely recalibrates your cognitive chemistry. What type of physical expression calls to you?',
        'When your mental space feels crowded, sometimes the best thing you can do is move your body. Exercise is like a cosmic reset button that can help clear the mental fog and create a powerful feedback loop of calm and focus.',
        'Science shows that physical activity can significantly reduce symptoms of anxiety and depression, improve sleep quality, and boost overall mood. It\'s like a natural mood booster that floods your system with endorphins and helps clear the mental fog.',
        'The great philosopher Friedrich Nietzsche said, "That which does not kill us makes us stronger." By pushing your physical limits through exercise, you\'re not just strengthening your body; you\'re cultivating a sharper, more resilient mind.',
        'When you push your physical limits, it creates a powerful feedback loop that can help break the cycle of overthinking. The intense focus required during exercise can help redirect your mental energy and provide a much-needed release from racing thoughts.',
        'The beauty of exercise is that it demands your full attention. It\'s like a cosmic reset button that forces your mind to drop all distractions and focus solely on the physical sensations of the moment.',
      ],
      options: [
        CoachingOption(
          text: 'A brisk, meditative walk',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'Flow and deep yoga stretches',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'A high-intensity, heavy-duty workout',
          nextNodeId: 'workout_dynamic',
        ),
      ],
    ),

    'workout_dynamic': CoachingNode(
      id: 'workout_dynamic',
      fairyMessage: [
        'Pushing your physical limits forces absolute presence. When you challenge your muscles heavy and deep, there is zero room for mental worry. Your mind clears out of pure necessity.',
        'The beauty of a heavy workout is that it demands your full attention. It\'s like a cosmic reset button that forces your mind to drop all distractions and focus solely on the physical sensations of the moment.',
        'When you push your physical limits, it creates a powerful feedback loop that can help break the cycle of overthinking. The intense focus required during a heavy workout can help redirect your mental energy and provide a much-needed release from racing thoughts.',
        'Science shows that high-intensity exercise can significantly reduce symptoms of anxiety and depression. It\'s like a natural mood booster that floods your system with endorphins and helps clear the mental fog.',
        'Mike Tyson once said, "Everyone has a plan until they get punched in the mouth." A heavy workout is like a controlled punch to your system that can help you break through mental barriers and find clarity in the chaos.',
        'The great Bruce Lee emphasized the importance of physical fitness for mental clarity, saying, "A fit body, a calm mind, a house full of love. These things cannot be bought – they must be earned." By pushing your physical limits, you\'re not just strengthening your body; you\'re cultivating a sharper, more resilient mind.',
      ],
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    // --- THE CENTRAL CORE PIPELINE ---
    'fact_dynamic': CoachingNode(
      id: 'fact_dynamic',
      fairyMessage: [
        'Did you know that research shows deliberately slowing down your audio or environmental stimuli can reduce active stress biomarkers by up to 40%? Imagine yourself floating weightless in a serene cosmic expanse.',
        'Science shows that even a brief evening ritual can significantly improve sleep quality and reduce stress. It\'s like setting a cosmic alarm clock for your nervous system. What small ritual can you commit to tonight?',
        'Dr. Andrew Huberman, a renowned neuroscientist, emphasizes the importance of light exposure in regulating our circadian rhythms. Dimming the lights and reducing screen time in the evening can help signal to your brain that it\'s time to wind down. Let\'s create a sleep-friendly environment together.',
        'The ancient practice of mindfulness meditation is like a cosmic anchor for your wandering thoughts. Just a few minutes of focused breathing can create a ripple effect of calm throughout your entire system. Let\'s claim that stillness tonight.',
        'Philosopher Alan Watts said, "To the mind that is still, the whole universe surrenders." By cultivating a still mind through meditation, you\'re opening yourself up to the infinite possibilities of the cosmos.',
        'The cosmic mirror reflects not just what is, but what can be. By taking care of your inner space, you\'re not just surviving the stormy weather; you\'re learning to dance in the rain and even find beauty in it. Let\'s cultivate that resilience together.',
        'When you feel mentally overwhelmed, it\'s like being caught in a cosmic storm. But remember, even the fiercest storms eventually pass, and they often leave behind clearer skies and brighter stars. Let\'s weather this together and find the calm on the other side.',
        'Your mind is a powerful tool, but it can also be a tricky one to manage. It\'s like trying to hold onto stardust - the more you try to grasp it tightly, the more it slips through your fingers. Let\'s learn how to gently hold and guide your thoughts instead.',
        'The journey to mental well-being is not a straight path; it\'s more like navigating through a complex galaxy. There will be twists, turns, and unexpected discoveries along the way. Let\'s embrace the adventure together and find the stars that guide you to a calmer, clearer mind.',
        'Remember, even the most brilliant stars need darkness to shine. When your mental space feels overwhelming, it\'s a sign that you\'re on the verge of a breakthrough. Let\'s harness that energy and turn it into a supernova of calm and focus.',
        'A research study published in the Journal of Positive Psychology found that people who wrote down three good things that happened each day for a week reported significantly higher levels of happiness and lower levels of depressive symptoms. It\'s like planting seeds of positivity in the fertile soil of your mind.',
        'The great philosopher Seneca said, "We suffer more often in imagination than in reality." By reflecting on the positive aspects of your day, you\'re training your mind to focus on the good and reduce the power of negative thoughts. Let\'s cultivate that mindset together.',
        'Gratitude is like a cosmic magnet that attracts more of what you appreciate into your life. By taking a moment to acknowledge the good, you\'re creating a powerful feedback loop of positivity that can help shift your overall perspective and mood.',
        'The cosmic mirror reflects not just what is, but what can be. By focusing on the positive aspects of your day, you\'re not just surviving the stormy weather; you\'re learning to dance in the rain and even find beauty in it. Let\'s cultivate that resilience together.',
        'When you focus on the good, it\'s like turning on a light in a dark room. The more you look for the positive, the more it illuminates your perspective and helps you find your way through challenges.',
      ],
      options: [CoachingOption(text: 'Tap to continue', nextNodeId: 'breathe')],
    ),

    'breathe': CoachingNode(
      id: 'breathe',
      fairyMessage:
          'Just a few intentional, deep expansions can completely drop your heart rate and ground your nervous system. Let\'s take a slow breath together.',
      options: [
        CoachingOption(
          text: 'I\'ve taken a breath',
          nextNodeId: 'input_dynamic',
        ),
      ],
    ),

    'input_dynamic': CoachingNode(
      id: 'input_dynamic',
      fairyMessage: [
        'What is the single most vital intention or perspective you want to transition into your orbit tomorrow?',
        'If you could set a single, powerful intention for tomorrow that would guide your actions and mindset, what would it be?',
        'What is one small but powerful perspective or intention you want to carry with you into tomorrow?',
        'If you could plant a single seed of intention in the fertile soil of tomorrow, what would it be?',
        'What is one powerful intention or mindset you want to anchor into your day tomorrow?',
        'If you could choose one guiding star to navigate by tomorrow, what would it be?',
        'What is one small but impactful intention you want to set for yourself tomorrow?',
        'If you could distill your aspirations for tomorrow into a single, guiding intention, what would it be?',
        'What is one powerful perspective or intention you want to carry with you into tomorrow to help you navigate the challenges and opportunities that come your way?',
        'If you could choose one guiding principle to live by tomorrow, what would it be?',
      ],
      isInput: true,
    ),

    'done_dynamic': CoachingNode(
      id: 'done_dynamic',
      fairyMessage: [
        'Beautifully anchored. Today you set out to "[INTENTION]". Your orbit is secure, and your trajectory is clear. Rest deeply, Commander.',
        //   'Your cosmic mirror reflects not just what is, but what can be. By taking care of your inner space, you\'re not just surviving the stormy weather; you\'re learning to dance in the rain and even find beauty in it. Rest well and wake ready to dance again tomorrow.',
        //   'When you feel mentally overwhelmed, it\'s like being caught in a cosmic storm. But remember, even the fiercest storms eventually pass, and they often leave behind clearer skies and brighter stars. Rest well tonight, knowing that calm is on the other side.',
        //   'Your mind is a powerful tool, but it can also be a tricky one to manage. It\'s like trying to hold onto stardust - the more you try to grasp it tightly, the more it slips through your fingers. By gently holding and guiding your thoughts tonight, you\'re setting yourself up for a calmer, clearer mind tomorrow. Rest well, Cosmic Navigator.',
        //   'The journey to mental well-being is not a straight path; it\'s more like navigating through a complex galaxy. There will be twists, turns, and unexpected discoveries along the way. By embracing this adventure and finding the stars that guide you to a calmer, clearer mind tonight, you\'re preparing for an even more enlightening journey tomorrow. Rest well, Cosmic Explorer.',
        //   'Remember, even the most brilliant stars need darkness to shine. When your mental space feels overwhelming, it\'s a sign that you\'re on the verge of a breakthrough. By harnessing that energy and turning it into a supernova of calm and focus tonight, you\'re setting yourself up for an even brighter tomorrow. Rest well, Cosmic Star.',
      ],
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };

  // --- LIFECYCLE METHODS ---

  @override
  void initState() {
    super.initState();
    _setupSession();
    _playHypnoticAudio();
  }

  Future<void> _playHypnoticAudio() async {
    try {
      _hypnoticAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _hypnoticAudioPlayer.setVolume(0.0);
      if (!mounted) return;

      await _hypnoticAudioPlayer.play(AssetSource('audio/hypnotic_loop.mp3'));
      if (!mounted) return;

      _fadeAudio(0.0, 0.3, const Duration(seconds: 2));
    } catch (e) {
      debugPrint("Hypnotic audio player interrupted: $e");
    }
  }

  Future<void> _fadeAudio(double start, double end, Duration duration) async {
    const int steps = 20;
    final stepDuration = duration ~/ steps;
    final volumeStep = (end - start) / steps;

    for (int i = 1; i <= steps; i++) {
      if (!mounted) return;
      final currentVolume = start + (volumeStep * i);
      await _hypnoticAudioPlayer.setVolume(currentVolume);
      await Future.delayed(stepDuration);
    }
  }

  Future<void> _handleExit() async {
    await _fadeAudio(0.3, 0.0, const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _setupSession() {
    // Select tree based on type
    if (widget.sessionType == 'daily') {
      _currentTree = _dailyTree;
    } else if (widget.sessionType == 'workday') {
      _currentTree = _workdayTree;
    } else {
      _currentTree = _nightlyTree;
    }

    _routineProvider = context.read<RoutineProvider>();
    if (!_routineProvider.isPlayingAmbient) {
      _routineProvider.toggleAmbientAudio();
    }
  }

  @override
  void dispose() {
    _hypnoticAudioPlayer.dispose();
    if (_routineProvider.isPlayingAmbient) {
      _routineProvider.stopAmbientAudio();
    }
    _noteController.dispose();
    super.dispose();
  }

  void _advanceNode(String nextId) {
    HapticFeedback.lightImpact();
    if (nextId == 'exit') {
      _handleExit();
      return;
    }
    setState(() {
      _currentNodeId = nextId;
    });
  }

  Future<void> _submitNote() async {
    HapticFeedback.heavyImpact();
    final noteText = _noteController.text.trim();

    if (noteText.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('coaching_notes')
              .add({
                // Slice it to max 2000 chars to guarantee it passes our strict Firestore rules
                'text': noteText.substring(0, min(noteText.length, 2000)),
                'createdAt': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          debugPrint('Error saving coaching note: $e');
        }
      }
    }

    _noteController.clear();
    _advanceNode('done_dynamic');
  }

  @override
  Widget build(BuildContext context) {
    final currentNode = _currentTree[_currentNodeId]!;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. STUNNING BACKGROUND
            Positioned.fill(
              child: Image.asset(
                'assets/images/deep_nebula.png', // Ensure you have a nice space background here
                fit: BoxFit.cover,
              ).animate().fade(duration: 2.seconds),
            ),

            // 2. DARK OVERLAY FOR READABILITY
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

            // 3. EXIT BUTTON
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _handleExit,
              ).animate().fade(duration: 2.seconds, curve: Curves.easeOut),
            ),

            // 4. TITLE
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child:
                    Text(
                          '${widget.sessionType.toUpperCase()} COACHING',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 3.0,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        .animate()
                        .fade(duration: 2.seconds, curve: Curves.easeOut)
                        .slideY(
                          begin: -0.5,
                          duration: 2.seconds,
                          curve: Curves.easeOut,
                        ),
              ),
            ),

            // 5. INTERACTIVE BOTTOM SECTION
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 40.0,
                  left: 24.0,
                  right: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- FAIRY AVATAR ---
                    Align(
                      alignment: Alignment.center,
                      child:
                          Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00E5FF,
                                      ).withValues(alpha: 0.35),
                                      blurRadius: 40,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00E5FF,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 80,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/fairy_avatar_flip.png',
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                begin: -35,
                                end: -15,
                                duration: 3.seconds,
                                curve: Curves.easeInOut,
                              ),
                    ),
                    // --- CHAT BUBBLE ---
                    // SizedBox with negative height is invalid (BoxConstraints h >= 0).
                    // Use Transform.translate to achieve the same visual overlap without
                    // violating layout constraints.
                    Transform.translate(
                      offset: const Offset(0, -10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.cyan.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cosmica',
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                      currentNode.fairyMessages.isEmpty
                                          ? ''
                                          : currentNode.displayMessage
                                                .replaceAll(
                                                  '[INTENTION]',
                                                  _routineProvider
                                                          .dailyIntention ??
                                                      'master your day',
                                                ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                    .animate()
                                    .fade(duration: 400.ms)
                                    .moveY(begin: 10, end: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- DYNAMIC OPTIONS OR INPUT ---
                    if (currentNode.isInput)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _noteController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Type your reflection here...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Color(0xFF00E5FF),
                              ),
                              onPressed: _submitNote,
                            ),
                          ),
                        ),
                      ).animate().fade().scale()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: currentNode.options.map((option) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF1A1F36,
                                ).withValues(alpha: 0.6),

                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () => _advanceNode(option.nextNodeId),
                              child: Text(
                                option.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ).animate().fade(duration: 400.ms).slideY(begin: 0.5);
                        }).toList(),
                      ),
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
