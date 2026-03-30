import 'package:flutter/material.dart';

class DecorativeBackground extends StatelessWidget {
  final Widget child;

  const DecorativeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -70,
          child: _Blob(
            size: 220,
            colors: const [Color(0x332A6C8E), Color(0x112A6C8E)],
          ),
        ),
        Positioned(
          top: 140,
          left: -60,
          child: _Blob(
            size: 170,
            colors: const [Color(0x222F7D67), Color(0x112F7D67)],
          ),
        ),
        Positioned(
          bottom: -60,
          right: -30,
          child: _Blob(
            size: 160,
            colors: const [Color(0x22C4871F), Color(0x11C4871F)],
          ),
        ),
        child,
      ],
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
