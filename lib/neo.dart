import 'package:flutter/material.dart';

/// Neo-brutalism kit: flat loud colours, thick black borders, hard shadows.
const ink = Color(0xFF111111);
const paper = Color(0xFFFFF6E0);
const yellow = Color(0xFFFFD93D);
const pink = Color(0xFFFF6B9D);
const blue = Color(0xFF6CB6FF);
const green = Color(0xFF7BE495);
const orange = Color(0xFFFF9F45);
const grey = Color(0xFFD9D4C7);

const borderW = 3.0;
const shadowD = 5.0;

const heavy = TextStyle(
    color: ink, fontWeight: FontWeight.w900, letterSpacing: 0.4, height: 1.15);
const mono = TextStyle(
    color: ink,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w700,
    fontSize: 12.5);

ThemeData neoTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
          seedColor: yellow, brightness: Brightness.light, surface: paper),
      textSelectionTheme: const TextSelectionThemeData(
          cursorColor: ink, selectionColor: yellow, selectionHandleColor: ink),
    );

class NeoBox extends StatelessWidget {
  const NeoBox({
    super.key,
    this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(12),
    this.shadow = shadowD,
    this.width,
    this.height,
  });
  final Widget? child;
  final Color color;
  final EdgeInsets padding;
  final double shadow;
  final double? width, height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: ink, width: borderW),
          boxShadow: shadow == 0
              ? null
              : [BoxShadow(color: ink, offset: Offset(shadow, shadow))],
        ),
        child: child,
      );
}

class NeoButton extends StatefulWidget {
  const NeoButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.color = yellow,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final Color color;
  final bool expand;
  final EdgeInsets padding;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null;
    final sh = (down && on) ? 0.0 : shadowD - 1;
    final move = (shadowD - 1) - sh;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => down = true) : null,
      onTapUp: on ? (_) => setState(() => down = false) : null,
      onTapCancel: on ? () => setState(() => down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(move, move, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: on ? widget.color : grey,
          border: Border.all(color: ink, width: borderW),
          boxShadow: [BoxShadow(color: ink, offset: Offset(sh, sh))],
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) Icon(widget.icon, color: ink, size: 22),
            if (widget.icon != null && widget.label != null)
              const SizedBox(width: 8),
            if (widget.label != null)
              Flexible(
                child: Text(widget.label!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: heavy.copyWith(
                        fontSize: 14, color: on ? ink : const Color(0xFF777777))),
              ),
          ],
        ),
      ),
    );
  }
}

class NeoCheck extends StatelessWidget {
  const NeoCheck(this.value, {super.key});
  final bool value;
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: value ? ink : Colors.white,
          border: Border.all(color: ink, width: borderW),
        ),
        child: value
            ? const Icon(Icons.check, color: yellow, size: 22, weight: 900)
            : null,
      );
}

class NeoTag extends StatelessWidget {
  const NeoTag(this.text, {super.key, this.color = Colors.white, this.maxLines = 1});
  final String text;
  final Color color;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color, border: Border.all(color: ink, width: 2)),
        child: Text(text,
            maxLines: maxLines, overflow: TextOverflow.ellipsis, style: mono),
      );
}

class NeoProgress extends StatelessWidget {
  const NeoProgress({super.key, this.value, this.color = pink});
  final double? value; // null = indeterminate
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 18,
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: ink, width: 3)),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 12,
          color: color,
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.zero,
        ),
      );
}

class NeoDrop<T> extends StatelessWidget {
  const NeoDrop(
      {super.key,
      required this.value,
      required this.items,
      required this.onChanged,
      required this.label,
      this.color = Colors.white});
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) label;
  final Color color;

  @override
  Widget build(BuildContext context) => NeoBox(
        color: color,
        shadow: shadowD - 1,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: false,
            borderRadius: BorderRadius.zero,
            dropdownColor: paper,
            iconEnabledColor: ink,
            style: heavy.copyWith(fontSize: 15),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(label(e))))
                .toList(),
            onChanged: (v) => onChanged(v as T),
          ),
        ),
      );
}
