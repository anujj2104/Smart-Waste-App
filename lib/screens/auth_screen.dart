import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text);
        await db.doc('users/${cred.user!.uid}').set({
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'role': 'citizen', // admins/drivers are promoted from the console
          'points': 0,
        });
      } else {
        await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) snack(context, e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(children: [
                const Icon(Icons.recycling, size: 80, color: Colors.green),
                const Text('Smart Waste',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (_register) ...[
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name')),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone')),
                ],
                TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email')),
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_register ? 'Create account' : 'Login')),
                TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register
                        ? 'Have an account? Login'
                        : 'New here? Register')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
