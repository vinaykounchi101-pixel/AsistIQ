import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';

class _RoleOption {
  final String roleKey;
  final String title;
  final String subtitle;
  final String emailSuffix;
  final IconData icon;

  const _RoleOption({
    required this.roleKey,
    required this.title,
    required this.subtitle,
    required this.emailSuffix,
    required this.icon,
  });
}

const List<_RoleOption> _roleOptions = [
  _RoleOption(
    roleKey: 'Requester',
    title: 'Requester',
    subtitle: 'Self-Service Incident & Request Hub',
    emailSuffix: '_requester@asistiq.com',
    icon: Icons.person_outline_rounded,
  ),
  _RoleOption(
    roleKey: 'Operator',
    title: 'Operator',
    subtitle: 'Ticket Workbench & SLA Resolution',
    emailSuffix: '_operator@asistiq.com',
    icon: Icons.build_circle_outlined,
  ),
  _RoleOption(
    roleKey: 'TeamLead',
    title: 'Team Lead',
    subtitle: 'Command Center & Escalation Watch',
    emailSuffix: '_lead@asistiq.com',
    icon: Icons.military_tech_outlined,
  ),
  _RoleOption(
    roleKey: 'Manager',
    title: 'Manager',
    subtitle: 'Operational Insights & AI Analytics',
    emailSuffix: '_manager@asistiq.com',
    icon: Icons.insights_outlined,
  ),
  _RoleOption(
    roleKey: 'Administrator',
    title: 'Administrator',
    subtitle: 'Governance & Infrastructure Telemetry',
    emailSuffix: '_admin@asistiq.com',
    icon: Icons.admin_panel_settings_outlined,
  ),
];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isRegistering = false;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  // Register controllers
  final _fullNameController = TextEditingController();
  final _initialsController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  int _selectedRoleIndex = 0;
  bool _initialsManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _fullNameController.addListener(_handleFullNameChanged);
    _initialsController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _initialsController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleFullNameChanged() {
    if (!_initialsManuallyEdited) {
      final name = _fullNameController.text.trim();
      if (name.isEmpty) {
        _initialsController.text = '';
      } else {
        final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        String initials = '';
        if (parts.length == 1) {
          initials = parts[0].substring(0, parts[0].length.clamp(1, 3)).toLowerCase();
        } else {
          initials = parts.take(3).map((p) => p[0].toLowerCase()).join();
        }
        _initialsController.text = initials;
      }
    }
    setState(() {});
  }

  String get _constructedEmail {
    final initials = _initialsController.text.trim().toLowerCase();
    final cleanInitials = initials.isEmpty ? 'initials' : initials.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final suffix = _roleOptions[_selectedRoleIndex].emailSuffix;
    return '$cleanInitials$suffix';
  }

  Future<void> _handleLogin() async {
    if (_loginFormKey.currentState?.validate() ?? false) {
      await ref.read(authNotifierProvider.notifier).login(
            _loginEmailController.text,
            _loginPasswordController.text,
          );
    }
  }

  Future<void> _handleRegister() async {
    if (_registerFormKey.currentState?.validate() ?? false) {
      final selectedRole = _roleOptions[_selectedRoleIndex];
      final email = _constructedEmail;
      await ref.read(authNotifierProvider.notifier).register(
            email: email,
            password: _registerPasswordController.text,
            fullName: _fullNameController.text,
            role: selectedRole.roleKey,
          );
    }
  }

  void _fillDemoCredentials(String email) {
    setState(() {
      _isRegistering = false;
      _loginEmailController.text = email;
      _loginPasswordController.text = 'Password123!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _isRegistering ? 560 : 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: const BorderSide(color: AppColors.borderLight, width: 1),
              ),
              color: AppColors.surfaceLight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isRegistering ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: _buildLoginForm(context, authState),
                  secondChild: _buildRegisterForm(context, authState),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required String title, required String subtitle}) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primarySolid.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: AppSpacing.paddingAllMd,
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.pastelRoseBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.pastelRose),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.pastelRoseText, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // --- SIGN IN VIEW ---
  Widget _buildLoginForm(BuildContext context, AuthState authState) {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(
            title: 'Welcome to AsistIQ',
            subtitle: 'AI-Assisted IT Helpdesk & SLA Engine',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (authState.status == AuthStatus.error && authState.errorMessage != null && !_isRegistering)
            _buildErrorMessage(authState.errorMessage!),
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'e.g. user_role@asistiq.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!val.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleLogin,
            child: authState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Sign In'),
          ),
          const SizedBox(height: AppSpacing.md),
          // Switch to Register button
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = true;
                  });
                },
                child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.borderLight),
          // Demo Persona Quick-Fill Chips
          Text(
            'FAST DEMO PERSONAS (PASSWORD: Password123!)',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMutedLight, letterSpacing: 0.8),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _buildDemoChip('Admin', 'admin@paradox.com'),
              _buildDemoChip('Manager', 'manager@paradox.com'),
              _buildDemoChip('Lead', 'lead@paradox.com'),
              _buildDemoChip('Operator', 'operator@paradox.com'),
              _buildDemoChip('Requester', 'requester@paradox.com'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChip(String label, String email) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.backgroundLight,
      side: const BorderSide(color: AppColors.borderLight),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => _fillDemoCredentials(email),
    );
  }

  // --- REGISTER VIEW ---
  Widget _buildRegisterForm(BuildContext context, AuthState authState) {
    final selectedRole = _roleOptions[_selectedRoleIndex];

    return Form(
      key: _registerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(
            title: 'Create an Account',
            subtitle: 'Select your role and customize your organizational identity',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (authState.status == AuthStatus.error && authState.errorMessage != null && _isRegistering)
            _buildErrorMessage(authState.errorMessage!),

          // 1. Full Name
          TextFormField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g. Vinay Kounchi',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Full Name is required';
              if (val.trim().length < 2) return 'Enter a valid name';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),

          // 2. Select Role Bento Cards Header
          Row(
            children: [
              const Icon(Icons.workspaces_outlined, size: 16, color: AppColors.primarySolid),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'SELECT YOUR ROLE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Role Bento Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isCompact ? 1 : 2,
                  childAspectRatio: isCompact ? 3.8 : 2.5,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: _roleOptions.length,
                itemBuilder: (context, index) {
                  final opt = _roleOptions[index];
                  final isSelected = index == _selectedRoleIndex;
                  return _buildRoleCard(opt, isSelected, () {
                    setState(() {
                      _selectedRoleIndex = index;
                    });
                  });
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.base),

          // 3. Employee Initials & Locked Email Construction Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.pastelSkyBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.pastelSky),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alternate_email_rounded, size: 16, color: AppColors.pastelSkyText),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'ORGANIZATIONAL EMAIL (ROLE ENFORCED)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pastelSkyText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    // Initials input
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _initialsController,
                        onChanged: (_) => _initialsManuallyEdited = true,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarySolid,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                          labelText: 'Initials',
                          hintText: 'vk',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            borderSide: const BorderSide(color: AppColors.borderLight),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Locked suffix badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 14, color: AppColors.textMutedLight),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                selectedRole.emailSuffix,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Full Login Address: $_constructedEmail',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.pastelSkyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // 4. Password & Confirm Password
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 360;
              if (isStacked) {
                return Column(
                  children: [
                    TextFormField(
                      controller: _registerPasswordController,
                      obscureText: _obscureRegisterPassword,
                      style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Min 8 chars',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Password required';
                        if (val.length < 8) return 'Min 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Confirm password';
                        if (val != _registerPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _registerPasswordController,
                      obscureText: _obscureRegisterPassword,
                      style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Min 8 chars',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Password required';
                        if (val.length < 8) return 'Min 8 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Confirm',
                        hintText: 'Re-enter password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Confirm password';
                        if (val != _registerPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // 5. Submit Registration
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleRegister,
            child: authState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Create ${selectedRole.title} Account & Sign In'),
          ),
          const SizedBox(height: AppSpacing.md),

          // Switch back to Login
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = false;
                  });
                },
                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(_RoleOption opt, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primarySolid : AppColors.borderLight,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primarySolid.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySolid : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                opt.icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.primarySolid : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    opt.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? AppColors.primaryNavy : AppColors.textMutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 16, color: AppColors.primarySolid),
          ],
        ),
      ),
    );
  }
}
