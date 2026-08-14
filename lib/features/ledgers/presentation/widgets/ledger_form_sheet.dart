import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/presentation/bloc/ledger/ledger_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Where a new account is named.
///
/// A form of its own rather than a field in the accounts sheet: the name is the
/// only thing the reader gets to choose, and it is what they will be picking out
/// of a switcher afterwards — "Personal", "Side business", "Home". A cramped
/// field beside a button invites accepting whatever was suggested.
///
/// Which kind it is belongs here too, because the two choices constrain each
/// other: a reader already in a family account can only make a personal one, and
/// one with three of their own can only make a family one. Asking both questions
/// in one place is what lets it say so rather than refusing afterwards.
class LedgerFormSheet extends StatelessWidget {
  const LedgerFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    // The bloc comes from the page, like the accounts sheet's does: this form
    // reads the same list, and a second subscription would let the two disagree
    // about how many books there already are.
    final bloc = context.read<LedgerBloc>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: bloc, child: const LedgerFormSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LedgerBloc, LedgerState>(
      builder: (context, state) => _LedgerForm(state: state),
    );
  }
}

class _LedgerForm extends StatefulWidget {
  const _LedgerForm({required this.state});

  final LedgerState state;

  @override
  State<_LedgerForm> createState() => _LedgerFormState();
}

class _LedgerFormState extends State<_LedgerForm> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Which kind is being made. Starts on whatever there is room for — a reader
  /// who cannot make one of the two should not have to discover that by picking
  /// it.
  late LedgerKind _kind = widget.state.canAddPersonal
      ? LedgerKind.personal
      : LedgerKind.family;

  @override
  void initState() {
    super.initState();
    // Opened focused: this sheet exists to collect a name, so the keyboard is up
    // and the reader is typing rather than hunting for the field.
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isAllowed => switch (_kind) {
    LedgerKind.personal => widget.state.canAddPersonal,
    LedgerKind.family => widget.state.canAddFamily,
  };

  void _submit() {
    if (!_isAllowed || widget.state.busy) return;

    final name = _controller.text.trim();
    if (name.isEmpty) {
      // Nothing to put in the switcher. Focus rather than a message: the field is
      // right there and the only thing missing.
      _focus.requestFocus();
      return;
    }

    context.read<LedgerBloc>().add(switch (_kind) {
      LedgerKind.personal => LedgerPersonalCreated(name),
      LedgerKind.family => LedgerFamilyCreated(name),
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        // Lifts the sheet clear of the keyboard this form opens with.
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.accounts.formTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<LedgerKind>(
            segments: [
              // Both stay selectable even at their limit. A disabled segment
              // swallows the tap and explains nothing; selecting it and being
              // told why is how the reader finds out there is a limit at all.
              ButtonSegment(
                value: LedgerKind.personal,
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(t.accounts.kindPersonal),
              ),
              ButtonSegment(
                value: LedgerKind.family,
                icon: const Icon(Icons.people_outline, size: 18),
                label: Text(t.accounts.kindFamily),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) =>
                setState(() => _kind = selection.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 4),
          Text(
            switch (_kind) {
              LedgerKind.personal when !state.canAddPersonal =>
                t.accounts.formPersonalLimit(count: LedgerLimits.personal),
              LedgerKind.family when !state.canAddFamily =>
                t.accounts.formFamilyLimit,
              // What each kind is *for*, which is the thing a reader choosing
              // between them actually needs to know.
              LedgerKind.personal => t.accounts.formPersonalAbout,
              LedgerKind.family => t.accounts.formFamilyAbout,
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: _isAllowed
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: _isAllowed && !state.busy,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.common.name,
              // A suggestion rather than a default: the field stays empty, so
              // nothing is created under a name the reader did not choose.
              hintText: switch (_kind) {
                LedgerKind.personal => t.accounts.formHintPersonal,
                LedgerKind.family => t.accounts.formHintFamily,
              },
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isAllowed && !state.busy ? _submit : null,
              child: Text(t.common.create),
            ),
          ),
        ],
      ),
    );
  }
}
