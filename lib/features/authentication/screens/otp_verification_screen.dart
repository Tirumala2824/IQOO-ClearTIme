import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../../parent/controllers/parent_dashboard_controller.dart';
import '../../child/controllers/child_dashboard_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? displayName;

  const OtpVerificationScreen({super.key, this.displayName});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  int _secondsRemaining = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _otpController.text.trim();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.verifyOtp(
      token: token,
      displayName: widget.displayName,
    );

    if (success && mounted) {
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        if (user.isParent) {
          await ref
              .read(parentDashboardControllerProvider.notifier)
              .loadDashboard(user.id);
          final parentState = ref.read(parentDashboardControllerProvider);
          if (mounted) {
            if (!parentState.hasFamily) {
              context.go(AppRoutes.onboarding);
            } else {
              context.go(AppRoutes.parent);
            }
          }
        } else {
          await ref
              .read(childDashboardControllerProvider.notifier)
              .loadDashboard(user.id);
          final childState = ref.read(childDashboardControllerProvider);
          if (mounted) {
            if (!childState.hasFamily) {
              context.go(AppRoutes.childJoinFamily);
            } else {
              context.go(AppRoutes.child);
            }
          }
        }
      }
    }
  }

  Future<void> _handleResend() async {
    final phone = ref.read(authControllerProvider).pendingPhone;
    if (phone != null) {
      final success =
          await ref.read(authControllerProvider.notifier).sendPhoneOtp(phone);
      if (success) {
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isParent = authState.isParent;
    final primaryColor =
        isParent ? AppTheme.parentPrimary : AppTheme.childPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Code'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 56,
                  color: primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter 6-digit Code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification code to\n${authState.pendingPhone ?? "your phone number"}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                  ),
                  validator: Validators.validateOtp,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleVerify,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Verify & Continue'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Didn't receive code? "),
                    TextButton(
                      onPressed: _secondsRemaining == 0 && !authState.isLoading
                          ? _handleResend
                          : null,
                      child: Text(
                        _secondsRemaining > 0
                            ? 'Resend in ${_secondsRemaining}s'
                            : 'Resend OTP',
                        style: TextStyle(
                          color: _secondsRemaining == 0
                              ? primaryColor
                              : AppTheme.neutralMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
