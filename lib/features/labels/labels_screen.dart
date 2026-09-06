import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';

/// The labels manager: a header block, an inline creator, and label rows
/// carrying live note counts. Label names render in JetBrains Mono, like every
/// other identifier.
class LabelsScreen extends ConsumerStatefulWidget {
  /// Set when arriving from a "new label" affordance: the creator takes focus
  /// so the action completes where the user expected it to.
  final bool focusCreate;

  const LabelsScreen({super.key, this.focusCreate = false});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  final TextEditingController _newLabel = TextEditingController();
  final FocusNode _newLabelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.focusCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _newLabelFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _newLabel.dispose();
    _newLabelFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newLabel.text.trim();
    if (name.isEmpty) return;
    _newLabel.clear();
    setState(() {});
    await ref.read(labelsDaoProvider).create(name);
  }

  Future<void> _rename(Label label) async {
    final name = await showTextPromptDialog(
      context,
      title: 'Rename label',
      label: 'Label name',
      initialValue: label.name,
    );
    if (name != null) {
      await ref.read(labelsDaoProvider).rename(label.id, name);
    }
  }

  Future<void> _delete(Label label) async {
    final ok = await showDangerConfirmDialog(
      context,
      title: 'Delete #${label.name}?',
      message: 'Notes keep their content. The label is removed from every note '
          'that carries it.',
      confirmLabel: 'Delete label',
    );
    if (ok) await ref.read(labelsDaoProvider).delete(label.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dao = ref.watch(labelsDaoProvider);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final gutter = wide ? Spacing.xxl : Spacing.gutter;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: StreamBuilder<List<Label>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          final labels = snapshot.data;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                gutter, Spacing.xl, gutter, Spacing.xxxl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.form),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelsHeader(count: labels?.length),
                    const SizedBox(height: Spacing.xl),
                    _Creator(
                      controller: _newLabel,
                      focusNode: _newLabelFocus,
                      onSubmit: _create,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Spacing.xl),
                    if (snapshot.hasError)
                      InlineError(
                        message: 'Labels could not be loaded.',
                        onRetry: () => setState(() {}),
                      )
                    else if (labels == null)
                      const Padding(
                        padding: EdgeInsets.only(top: Spacing.xxl),
                        child: CenteredLoader(),
                      )
                    else if (labels.isEmpty)
                      EmptyState(
                        icon: Symbols.tag,
                        title: 'No labels yet',
                        message: 'Labels group notes across the workspace. '
                            'Create one above to get started.',
                        action: FilledButton.icon(
                          onPressed: () => _newLabelFocus.requestFocus(),
                          icon: const Icon(Symbols.add, size: 18),
                          label: const Text('Create a label'),
                        ),
                      )
                    else ...[
                      SectionHeader(
                        icon: Symbols.sell,
                        label: 'All labels',
                        count: labels.length,
                        trailing: Text(
                          'Sorted A–Z',
                          style: context.texts.labelSmall
                              ?.copyWith(color: palette.textTertiary),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      SurfacePanel(
                        padding: const EdgeInsets.all(Spacing.xs),
                        child: Column(
                          children: [
                            for (var i = 0; i < labels.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: palette.border,
                                  indent: Spacing.md,
                                  endIndent: Spacing.md,
                                ),
                              _LabelRow(
                                label: labels[i],
                                onOpen: () =>
                                    context.go('/label/${labels[i].id}'),
                                onRename: () => _rename(labels[i]),
                                onDelete: () => _delete(labels[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Page banner: a tinted `#` tile, the title, and a dot-separated meta row.
class _LabelsHeader extends StatelessWidget {
  final int? count;

  const _LabelsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: palette.primaryWash,
            borderRadius: AppRadii.all(AppRadii.md),
          ),
          child: Icon(Symbols.tag, size: 26, color: palette.onPrimaryWash),
        ),
        const SizedBox(width: Spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Labels', style: context.texts.headlineLarge),
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  Text(
                    count == null
                        ? '—'
                        : count == 1
                            ? '1 label'
                            : '$count labels',
                    style: context.mono.copyWith(color: palette.textTertiary),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text('•',
                      style:
                          context.mono.copyWith(color: palette.textTertiary)),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Text(
                      'Group notes across the workspace',
                      style: context.texts.bodySmall
                          ?.copyWith(color: palette.textTertiary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Creator extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;

  const _Creator({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSubmit = controller.text.trim().isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: context.mono.copyWith(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'new-label',
              hintStyle: context.mono.copyWith(color: palette.textTertiary),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.sm),
                child: Icon(Symbols.tag, size: 17, color: palette.textTertiary),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: Spacing.md),
        FilledButton.icon(
          onPressed: canSubmit ? onSubmit : null,
          icon: const Icon(Symbols.add, size: 18),
          label: const Text('Create'),
        ),
      ],
    );
  }
}

class _LabelRow extends ConsumerWidget {
  final Label label;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _LabelRow({
    required this.label,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return StreamBuilder<List<Note>>(
      stream: ref.watch(notesDaoProvider).watchByLabel(label.id),
      builder: (context, snapshot) {
        final count = snapshot.data?.length;

        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.all(AppRadii.base),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              child: Row(
                children: [
                  Icon(Symbols.tag, size: 17, color: palette.textTertiary),
                  const SizedBox(width: Spacing.md - 2),
                  Expanded(
                    child: Text(
                      label.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.mono.copyWith(
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (count != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Spacing.sm),
                      child: Text(
                        count == 1 ? '1 note' : '$count notes',
                        style: context.mono
                            .copyWith(color: palette.textTertiary),
                      ),
                    ),
                  GhostIconButton(
                    icon: Symbols.edit,
                    tooltip: 'Rename',
                    iconSize: 17,
                    target: 34,
                    onPressed: onRename,
                  ),
                  GhostIconButton(
                    icon: Symbols.delete,
                    tooltip: 'Delete',
                    iconSize: 17,
                    target: 34,
                    color: palette.textTertiary,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
