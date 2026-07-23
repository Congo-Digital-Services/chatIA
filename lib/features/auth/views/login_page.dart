import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/backend_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/auth_state_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isRegisterMode = false;
  ProviderSubscription<AuthController>? _authSubscription;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _confirmPasswordController;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _lastErrorToast;
  String? _lastInfoToast;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController(text: BackendConfig.authEmail);
    _passwordController = TextEditingController(
      text: BackendConfig.authPassword,
    );
    _confirmPasswordController = TextEditingController();
    _authSubscription = ref.listenManual<AuthController>(
      authControllerProvider,
      (_, next) {
        final hasNewError =
            next.errorMessage != null &&
            next.errorMessage!.isNotEmpty &&
            _lastErrorToast != next.errorMessage;
        if (hasNewError && mounted) {
          _lastErrorToast = next.errorMessage;
          showAppToast(
            context,
            message: next.errorMessage!,
            type: AppToastType.error,
          );
        }

        final hasNewInfo =
            next.infoMessage != null &&
            next.infoMessage!.isNotEmpty &&
            _lastInfoToast != next.infoMessage;
        if (hasNewInfo && mounted) {
          _lastInfoToast = next.infoMessage;
          showAppToast(
            context,
            message: next.infoMessage!,
            type: AppToastType.success,
          );
        }

        final registrationCompleted =
            _isRegisterMode &&
            next.infoMessage != null &&
            next.infoMessage!.isNotEmpty &&
            _lastInfoToast == next.infoMessage;
        if (!registrationCompleted || !mounted) {
          return;
        }

        setState(() {
          _isRegisterMode = false;
          _nameController.clear();
          _usernameController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _obscurePassword = true;
          _obscureConfirmPassword = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    if (auth.errorMessage == null) {
      _lastErrorToast = null;
    }
    if (auth.infoMessage == null) {
      _lastInfoToast = null;
    }

    // Écran de restauration de session
    if (auth.isRestoring) {
      return Scaffold(
        backgroundColor: AppThemeColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppThemeColors.accent,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                'Restauration de session…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: AppThemeColors.shellGradient),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: -80,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppThemeColors.accent.withValues(alpha: 0.18),
                    AppThemeColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ctaSpacing = (constraints.maxHeight * 0.22).clamp(
                  32.0,
                  220.0,
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.09),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: AppThemeColors.surface.withValues(
                              alpha: 0.82,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppThemeColors.stroke),
                            boxShadow: AppThemeShadows.soft,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/icons/congo_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ChatIA',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AppThemeColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Une messagerie IA claire, rapide et moderne\npour vos échanges avec LibreChat.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppThemeColors.textSoft,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: (ctaSpacing * 0.35).toDouble()),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppThemeColors.surface.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppThemeColors.stroke),
                            boxShadow: AppThemeShadows.medium,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isRegisterMode
                                    ? 'Créer un compte'
                                    : 'Connexion',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppThemeColors.textStrong,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isRegisterMode
                                    ? 'Rejoignez l’espace de travail et commencez à discuter.'
                                    : 'Connectez-vous pour reprendre vos conversations.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppThemeColors.textSoft,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_isRegisterMode) ...[
                                _AuthTextField(
                                  controller: _nameController,
                                  hintText: 'Nom complet',
                                  enabled: !auth.isLoading,
                                ),
                                const SizedBox(height: 12),
                                _AuthTextField(
                                  controller: _usernameController,
                                  hintText: 'Nom d’utilisateur',
                                  enabled: !auth.isLoading,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _AuthTextField(
                                controller: _emailController,
                                hintText: 'Adresse e-mail',
                                keyboardType: TextInputType.emailAddress,
                                enabled: !auth.isLoading,
                              ),
                              const SizedBox(height: 12),
                              _AuthTextField(
                                controller: _passwordController,
                                hintText: 'Mot de passe',
                                obscureText: _obscurePassword,
                                enabled: !auth.isLoading,
                                suffixIcon: IconButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppThemeColors.textMuted,
                                  ),
                                ),
                              ),
                              if (_isRegisterMode) ...[
                                const SizedBox(height: 12),
                                _AuthTextField(
                                  controller: _confirmPasswordController,
                                  hintText: 'Confirmer le mot de passe',
                                  obscureText: _obscureConfirmPassword,
                                  enabled: !auth.isLoading,
                                  suffixIcon: IconButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () => setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          }),
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppThemeColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: (ctaSpacing * 0.18).toDouble()),
                              _LoginButton(
                                isLoading: auth.isLoading,
                                label: _isRegisterMode
                                    ? 'Créer un compte'
                                    : 'Continuer',
                                loadingLabel: _isRegisterMode
                                    ? 'Inscription en cours…'
                                    : 'Connexion en cours…',
                                onTap: auth.isLoading
                                    ? null
                                    : () {
                                        if (_isRegisterMode &&
                                            _passwordController.text !=
                                                _confirmPasswordController
                                                    .text) {
                                          ref
                                              .read(authControllerProvider)
                                              .setErrorMessage(
                                                'Les mots de passe ne correspondent pas.',
                                              );
                                          return;
                                        }
                                        if (_isRegisterMode) {
                                          ref
                                              .read(authControllerProvider)
                                              .register(
                                                name: _nameController.text
                                                    .trim(),
                                                username: _usernameController
                                                    .text
                                                    .trim(),
                                                email: _emailController.text
                                                    .trim(),
                                                password:
                                                    _passwordController.text,
                                                confirmPassword:
                                                    _confirmPasswordController
                                                        .text,
                                              );
                                          return;
                                        }
                                        ref
                                            .read(authControllerProvider)
                                            .signIn(
                                              email: _emailController.text
                                                  .trim(),
                                              password:
                                                  _passwordController.text,
                                            );
                                      },
                              ),
                              const SizedBox(height: 18),
                              _AuthFooterLink(
                                isRegisterMode: _isRegisterMode,
                                enabled: !auth.isLoading,
                                onToggle: () => setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                  _obscurePassword = true;
                                  _obscureConfirmPassword = true;
                                  ref
                                      .read(authControllerProvider)
                                      .clearMessages();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFooterLink extends StatelessWidget {
  const _AuthFooterLink({
    required this.isRegisterMode,
    required this.enabled,
    required this.onToggle,
  });

  final bool isRegisterMode;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppThemeColors.textSoft);
    final actionStyle = baseStyle?.copyWith(
      color: enabled ? AppThemeColors.textStrong : AppThemeColors.textMuted,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isRegisterMode
                ? 'Vous avez déjà un compte ? '
                : 'Vous n\'avez pas encore de compte ? ',
            style: baseStyle,
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: enabled ? onToggle : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isRegisterMode ? 'Connectez-vous' : 'Inscrivez-vous',
              style: actionStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: !obscureText,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: AppThemeColors.textStrong),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppThemeColors.textMuted),
        filled: true,
        fillColor: AppThemeColors.backgroundSoft.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppThemeColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppThemeColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppThemeColors.accent),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.isLoading,
    required this.onTap,
    required this.label,
    required this.loadingLabel,
  });

  final bool isLoading;
  final VoidCallback? onTap;
  final String label;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: secondaryColor,
                  strokeWidth: 2,
                ),
              )
            else ...[
              Text(
                label,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: secondaryColor,
                size: 18,
              ),
            ],
            if (isLoading) ...[
              const SizedBox(width: 10),
              Text(
                loadingLabel,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
