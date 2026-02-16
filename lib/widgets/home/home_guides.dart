import 'dart:math' as math;

import 'package:flutter/material.dart';

class TopActionGuideButton extends StatelessWidget {
  const TopActionGuideButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.guideLabel,
    required this.guideVisible,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final String guideLabel;
  final bool guideVisible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(icon),
            tooltip: tooltip,
            onPressed: onPressed,
          ),
          SizedBox(
            height: 16,
            child: _WavyGuideLabel(
              text: guideLabel,
              visible: guideVisible,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingGuideAction extends StatelessWidget {
  const FloatingGuideAction({
    super.key,
    required this.label,
    required this.heroTag,
    required this.icon,
    required this.compact,
    required this.emphasized,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final String heroTag;
  final IconData icon;
  final bool compact;
  final bool emphasized;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 56.0;
    final hiddenOffsetFactor = compact ? 0.6 : 0.5;
    const labelWidth = 14.0;
    const labelSpacing = 10.0;
    const edgeInset = 16.0;
    final hiddenShift = iconSize * hiddenOffsetFactor;
    final actionWidth = iconSize + labelWidth + labelSpacing;
    final hiddenAreaActive = !emphasized;
    final iconButton = compact
        ? FloatingActionButton.small(
            heroTag: heroTag,
            onPressed: hiddenAreaActive ? null : onTap,
            child: Icon(icon),
          )
        : FloatingActionButton(
            heroTag: heroTag,
            onPressed: hiddenAreaActive ? null : onTap,
            child: Icon(icon),
          );

    return SizedBox(
      width: actionWidth + edgeInset,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOutCubic,
            right: emphasized ? edgeInset : -hiddenShift,
            top: 0,
            child: GestureDetector(
              onTap: hiddenAreaActive ? onTap : null,
              onLongPress: hiddenAreaActive ? onLongPress : null,
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: actionWidth,
                height: iconSize,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _VerticalWaveLabel(
                          text: label,
                          emphasized: emphasized,
                          visible: !emphasized,
                        ),
                      ),
                    ),
                    const SizedBox(width: labelSpacing),
                    GestureDetector(
                      onLongPress: hiddenAreaActive ? null : onLongPress,
                      behavior: HitTestBehavior.translucent,
                      child: SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: iconButton,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalWaveLabel extends StatefulWidget {
  const _VerticalWaveLabel({
    required this.text,
    required this.emphasized,
    required this.visible,
  });

  final String text;
  final bool emphasized;
  final bool visible;

  @override
  State<_VerticalWaveLabel> createState() => _VerticalWaveLabelState();
}

class _VerticalWaveLabelState extends State<_VerticalWaveLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chars = widget.text
        .replaceAll(' ', '')
        .runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    final opacity = widget.emphasized ? 0.95 : 0.78;
    final color = theme.colorScheme.onSurfaceVariant.withValues(alpha: opacity);
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    final amplitudeY = widget.emphasized ? 1.1 : 0.55;
    final amplitudeX = widget.emphasized ? 0.7 : 0.35;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      opacity: widget.visible ? 0.92 : 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(chars.length, (index) {
                final phase = t + index * 0.58;
                final y = math.sin(phase) * amplitudeY +
                    math.sin(phase * 2.2 + 0.4) * (amplitudeY * 0.24);
                final x = math.sin(phase * 1.45 + 0.35) * amplitudeX;
                return Transform.translate(
                  offset: Offset(x, y),
                  child: Text(chars[index], style: textStyle),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _WavyGuideLabel extends StatefulWidget {
  const _WavyGuideLabel({
    required this.text,
    required this.visible,
    this.compact = false,
  });

  final String text;
  final bool visible;
  final bool compact;

  @override
  State<_WavyGuideLabel> createState() => _WavyGuideLabelState();
}

class _WavyGuideLabelState extends State<_WavyGuideLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = (widget.compact
            ? theme.textTheme.labelSmall
            : theme.textTheme.labelMedium)
        ?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(
        alpha: widget.compact ? 0.92 : 0.86,
      ),
      fontWeight: FontWeight.w500,
      letterSpacing: widget.compact ? 0.12 : 0.18,
      height: 1,
    );
    final chars = widget.text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    final amplitudeY = widget.compact ? 0.9 : 1.35;
    final amplitudeX = widget.compact ? 0.35 : 0.55;
    const popScale = 0.96;
    const popOffsetY = 0.06;

    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        offset: widget.visible ? Offset.zero : const Offset(0, popOffsetY),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          scale: widget.visible ? popScale : 0.92,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(chars.length, (index) {
                  final phase = t + index * 0.72;
                  final y = math.sin(phase) * amplitudeY +
                      math.sin(phase * 2.15 + 0.65) * (amplitudeY * 0.28);
                  final x = math.sin(phase * 1.35 + 0.4) * amplitudeX;
                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Text(chars[index], style: textStyle),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
