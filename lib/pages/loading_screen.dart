import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/stars_animation.dart';
import '../core/stores/auth_store.dart';
import '../core/utils/video_loader.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late Animation<double> _circleScale;
  int _count = 1;
  bool _isIn = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeInOut),
    );
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Preload video in background
    VideoLoader.initializeVideos();

    // Check if user is authenticated first
    final authStore = Provider.of<AuthStore>(context, listen: false);
    final isAuthenticated = await authStore.isAuthenticated();

    if (isAuthenticated) {
      // User is authenticated, show splash screen and redirect
      setState(() {
        _isAuthenticated = true;
      });

      if (!mounted) return;

      // Add timeout to prevent hanging
      try {
        final redirectRoute = await authStore.getRedirectRoute().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // If timeout but token exists, go to generator to complete profile
            return '/generator';
          },
        );

        // Show splash screen for a short time
        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(redirectRoute);
        return;
      } catch (e) {
        // If there's an error but token exists, still try to go to generator
        // This ensures user can complete their profile even if API call fails
        final stillAuthenticated = await authStore.isAuthenticated();
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        if (stillAuthenticated) {
          // Token exists but API failed - go to generator to complete profile
          Navigator.of(context).pushReplacementNamed('/generator');
        } else {
          // Token was cleared or invalid - go to onboarding
          Navigator.of(context).pushReplacementNamed('/onboarding-1');
        }
        return;
      }
    }

    // User is not authenticated, show breathing animation
    setState(() {
      _isAuthenticated = false;
    });
    _startBreathingAnimation();
  }

  Future<void> _startBreathingAnimation() async {
    // Breathe In: circle grows from 0 to max and stays
    setState(() {
      _isIn = true;
      _count = 1;
    });
    _circleController.reset();
    _circleController.forward();
    for (int i = 1; i <= 5; i++) {
      setState(() => _count = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    // Breathe Out: circle shrinks from max to 0
    setState(() {
      _isIn = false;
      _count = 5;
    });
    _circleController.reverse(from: 1.0);
    for (int i = 5; i >= 1; i--) {
      setState(() => _count = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    // If we reach here, it means user is not authenticated
    // Navigate to onboarding page 1 (first page after splash)
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/onboarding-1');
  }

  @override
  void dispose() {
    _circleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If user is authenticated, show splash screen that looks like default splash
    if (_isAuthenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFFDCE6F0), // Same as default splash
        body: Center(
          child: Image.asset('assets/logo.png', width: 120, height: 120),
        ),
      );
    }

    // If user is not authenticated, show breathing animation
    return Scaffold(
      body: Stack(
        children: [
          const StarsAnimation(),
          Center(child: _buildBreathingAnimation()),
        ],
      ),
    );
  }

  Widget _buildBreathingAnimation() {
    return AnimatedBuilder(
      animation: _circleController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.1,
              child: Transform.translate(
                offset: const Offset(0, 25), // смещение вниз на 20 px
                child: Transform.scale(
                  scale: _circleScale.value,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isIn ? 'Breathe In' : 'Breathe Out',
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontFamily: 'Canela',
                  ),
                ),
                const SizedBox(height: 0),
                Text(
                  '$_count',
                  style: TextStyle(
                    fontSize: 138,
                    color: Colors.white.withAlpha((0.3 * 255).toInt()),
                    fontFamily: 'Canela',
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
