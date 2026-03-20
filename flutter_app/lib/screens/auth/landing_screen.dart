// ============================================================
// Landing Screen (Homepage)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              // App Logo & Title
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 48),
              ).animate().scale(delay: 200.ms),
              const SizedBox(height: 24),
              Text(
                'SchoolID Pro',
                style: GoogleFonts.poppins(
                  fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'Choose your portal to continue',
                style: GoogleFonts.poppins(
                  fontSize: 16, color: Colors.white.withOpacity(0.8)
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 60),

              // Portal Cards
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 24,
                children: [
                   _PortalCard(
                     icon: Icons.badge_outlined,
                     title: 'Staff Portal',
                     subtitle: 'For Teachers, Admins & Transport',
                     color: const Color(0xFF0EA5E9),
                     onTap: () => context.go('/login/staff'),
                   ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                   _PortalCard(
                     icon: Icons.family_restroom_outlined,
                     title: 'Parent Portal',
                     subtitle: 'Track students & communication',
                     color: const Color(0xFF10B981),
                     onTap: () => context.go('/login/parent'),
                   ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                ],
              ),

              const SizedBox(height: 80),

              // Register School Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Are you a School Authority?',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register your institution to begin setting up your hierarchy, dynamic roles, and onboarding staff.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => context.go('/login/register'),
                      child: const Text('Register New School'),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 24),
            Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Login', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16, color: color),
              ],
            )
          ],
        ),
      ),
    );
  }
}
