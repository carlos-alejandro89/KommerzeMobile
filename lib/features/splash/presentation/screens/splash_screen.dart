import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _truckSlide;
  late final Animation<double> _textReveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _truckSlide = Tween(begin: const Offset(1.8, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _textReveal = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward().whenComplete(() {
      if (mounted) context.go(AppConstants.loginScreenRoute);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => SlideTransition(
            position: _truckSlide,
            child: SizedBox(
              width: 280,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 0.42 + (_textReveal.value * 0.58),
                  child: Image.asset(
                    'assets/img/kommerze_logo.png',
                    width: 280,
                    height: 198,
                    fit: BoxFit.contain,
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
