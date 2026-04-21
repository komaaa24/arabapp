import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────
// Avatar doirasi — NetworkImage muammosiz
// ─────────────────────────────────────────────
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.user, required this.size});

  final AuthUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: user.avatar != null
            ? Image.network(
                user.avatar!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Avatar yuklanmaguncha initials ko'rsatiladi
                frameBuilder: (ctx, child, frame, loaded) {
                  if (frame == null)
                    return _InitialsCircle(user: user, size: size);
                  return child;
                },
                errorBuilder: (_, __, ___) =>
                    _InitialsCircle(user: user, size: size),
              )
            : _InitialsCircle(user: user, size: size),
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.user, required this.size});

  final AuthUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF0D9488),
      alignment: Alignment.center,
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HomeScreen hero-dagi kichik badge
// ─────────────────────────────────────────────
class UserAvatarBadge extends StatelessWidget {
  const UserAvatarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    if (user == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      child: _AvatarCircle(user: user, size: 30),
    );
  }
}

// ─────────────────────────────────────────────
// Google kirish tugmasi (bottom sheet ichida)
// ─────────────────────────────────────────────
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  String? _error;
  bool _loading = false;

  Future<void> _handleSignIn() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted && AuthService.instance.isAuthenticated) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _loading ? null : _handleSignIn,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFDADCE0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded,
                          color: Color(0xFF4285F4), size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Google bilan kirish',
                        style: TextStyle(
                          color: Color(0xFF3C4043),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Auth bottom sheet
// ─────────────────────────────────────────────
class AuthBottomSheet extends StatelessWidget {
  const AuthBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.user;
        return Container(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),

              if (user == null) ...[
                // LOGIN
                const Icon(Icons.account_circle_outlined,
                    size: 60, color: Color(0xFF0F766E)),
                const SizedBox(height: 12),
                const Text('Hisobingizga kiring',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Progressingizni saqlash va barcha\nqurilmalarda sinhronlash uchun kiring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                const GoogleSignInButton(),
              ] else ...[
                // PROFIL
                _AvatarCircle(user: user, size: 70),
                const SizedBox(height: 14),
                Text(user.displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(user.email,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await AuthService.instance.signOut();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Chiqish',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
