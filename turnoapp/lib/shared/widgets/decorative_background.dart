import 'package:flutter/material.dart';

class DecorativeBackground extends StatelessWidget {
  final Widget child;

  const DecorativeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040B17), Color(0xFF08152A), Color(0xFF0A1D36)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _Blob(
              size: 280,
              colors: const [Color(0x5536A8FF), Color(0x0036A8FF)],
            ),
          ),
          Positioned(
            top: 120,
            left: -90,
            child: _Blob(
              size: 230,
              colors: const [Color(0x4448E5FF), Color(0x0048E5FF)],
            ),
          ),
          Positioned(
            bottom: -100,
            right: -40,
            child: _Blob(
              size: 220,
              colors: const [Color(0x446EEBFF), Color(0x006EEBFF)],
            ),
          ),
          Positioned(
            bottom: 110,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00000000),
                      Color(0x4D77D7FF),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _Blob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
