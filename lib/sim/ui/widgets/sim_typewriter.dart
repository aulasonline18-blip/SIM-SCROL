import 'dart:async';

import 'package:flutter/material.dart';

class SimTypewriter extends StatefulWidget {
  const SimTypewriter({
    required this.text,
    required this.style,
    this.charactersPerTick = 3,
    this.tickDuration = const Duration(milliseconds: 18),
    this.cursorColor,
    this.onDone,
    this.onTick,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int charactersPerTick;
  final Duration tickDuration;
  final Color? cursorColor;
  final VoidCallback? onDone;
  final VoidCallback? onTick;

  @override
  State<SimTypewriter> createState() => _SimTypewriterState();
}

class _SimTypewriterState extends State<SimTypewriter>
    with SingleTickerProviderStateMixin {
  String _displayed = '';
  bool _done = false;
  Timer? _timer;
  late final AnimationController _cursorCtrl;
  late final Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _cursorOpacity = Tween<double>(begin: 1, end: 0).animate(_cursorCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(SimTypewriter old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.charactersPerTick != widget.charactersPerTick ||
        old.tickDuration != widget.tickDuration) {
      _stop();
      _displayed = '';
      _done = false;
      _start();
    }
  }

  void _start() {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      setState(() {
        _displayed = widget.text;
        _done = true;
      });
      Future<void>.microtask(() {
        widget.onDone?.call();
        widget.onTick?.call();
      });
      return;
    }
    _timer = Timer.periodic(widget.tickDuration, (_) {
      if (!mounted) return;
      final charsPerTick = widget.charactersPerTick.clamp(1, 12);
      final end = (_displayed.length + charsPerTick).clamp(
        0,
        widget.text.length,
      );
      final completed = end >= widget.text.length;
      setState(() {
        _displayed = widget.text.substring(0, end);
        _done = completed;
      });
      if (completed) {
        _timer?.cancel();
        widget.onDone?.call();
      } else {
        widget.onTick?.call();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final cursorHeight = textScaler.scale(
      widget.style.fontSize ??
          DefaultTextStyle.of(context).style.fontSize ??
          14,
    );
    if (MediaQuery.of(context).disableAnimations || _done) {
      return Text(widget.text, style: widget.style);
    }
    return Stack(
      children: [
        Opacity(
          opacity: 0,
          alwaysIncludeSemantics: true,
          child: Text(widget.text, style: widget.style),
        ),
        RichText(
          textScaler: textScaler,
          text: TextSpan(
            style: widget.style,
            children: [
              TextSpan(text: _displayed),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: FadeTransition(
                  opacity: _cursorOpacity,
                  child: Container(
                    width: 6,
                    height: cursorHeight.clamp(14.0, 34.0),
                    margin: const EdgeInsets.only(left: 2),
                    color: widget.cursorColor ?? widget.style.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
