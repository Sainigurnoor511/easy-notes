import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';

/// Shared building blocks that encode `DESIGN.md` decisions once, so screens
/// don't re-derive them (and drift apart).

/// A `label-sm` uppercase eyebrow with wide tracking, in `text-tertiary`.
class Eyebrow extends StatelessWidget {
  final String text;

  const Eyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: context.eyebrow);
}

/// A count pill. Numbers always render in JetBrains Mono.
class CountBadge extends StatelessWidget {
  final int count;
  final bool emphasised;

  const CountBadge(this.count, {super.key, this.emphasised = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: emphasised ? palette.primary : palette.surfaceHover,
        borderRadius: AppRadii.all(AppRadii.full),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: context.mono.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: emphasised ? palette.onPrimary : palette.textSecondary,
        ),
      ),
    );
  }
}

/// Section header: an icon, an eyebrow, a count badge, a hairline rule filling
/// the remaining width, and optional right-aligned meta.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 15, color: palette.textTertiary),
        const SizedBox(width: Spacing.sm),
        Eyebrow(label),
        if (count != null) ...[
          const SizedBox(width: Spacing.sm),
          CountBadge(count!),
        ],
        const SizedBox(width: Spacing.md),
        Expanded(child: Divider(color: palette.border, height: 1)),
        if (trailing != null) ...[
          const SizedBox(width: Spacing.md),
          trailing!,
        ],
      ],
    );
  }
}

/// A Level 1 surface panel: 1px hairline, `md` corners, ambient shadow.
class SurfacePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool bordered;
  final List<BoxShadow>? shadow;

  const SurfacePanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.md,
    this.color,
    this.borderColor,
    this.bordered = true,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: AppRadii.all(radius),
        border:
            bordered ? Border.all(color: borderColor ?? palette.border) : null,
        boxShadow: shadow ?? AppShadows.e1(palette),
      ),
      child: child,
    );
  }
}

/// A settings-style section: an icon tile, a title, a description, then content.
class SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? headerAction;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.headerAction,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfacePanel(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.texts.headlineSmall),
                    if (description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xxs),
                        child: Text(
                          description!,
                          style: context.texts.bodySmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (headerAction != null) ...[
                const SizedBox(width: Spacing.md),
                headerAction!,
              ],
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// A 40px sunken tile holding a primary-colored glyph.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  const IconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? palette.surfaceSunken,
        borderRadius: AppRadii.all(AppRadii.base),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? palette.primary),
    );
  }
}

/// A sunken row for a setting: title, description, trailing control.
class SettingsRow extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? leading;
  final Color? leadingColor;

  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.onTap,
    this.leading,
    this.leadingColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final row = Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 18, color: leadingColor ?? palette.textSecondary),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.texts.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: leadingColor ?? palette.textPrimary,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xxs),
                    child: Text(
                      description!,
                      style: context.texts.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            trailing!,
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: AppRadii.all(AppRadii.md),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? row
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, child: row),
            ),
    );
  }
}

/// Lifts its child `-2px` on Y from Level 1 to Level 2 while hovered. Cards
/// lean toward the cursor; they never bounce.
class HoverLift extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovering) builder;

  /// Pointer-less platforms get no hover state; pass `false` to opt out.
  final bool enabled;

  const HoverLift({super.key, required this.builder, this.enabled = true});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, false);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        child: widget.builder(context, _hovering),
      ),
    );
  }
}

/// A pill-shaped monospaced tag chip: `#label`.
class TagChip extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;
  final IconData? icon;

  const TagChip({
    super.key,
    required this.label,
    this.background,
    this.foreground,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background ?? palette.surfaceSunken,
        borderRadius: AppRadii.all(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground ?? palette.textSecondary),
            const SizedBox(width: Spacing.xs),
          ],
          Text(
            label,
            style: context.mono
                .copyWith(color: foreground ?? palette.textSecondary),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: AppRadii.all(AppRadii.full),
      onTap: onTap,
      child: content,
    );
  }
}

/// A status pill: success / error / info washes with `label-sm` text.
class StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool dot;

  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm + 2,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.all(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: Spacing.sm - 2),
              decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
            )
          else if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: Spacing.xs + 2),
          ],
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled progress bar: label left, monospaced value right, 6px track.
class LabelledProgress extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color? color;
  final IconData? icon;

  const LabelledProgress({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: palette.textSecondary),
              const SizedBox(width: Spacing.xs + 2),
            ],
            Expanded(
              child: Text(
                label,
                style: context.texts.labelMedium
                    ?.copyWith(color: palette.textPrimary),
              ),
            ),
            Text(
              value,
              style: context.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm - 2),
        ClipRRect(
          borderRadius: AppRadii.all(AppRadii.full),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 6,
            backgroundColor: palette.surfaceHover,
            valueColor: AlwaysStoppedAnimation(color ?? palette.primary),
          ),
        ),
      ],
    );
  }
}

/// A 48px `text-tertiary` glyph on a sunken circle, one `headline-sm` line
/// naming what belongs here, one `body-sm` line explaining how to add it, and a
/// primary action when one exists.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: palette.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: palette.textTertiary),
              ),
              const SizedBox(height: Spacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.texts.headlineSmall,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.texts.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              if (action != null) ...[
                const SizedBox(height: Spacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A ghost icon button: transparent, `text-secondary`, hover fill. Keeps a 40px
/// hit area however small the glyph looks.
class GhostIconButton extends StatelessWidget {
  final IconData icon;

  /// Material Symbols' `FILL` axis: 0 outlined, 1 filled. Use 1 for an active
  /// toggle rather than swapping in a different glyph name.
  final double fill;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final double iconSize;
  final double target;

  const GhostIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.background,
    this.iconSize = 20,
    this.target = kMinTouchTarget,
    this.fill = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: target,
      height: target,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: iconSize,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          foregroundColor: color ?? palette.textSecondary,
          backgroundColor: background,
          minimumSize: Size(target, target),
          shape: AppRadii.shape(AppRadii.full),
        ),
        icon: Icon(icon, fill: fill),
      ),
    );
  }
}

/// A small centred indicator. Never a full-screen spinner block.
class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.palette.textTertiary,
        ),
      ),
    );
  }
}

/// Inline error surface. Error color on a soft wash, never a red-filled block.
class InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.error, color: palette.error, size: 26),
            const SizedBox(height: Spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium
                  ?.copyWith(color: palette.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Spacing.sm),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
