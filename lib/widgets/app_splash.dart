import 'package:flutter/material.dart';

class AppSplash extends StatefulWidget {
  const AppSplash({super.key});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _line;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOut),
      ),
    );

    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    _line = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.82, curve: Curves.easeInOutCubic),
      ),
    );

    // Keep the animation alive after the first reveal instead of allowing the
    // logo to disappear almost immediately while startup finishes.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            _controller.reverse();
          }
        });
      }
    });

    // Forward the controller again after the reverse so AppSplash can be
    // safely rebuilt on another startup without a stale animation state.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFAFAFA);
    final orange = Colors.orange.shade800;

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: orange.withValues(alpha: 0.10),
                      ),
                      child: Icon(
                        Icons.train_rounded,
                        size: 52,
                        color: orange,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'RailSahayak',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Making railway travel more accessible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 150,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _line.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: orange),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
