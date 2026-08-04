import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/usecases/read_overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/usecases/save_overrun_settings.dart';
import 'package:my_pnl/features/spending/presentation/bloc/overrun_settings/overrun_settings_bloc.dart';

import '../../../../../helpers/helpers.dart';

/// Thresholds someone has already tightened.
const _tightened = OverrunSettings(
  mildPercent: 110,
  highPercent: 130,
  severePercent: 160,
);

void main() {
  group('OverrunSettingsBloc', () {
    late FakeOverrunSettingsStore store;

    OverrunSettingsBloc build([
      OverrunSettings initial = OverrunSettings.defaults,
    ]) {
      store = FakeOverrunSettingsStore(initial: initial);
      return OverrunSettingsBloc(
        readOverrunSettings: ReadOverrunSettings(store),
        saveOverrunSettings: SaveOverrunSettings(store),
      );
    }

    tearDown(() async => store.close());

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'opens on the settings in force',
      build: () => build(_tightened),
      act: (bloc) => bloc.add(const OverrunSettingsRequested()),
      expect: () => const <OverrunSettingsState>[
        OverrunSettingsState(settings: _tightened),
      ],
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'shows the defaults when the settings cannot be read',
      build: () {
        final bloc = build();
        store.readError = Exception('nope');
        return bloc;
      },
      act: (bloc) => bloc.add(const OverrunSettingsRequested()),
      // A form with no values in it could not be used at all.
      expect: () => const <OverrunSettingsState>[],
      verify: (bloc) =>
          expect(bloc.state.settings, OverrunSettings.defaults),
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'turns the warnings off without touching the thresholds',
      build: () => build(_tightened),
      act: (bloc) => bloc
        ..add(const OverrunSettingsRequested())
        ..add(const OverrunWarningsToggled(on: false)),
      skip: 1,
      expect: () => <OverrunSettingsState>[
        OverrunSettingsState(settings: _tightened.copyWith(enabled: false)),
      ],
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'moves one level and pushes the looser ones along',
      build: build,
      act: (bloc) =>
          bloc.add(const OverrunThresholdChanged(SpendOverrun.mild, 250)),
      verify: (bloc) {
        final settings = bloc.state.settings;

        expect(settings.mildPercent, 250);
        // Dragging past another level pushes it rather than leaving a set where
        // the colour in between can never appear.
        expect(settings.highPercent, 250);
        expect(settings.severePercent, 250);
      },
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'writes nothing until it is submitted',
      build: () => build(_tightened),
      act: (bloc) => bloc
        ..add(const OverrunSettingsRequested())
        ..add(const OverrunWarningsToggled(on: false))
        ..add(const OverrunThresholdChanged(SpendOverrun.high, 200)),
      // A slider produces a value per frame, and each one would be a write to
      // the platform store and a redraw of the grid behind the sheet.
      verify: (bloc) => expect(store.saved, isNull),
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'saves the draft and reports success',
      build: build,
      act: (bloc) => bloc
        ..add(const OverrunThresholdChanged(SpendOverrun.mild, 115))
        ..add(const OverrunSettingsSubmitted()),
      expect: () => const <OverrunSettingsState>[
        OverrunSettingsState(settings: OverrunSettings(mildPercent: 115)),
        OverrunSettingsState(
          settings: OverrunSettings(mildPercent: 115),
          status: OverrunSettingsStatus.submitting,
        ),
        OverrunSettingsState(
          settings: OverrunSettings(mildPercent: 115),
          status: OverrunSettingsStatus.success,
        ),
      ],
      verify: (bloc) =>
          expect(store.saved, const OverrunSettings(mildPercent: 115)),
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'says so when the settings cannot be saved, and stays open',
      build: () {
        final bloc = build();
        store.writeError = Exception('nope');
        return bloc;
      },
      act: (bloc) => bloc.add(const OverrunSettingsSubmitted()),
      expect: () => const <OverrunSettingsState>[
        OverrunSettingsState(status: OverrunSettingsStatus.submitting),
        OverrunSettingsState(
          status: OverrunSettingsStatus.failure,
          errorMessage: 'Could not save your warning settings',
        ),
        // Back to editing, so the sheet neither closes nor sticks on a spinner.
        OverrunSettingsState(),
      ],
    );

    blocTest<OverrunSettingsBloc, OverrunSettingsState>(
      'puts every threshold back',
      build: () => build(_tightened),
      act: (bloc) => bloc
        ..add(const OverrunSettingsRequested())
        ..add(const OverrunSettingsRestored()),
      skip: 1,
      expect: () => const <OverrunSettingsState>[OverrunSettingsState()],
      verify: (bloc) => expect(bloc.state.isDefault, isTrue),
    );

    test('reports a tightened set as not the default', () {
      expect(
        const OverrunSettingsState(settings: _tightened).isDefault,
        isFalse,
      );
    });
  });
}
