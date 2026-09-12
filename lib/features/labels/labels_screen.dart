import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';

Future<void> showEditLabelsDialog(
  BuildContext context, {
  bool focusCreate = false,
}) {
  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: AppMotion.slow,
    pageBuilder: (dialogContext, _, _) {
      final palette = dialogContext.palette;
      final compact =
          MediaQuery.sizeOf(dialogContext).width < Breakpoints.tablet;
      void close() => Navigator.of(dialogContext, rootNavigator: true).pop();

      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: close,
          child: ColoredBox(
            color: const Color(0x33191919),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding:
                      compact
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(Spacing.xl),
                  child: GestureDetector(
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? double.infinity : 520,
                        maxHeight: compact ? double.infinity : 680,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              compact
                                  ? BorderRadius.zero
                                  : AppRadii.all(AppRadii.lg),
                          border:
                              compact
                                  ? null
                                  : Border.all(color: palette.border),
                          boxShadow: compact ? null : AppShadows.e4(palette),
                        ),
                        child: Material(
                          color: palette.surface,
                          clipBehavior: Clip.antiAlias,
                          shape:
                              compact
                                  ? const RoundedRectangleBorder()
                                  : AppRadii.shape(AppRadii.lg),
                          child: Scaffold(
                            backgroundColor: palette.surface,
                            body: _LabelsManager(
                              focusCreate: focusCreate,
                              modal: true,
                              onClose: close,
                              onOpenLabel: (label) {
                                final router = GoRouter.of(dialogContext);
                                close();
                                router.go('/label/${label.id}');
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class LabelsScreen extends StatelessWidget {
  final bool focusCreate;

  const LabelsScreen({super.key, this.focusCreate = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.surface,
      body: _LabelsManager(
        focusCreate: focusCreate,
        modal: false,
        onOpenLabel: (label) => context.go('/label/${label.id}'),
      ),
    );
  }
}

class _LabelsManager extends ConsumerStatefulWidget {
  final bool focusCreate;
  final bool modal;
  final VoidCallback? onClose;
  final ValueChanged<Label> onOpenLabel;

  const _LabelsManager({
    required this.focusCreate,
    required this.modal,
    required this.onOpenLabel,
    this.onClose,
  });

  @override
  ConsumerState<_LabelsManager> createState() => _LabelsManagerState();
}

class _LabelsManagerState extends ConsumerState<_LabelsManager> {
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
    try {
      await ref.read(labelsDaoProvider).create(name);
      _newLabel.clear();
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      if (mounted) {
        setState(() {});
        _newLabelFocus.requestFocus();
      }
    } catch (_) {
      _showError('That label already exists or could not be created.');
      if (mounted) _newLabelFocus.requestFocus();
    }
  }

  Future<void> _rename(Label label) async {
    final name = await showTextPromptDialog(
      context,
      title: 'Rename label',
      label: 'Label name',
      initialValue: label.name,
    );
    if (name == null || !mounted) return;
    try {
      await ref.read(labelsDaoProvider).rename(label.id, name);
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    } catch (_) {
      _showError('That label name is already in use.');
    }
  }

  Future<void> _delete(Label label) async {
    final ok = await showDangerConfirmDialog(
      context,
      title: 'Delete #${label.name}?',
      message:
          'Notes keep their content. The label is removed from every note '
          'that carries it.',
      confirmLabel: 'Delete label',
    );
    if (ok && mounted) {
      await ref.read(labelsDaoProvider).delete(label.id);
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(labelsDaoProvider);
    return StreamBuilder<List<Label>>(
      stream: dao.watchAll(),
      builder: (context, snapshot) {
        if (widget.modal) return _buildModal(snapshot);
        return _buildPage(snapshot);
      },
    );
  }

  Widget _buildModal(AsyncSnapshot<List<Label>> snapshot) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.lg,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Edit labels', style: context.texts.headlineMedium),
              ),
              GhostIconButton(
                icon: Symbols.close,
                tooltip: 'Close',
                onPressed: widget.onClose!,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.sm,
            Spacing.xl,
            Spacing.lg,
          ),
          child: _Creator(
            controller: _newLabel,
            focusNode: _newLabelFocus,
            compact: true,
            onSubmit: _create,
            onChanged: (_) => setState(() {}),
          ),
        ),
        Divider(height: 1, color: palette.border),
        Flexible(
          child: _LabelsBody(
            snapshot: snapshot,
            modal: true,
            onRetry: () => setState(() {}),
            onCreate: () => _newLabelFocus.requestFocus(),
            onOpenLabel: widget.onOpenLabel,
            onRename: _rename,
            onDelete: _delete,
          ),
        ),
        Divider(height: 1, color: palette.border),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onClose,
              child: const Text('Done'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(AsyncSnapshot<List<Label>> snapshot) {
    final labels = snapshot.data;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final gutter = wide ? Spacing.xxl : Spacing.gutter;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, Spacing.xl, gutter, Spacing.xxxl),
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
                compact: false,
                onSubmit: _create,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.xl),
              _LabelsBody(
                snapshot: snapshot,
                modal: false,
                onRetry: () => setState(() {}),
                onCreate: () => _newLabelFocus.requestFocus(),
                onOpenLabel: widget.onOpenLabel,
                onRename: _rename,
                onDelete: _delete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelsBody extends StatelessWidget {
  final AsyncSnapshot<List<Label>> snapshot;
  final bool modal;
  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final ValueChanged<Label> onOpenLabel;
  final ValueChanged<Label> onRename;
  final ValueChanged<Label> onDelete;

  const _LabelsBody({
    required this.snapshot,
    required this.modal,
    required this.onRetry,
    required this.onCreate,
    required this.onOpenLabel,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final labels = snapshot.data;
    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: InlineError(
          message: 'Labels could not be loaded.',
          onRetry: onRetry,
        ),
      );
    }
    if (labels == null) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.xxl),
        child: CenteredLoader(),
      );
    }
    if (labels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: EmptyState(
          icon: Symbols.tag,
          title: 'No labels yet',
          message: 'Create a label above to group notes across the workspace.',
          action: TextButton.icon(
            onPressed: onCreate,
            icon: const Icon(Symbols.add, size: 18),
            label: const Text('Create a label'),
          ),
        ),
      );
    }

    final rows = Column(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: context.palette.border,
              indent: Spacing.md,
              endIndent: Spacing.md,
            ),
          _LabelRow(
            label: labels[i],
            onOpen: () => onOpenLabel(labels[i]),
            onRename: () => onRename(labels[i]),
            onDelete: () => onDelete(labels[i]),
          ),
        ],
      ],
    );

    if (modal) {
      return ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        children: [rows],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Symbols.sell,
          label: 'All labels',
          count: labels.length,
          trailing: Text(
            'Sorted A–Z',
            style: context.texts.labelSmall?.copyWith(
              color: context.palette.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        SurfacePanel(padding: const EdgeInsets.all(Spacing.xs), child: rows),
      ],
    );
  }
}

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
              Text(
                count == null
                    ? '—'
                    : count == 1
                    ? '1 label'
                    : '$count labels',
                style: context.mono.copyWith(color: palette.textTertiary),
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
  final bool compact;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;

  const _Creator({
    required this.controller,
    required this.focusNode,
    required this.compact,
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
              hintText: 'Create new label',
              hintStyle: context.mono.copyWith(color: palette.textTertiary),
              prefixIcon: Icon(
                Symbols.add,
                size: 19,
                color: palette.textSecondary,
              ),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        if (compact)
          GhostIconButton(
            icon: Symbols.check,
            tooltip: 'Create label',
            onPressed: canSubmit ? onSubmit : null,
          )
        else
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
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
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
                        style: context.mono.copyWith(
                          color: palette.textTertiary,
                        ),
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
