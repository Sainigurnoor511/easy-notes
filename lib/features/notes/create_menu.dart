import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../shared/models/note_models.dart';

/// One shortcut on the create menu.
class CreateAction {
  final IconData icon;
  final String label;

  /// The block the new note opens with. `null` starts a plain note.
  final BlockType? seed;

  const CreateAction({required this.icon, required this.label, this.seed});
}

/// FAB shortcuts seed common block types; recording and drawing live inside notes.
const List<CreateAction> kCreateActions = [
  CreateAction(icon: Symbols.image, label: 'Image', seed: BlockType.image),
  CreateAction(
    icon: Symbols.check_box,
    label: 'List',
    seed: BlockType.checklist,
  ),
  CreateAction(icon: Symbols.title, label: 'Text'),
];

/// The FAB, and the labelled shortcuts that fan out above it.
///
/// Lives in the Scaffold's `floatingActionButton` slot as a bottom-aligned
/// column, so the shortcuts grow upward from the button without any manual
/// positioning. The dimming scrim is a separate widget in the body, which puts
/// it under the FAB in paint order — content dims, the menu stays lit.
class CreateMenu extends StatelessWidget {
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<BlockType?> onCreate;

  /// The labelled `+ New note` pill an empty wall gets, in place of the fan.
  final bool labelled;

  const CreateMenu({
    super.key,
    required this.open,
    required this.onOpenChanged,
    required this.onCreate,
    this.labelled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (labelled && !open) {
      return FloatingActionButton.extended(
        onPressed: () => onOpenChanged(true),
        icon: const Icon(Symbols.add, size: 22),
        label: const Text('New note'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final action in kCreateActions)
          _ActionPill(
            action: action,
            open: open,
            // Staggered so the fan reads as one gesture opening rather than
            // three things appearing at once.
            delay: Duration(milliseconds: 40 * kCreateActions.indexOf(action)),
            onTap: () {
              onOpenChanged(false);
              onCreate(action.seed);
            },
          ),
        FloatingActionButton(
          onPressed: () => onOpenChanged(!open),
          tooltip: open ? 'Close' : 'New note',
          child: AnimatedRotation(
            // The plus becomes the close, rather than swapping glyphs, so the
            // button never looks like it was replaced by a different control.
            turns: open ? 0.125 : 0,
            duration: AppMotion.base,
            curve: AppMotion.curve,
            child: const Icon(Symbols.add, size: 26),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final CreateAction action;
  final bool open;
  final Duration delay;
  final VoidCallback onTap;

  const _ActionPill({
    required this.action,
    required this.open,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedSlide(
      offset: open ? Offset.zero : const Offset(0, 0.4),
      duration: AppMotion.base + delay,
      curve: AppMotion.curve,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: AppMotion.fast + delay,
        child: IgnorePointer(
          ignoring: !open,
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: Spacing.md,
              right: Spacing.xs,
            ),
            child: Material(
              color: palette.primaryWash,
              borderRadius: AppRadii.all(AppRadii.full),
              elevation: 0,
              child: InkWell(
                borderRadius: AppRadii.all(AppRadii.full),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.md,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(action.icon, size: 20, color: palette.onPrimaryWash),
                      const SizedBox(width: Spacing.md),
                      Text(
                        action.label,
                        style: context.texts.titleSmall?.copyWith(
                          color: palette.onPrimaryWash,
                        ),
                      ),
                    ],
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

/// Dims the canvas while the create menu is open, and closes it on a tap
/// anywhere. Sits in the body so the FAB and its pills paint above it.
class CreateMenuScrim extends StatelessWidget {
  final bool open;
  final VoidCallback onDismiss;

  const CreateMenuScrim({
    super.key,
    required this.open,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: AppMotion.base,
        child: GestureDetector(
          onTap: onDismiss,
          child: ColoredBox(
            color: context.palette.textPrimary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
