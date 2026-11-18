import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_dialogs.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillDefaultCredentials() {
    setState(() {
      _usernameController.text = 'OMMAVTAR36';
      _passwordController.text = 'OMMAVTAR36';
      _errorMessage = null;
    });
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both username and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.login(username, password);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid username or password. Use: OMMAVTAR36 / OMMAVTAR36';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    const Color(0xFF090D16),
                  ]
                : [
                    const Color(0xFFF1F5F9),
                    const Color(0xFFE2E8F0),
                    const Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: isDark ? 4 : 8,
                shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.25 : 0.15),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 24 : 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LOGO & APP BRANDING
                      Center(
                        child: Column(
                          children: [
                            const AppLogoWidget(
                              size: 72,
                              borderRadius: 18,
                              showEditBadge: false,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              provider.companyName.isNotEmpty
                                  ? provider.companyName
                                  : 'OM MAVTAR GROUP',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              provider.companyTagline.isNotEmpty
                                  ? provider.companyTagline
                                  : 'Khata Book Desktop & Mobile System',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.75),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ERROR BANNER
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.warningBgDark.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.warningBorder.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.warningText,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warningText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // USERNAME FIELD
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter username (OMMAVTAR36)',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PASSWORD FIELD
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password (OMMAVTAR36)',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            tooltip: _obscurePassword ? 'Show Password' : 'Hide Password',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // SIGN IN BUTTON
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign In to Dashboard',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                      ),
                      const SizedBox(height: 20),

                      // DEFAULT CREDENTIALS HELPER BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DEFAULT CREDENTIALS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'OMMAVTAR36  /  OMMAVTAR36',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.flash_on, size: 16),
                              label: const Text('Auto-Fill', style: TextStyle(fontSize: 12)),
                              onPressed: _fillDefaultCredentials,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

