import 'package:flutter/material.dart';

/// Three pulsing dots — the UniShip loading signature.
class LoadingDots extends StatefulWidget {
  final double size;
  const LoadingDots({super.key, this.size = 8});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.18) % 1.0;
            final opacity = t < 0.5 ? 0.25 + t * 1.5 : 1.0 - (t - 0.5) * 1.5;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
              child: Opacity(
                opacity: opacity.clamp(0.25, 1.0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(48), child: LoadingDots()));
}
