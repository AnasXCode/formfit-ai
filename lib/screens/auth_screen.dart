import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      if (_isCanceled(error)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isCanceled(Object error) {
    return error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled;
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) return error.message ?? error.code;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'FormFit AI',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Compete. Count every rep.\nTrain with honest form.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
              const Spacer(flex: 3),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(),
                ),
              PrimaryButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: _busy
                    ? null
                    : () => _run(ref.read(authProvider.notifier).signInWithGoogle),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Continue as Guest',
                icon: Icons.person_outline_rounded,
                onPressed: _busy
                    ? null
                    : () => _run(ref.read(authProvider.notifier).signInAsGuest),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
