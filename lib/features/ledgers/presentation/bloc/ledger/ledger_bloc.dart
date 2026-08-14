import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/create_family_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/create_personal_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/delete_personal_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/join_family_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/leave_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/rotate_invite_code.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/select_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/watch_ledgers.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'ledger_event.dart';
part 'ledger_state.dart';

/// Drives the switcher and the family-account sheet.
///
/// Both read the same list, so one bloc serves them: the sheet is opened from
/// the switcher and shows what the switcher was showing, and two blocs would
/// give them two answers while a join was in flight.
class LedgerBloc extends Bloc<LedgerEvent, LedgerState> {
  LedgerBloc({
    required WatchLedgers watchLedgers,
    required String activeId,
    SelectLedger? selectLedger,
    CreatePersonalLedger? createPersonalLedger,
    CreateFamilyLedger? createFamilyLedger,
    DeletePersonalLedger? deletePersonalLedger,
    JoinFamilyLedger? joinFamilyLedger,
    LeaveLedger? leaveLedger,
    RotateInviteCode? rotateInviteCode,
  }) : _watchLedgers = watchLedgers,
       _selectLedger = selectLedger,
       _createPersonalLedger = createPersonalLedger,
       _createFamilyLedger = createFamilyLedger,
       _deletePersonalLedger = deletePersonalLedger,
       _joinFamilyLedger = joinFamilyLedger,
       _leaveLedger = leaveLedger,
       _rotateInviteCode = rotateInviteCode,
       super(LedgerState(activeId: activeId)) {
    on<LedgerSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    // Sequential across all of these: they change what the reader has access
    // to, and two overlapping changes would leave whichever finished last in
    // charge of a decision the reader made in a particular order.
    on<LedgerSelected>(_onSelected, transformer: sequential());
    on<LedgerPersonalCreated>(_onPersonalCreated, transformer: sequential());
    on<LedgerFamilyCreated>(_onFamilyCreated, transformer: sequential());
    on<LedgerDeleted>(_onDeleted, transformer: sequential());
    on<LedgerJoinRequested>(_onJoinRequested, transformer: sequential());
    on<LedgerLeft>(_onLeft, transformer: sequential());
    on<LedgerInviteCodeRotated>(
      _onInviteCodeRotated,
      transformer: sequential(),
    );
  }

  final WatchLedgers _watchLedgers;

  /// Null in a bloc built for a test that only reads the list.
  final SelectLedger? _selectLedger;
  final CreatePersonalLedger? _createPersonalLedger;
  final CreateFamilyLedger? _createFamilyLedger;
  final DeletePersonalLedger? _deletePersonalLedger;
  final JoinFamilyLedger? _joinFamilyLedger;
  final LeaveLedger? _leaveLedger;
  final RotateInviteCode? _rotateInviteCode;

  Future<void> _onSubscriptionRequested(
    LedgerSubscriptionRequested event,
    Emitter<LedgerState> emit,
  ) async {
    emit(state.copyWith(status: LedgerStatus.loading));

    await emit.forEach<List<Ledger>>(
      _watchLedgers(),
      onData: (ledgers) => state.copyWith(
        status: LedgerStatus.success,
        ledgers: ledgers,
        clearError: true,
      ),
      onError: (error, stackTrace) {
        log('Watching ledgers failed', error: error, stackTrace: stackTrace);
        return state.copyWith(status: LedgerStatus.failure);
      },
    );
  }

