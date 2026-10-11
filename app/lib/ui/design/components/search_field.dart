// SearchField: 52 dp sunken field with a leading search icon, a clear
// button and no Material underline or filled defaults.
// See docs/ui/UI_SPEC.md 5 and 7.3.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// Search input.
class SearchField extends StatelessWidget {
  /// Creates the field.
  const SearchField({
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.semanticLabel,
    super.key,
  });

  /// Hint in pt-BR.
  final String hint;

  /// Optional external controller.
  final TextEditingController? controller;

  /// Called on every keystroke, with no debounce.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard submits.
  final ValueChanged<String>? onSubmitted;

  /// Takes focus on mount (search screen).
  final bool autofocus;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Screen-reader label, defaults to [hint].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel ?? hint,
      textField: true,
      child: Container(
        height: Sizes.search,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.x4),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.l),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, size: 20, color: colors.inkMuted),
            const SizedBox(width: Space.x3),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                cursorColor: colors.primary,
                style: PontualText.body.copyWith(color: colors.ink),
                decoration: InputDecoration.collapsed(
                  hintText: hint,
                  hintStyle: PontualText.body.copyWith(color: colors.inkSubtle),
                ),
              ),
            ),
            if (onChanged != null)
              Pressable(
                onTap: () {
                  controller?.clear();
                  onChanged?.call('');
                },
                semanticLabel: 'Limpar',
                borderRadius: Radii.pill,
                child: Padding(
                  padding: const EdgeInsets.all(Space.x1),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Field that opens the search screen on tap, used on Início.
class SearchEntry extends StatelessWidget {
  /// Creates the entry.
  const SearchEntry({required this.hint, this.onTap, super.key});

  /// Hint in pt-BR.
  final String hint;

  /// Called on tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      semanticLabel: hint,
      borderRadius: Radii.l,
      child: Container(
        height: Sizes.search,
        padding: const EdgeInsets.symmetric(horizontal: Space.x4),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.l),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, size: 20, color: colors.inkMuted),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                hint,
                style: PontualText.body.copyWith(color: colors.inkSubtle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
