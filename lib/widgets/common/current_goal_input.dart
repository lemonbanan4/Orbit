import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CurrentGoalInput extends StatefulWidget {
  final String initialGoal;
  final String uid;

  const CurrentGoalInput({
    super.key,
    required this.initialGoal,
    required this.uid,
  });

  @override
  State<CurrentGoalInput> createState() => _CurrentGoalInputState();
}

class _CurrentGoalInputState extends State<CurrentGoalInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGoal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: 'What is your main goal for today?',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: const Icon(
          Icons.track_changes_rounded,
          color: Color(0xFF00E5FF),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (val) {
        FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
          'currentGoal': val.trim(),
        }, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal updated! 🎯'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }
}