  Future<void> _onSelected(
    LedgerSelected event,
    Emitter<LedgerState> emit,
  ) async {
    if (event.ledgerId == state.activeId) return;

    try {
      await _selectLedger?.call(event.ledgerId);
      // The app shell rebuilds on the switch, so this bloc is about to be
      // replaced by a fresh one. Emitting anyway: on the frame between the two,
      // the switcher should already read the ledger it was told to open.
      emit(state.copyWith(activeId: event.ledgerId, clearError: true));
    } on LedgerFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } on Object catch (e, s) {
      log('Switching to ${event.ledgerId} failed', error: e, stackTrace: s);
      emit(state.copyWith(errorMessage: t.accounts.openFailed));
    }
  }

  Future<void> _onPersonalCreated(
    LedgerPersonalCreated event,
    Emitter<LedgerState> emit,
  ) => _create(
    emit,
    make: () => _createPersonalLedger?.call(event.name),
    whenItFails: t.accounts.createFailed,
  );

  Future<void> _onFamilyCreated(
    LedgerFamilyCreated event,
    Emitter<LedgerState> emit,
  ) => _create(
    emit,
    make: () => _createFamilyLedger?.call(event.name),
    whenItFails: t.accounts.createFamilyFailed,
  );

  /// Makes a book and opens it.
  ///
  /// Shared by both kinds because the difference between them is which use case
  /// runs; what happens around it — the busy flag, opening what was made,
  /// reporting a refusal — is the same, and two copies of it is how the two drift
  /// apart.
  Future<void> _create(
    Emitter<LedgerState> emit, {
    required Future<Ledger?>? Function() make,
    required String whenItFails,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      final created = await make();
      // Opened as well as created. Making an account and staying in the one that
      // was already open would leave the reader looking for what they just made.
      if (created != null) await _selectLedger?.call(created.id);

      emit(
        state.copyWith(
          busy: false,
          activeId: created?.id ?? state.activeId,
          clearError: true,
        ),
      );
    } on LedgerFailure catch (e) {
      // Includes the limits, which is the common case here rather than an edge:
      // the form asks first, but a device that has been offline can be looking at
      // a list one book out of date.
      emit(state.copyWith(busy: false, errorMessage: e.message));
    } on Object catch (e, s) {
      log(whenItFails, error: e, stackTrace: s);
      emit(state.copyWith(busy: false, errorMessage: whenItFails));
    }
  }

  Future<void> _onDeleted(
    LedgerDeleted event,
    Emitter<LedgerState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      await _deletePersonalLedger?.call(event.ledgerId);
      emit(state.copyWith(busy: false, clearError: true));
    } on LedgerFailure catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.message));
    } on Object catch (e, s) {
      log('Removing ${event.ledgerId} failed', error: e, stackTrace: s);
      emit(
        state.copyWith(
          busy: false,
          errorMessage: t.accounts.removeFailed,
        ),
      );
    }
  }

  Future<void> _onJoinRequested(
    LedgerJoinRequested event,
    Emitter<LedgerState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      final joined = await _joinFamilyLedger?.call(event.code);
      if (joined != null) await _selectLedger?.call(joined.id);

      emit(
        state.copyWith(
          busy: false,
          activeId: joined?.id ?? state.activeId,
          clearError: true,
        ),
      );
    } on LedgerFailure catch (e) {
      // Includes the case where the join worked but sync has not caught up, so
      // this is not always a refusal — the message says which.
      emit(state.copyWith(busy: false, errorMessage: e.message));
    } on Object catch (e, s) {
      log('Joining a family account failed', error: e, stackTrace: s);
      emit(
        state.copyWith(busy: false, errorMessage: t.accounts.codeFailed),
      );
    }
  }

  Future<void> _onLeft(LedgerLeft event, Emitter<LedgerState> emit) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      await _leaveLedger?.call(event.ledgerId);
      emit(state.copyWith(busy: false, clearError: true));
    } on LedgerFailure catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.message));
    } on Object catch (e, s) {
      log('Leaving ${event.ledgerId} failed', error: e, stackTrace: s);
      emit(
        state.copyWith(
          busy: false,
          errorMessage: t.accounts.leaveFailed,
        ),
      );
    }
  }

  Future<void> _onInviteCodeRotated(
    LedgerInviteCodeRotated event,
    Emitter<LedgerState> emit,
  ) async {
    try {
      await _rotateInviteCode?.call(event.ledgerId);
      // No emit on success: the new code arrives on the watch stream, so there
      // is one source of truth for what the sheet shows.
    } on LedgerFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } on Object catch (e, s) {
      log(
        'Rotating the code for ${event.ledgerId} failed',
        error: e,
        stackTrace: s,
      );
      emit(state.copyWith(errorMessage: t.accounts.rotateFailed));
    }
  }
}
