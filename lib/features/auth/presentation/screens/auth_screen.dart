import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../domain/entities/user_entity.dart';
import '../../../location/presentation/providers/location_share_provider.dart';
import '../../../location/domain/services/location_share_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _guestUsernameController = TextEditingController();
  
  bool _isLoginMode = true;
  bool _isLoading = false;

  Future<void> _submitAuth() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      if (_isLoginMode) {
        final user = await repo.login(email, password);
        ref.read(authStateProvider.notifier).state = user;
      } else {
        final username = _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : email.split('@').first;
        final user = await repo.signup(email, password, username);
        ref.read(authStateProvider.notifier).state = user;
      }
      // Usually, we can navigate or just let the widget rebuild and show the profile
      // _navigateToMap(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final username = _guestUsernameController.text.trim().isNotEmpty 
          ? _guestUsernameController.text.trim() 
          : 'guest';
          
      final user = await repo.loginAsGuest(username);
      ref.read(authStateProvider.notifier).state = user;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
      ref.read(authStateProvider.notifier).state = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            ),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.explore, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 8),
            Text(
              user != null ? 'PROFILE' : 'AETHERIS',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: _GlowBlob(color: Colors.cyanAccent.withValues(alpha: 0.2), size: 400),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: _GlowBlob(color: Colors.purpleAccent.withValues(alpha: 0.2), size: 350),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
              child: user != null ? _buildProfileView(user, activeSessionsAsync) : _buildAuthForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView(UserEntity user, AsyncValue<List<dynamic>> activeSessionsAsync) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.cyanAccent,
                child: Icon(Icons.person, size: 40, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                user.username ?? 'Explorer',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(
                user.isGuest ? 'Guest Account' : (user.email ?? 'Registered User'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              
              _buildProfileStatRow(Icons.calendar_today, 'Created At', 'Active Now'),
              const SizedBox(height: 16),
              
              if (!user.isGuest) ...[
                activeSessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return _buildProfileStatRow(Icons.share_location, 'Location Shared With', '0 Active');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProfileStatRow(Icons.share_location, 'Location Shared With', '${sessions.length} Active'),
                        const SizedBox(height: 12),
                        ...sessions.map((session) {
                          // The other user's username
                          final otherUsername = session.fromUserId == user.id ? session.toUsername : session.fromUsername;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildSharedUserItem(otherUsername, session.id),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
                  error: (e, st) => Text('Error loading sessions', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
              
              const SizedBox(height: 48),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              else
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ).copyWith(
                    side: WidgetStateProperty.all(BorderSide(color: Colors.redAccent.withValues(alpha: 0.5))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStatRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedUserItem(String username, String sessionId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.purpleAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              ref.read(locationShareServiceProvider).endSession(sessionId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Stopped sharing with $username')),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 30),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Remove', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isLoginMode ? 'Welcome Back' : 'Create Account',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Elevate your cartographic experience',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              
              if (!_isLoginMode) ...[
                _buildLabel('USERNAME'),
                _buildTextField(
                  controller: _usernameController,
                  icon: Icons.person,
                  hint: 'explorer99',
                ),
                const SizedBox(height: 16),
              ],
              
              _buildLabel('EMAIL ADDRESS'),
              _buildTextField(
                controller: _emailController,
                icon: Icons.mail,
                hint: 'explorer@aetheris.com',
              ),
              const SizedBox(height: 16),
              _buildLabel('PASSWORD'),
              _buildTextField(
                controller: _passwordController,
                icon: Icons.lock,
                hint: '••••••••',
                obscure: true,
              ),
              const SizedBox(height: 24),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              else ...[
                ElevatedButton(
                  onPressed: _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ).copyWith(
                    side: WidgetStateProperty.all(BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.5))),
                  ),
                  child: Text(_isLoginMode ? 'AUTHORIZE SESSION' : 'REGISTER ACCOUNT', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isLoginMode ? 'CREATE NEW ACCOUNT' : 'LOG INTO EXISTING ACCOUNT', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
              ),
              
              const Text(
                'Anonymous Entry',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Limited data persistence mode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 24),
              
              _buildLabel('GUEST USERNAME'),
              _buildTextField(
                controller: _guestUsernameController,
                icon: Icons.person_search,
                hint: 'guest',
              ),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginAsGuest,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('CONTINUE AS GUEST', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.2)),
                  foregroundColor: Colors.cyanAccent,
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.6)),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 50,
          )
        ],
      ),
    );
  }
}
