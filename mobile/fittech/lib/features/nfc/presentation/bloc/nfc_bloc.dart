import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/access_log_entity.dart';
import '../../domain/entities/access_status_entity.dart';
import '../../domain/repositories/nfc_repository.dart';
import '../../../../../core/services/nfc_service.dart';

part 'nfc_event.dart';
part 'nfc_state.dart';

class NfcBloc extends Bloc<NfcEvent, NfcState> {
  final NfcRepository repository;
  final NfcService nfcService;

  NfcBloc({required this.repository, required this.nfcService})
      : super(const NfcState()) {
    on<NfcDataRequested>(_onDataRequested);
    on<NfcRefreshed>(_onRefreshed);
    on<NfcSimulateScanRequested>(_onSimulateScan);
    on<NfcRegisterCardRequested>(_onRegisterCard);
    on<NfcPhoneScanRequested>(_onPhoneScan);
  }

  Future<void> _onDataRequested(
    NfcDataRequested event,
    Emitter<NfcState> emit,
  ) async {
    emit(state.copyWith(status: NfcLoadStatus.loading, error: null));
    final statusEither = await repository.getStatus();
    final historyEither = await repository.getHistory(limit: event.limit);

    statusEither.fold(
      (failure) => emit(state.copyWith(
        status: NfcLoadStatus.failure,
        error: failure.message,
      )),
      (status) {
        final history = historyEither.fold<List<AccessLogEntity>>(
          (_) => const [],
          (logs) => logs,
        );
        emit(state.copyWith(
          status: NfcLoadStatus.success,
          accessStatus: status,
          history: history,
        ));
      },
    );
  }

  Future<void> _onRefreshed(
    NfcRefreshed event,
    Emitter<NfcState> emit,
  ) async {
    final statusEither = await repository.getStatus();
    final historyEither = await repository.getHistory(limit: event.limit);
    statusEither.fold(
      (_) {},
      (s) => emit(state.copyWith(accessStatus: s)),
    );
    historyEither.fold(
      (_) {},
      (logs) => emit(state.copyWith(history: logs)),
    );
  }

  Future<void> _onSimulateScan(
    NfcSimulateScanRequested event,
    Emitter<NfcState> emit,
  ) async {
    emit(state.copyWith(scanStatus: NfcScanStatus.scanning, scanError: null));
    final result = await repository.simulateScan();
    result.fold(
      (failure) => emit(state.copyWith(
        scanStatus: NfcScanStatus.failure,
        scanError: failure.message,
      )),
      (scan) {
        emit(state.copyWith(
          scanStatus:
              scan.allowed ? NfcScanStatus.granted : NfcScanStatus.denied,
          scanError: scan.allowed ? null : scan.reason,
          lastScanReason: scan.reason,
        ));
        // Refresh history so the new log entry shows up immediately.
        add(const NfcRefreshed());
      },
    );
  }

  Future<void> _onPhoneScan(
    NfcPhoneScanRequested event,
    Emitter<NfcState> emit,
  ) async {
    // Must have an active subscription to use phone NFC.
    final subActive = state.accessStatus?.subscriptionActive ?? false;
    if (!subActive) {
      emit(state.copyWith(
        phoneNfcStatus: NfcPhoneStatus.failure,
        phoneNfcError: 'An active subscription is required.',
      ));
      return;
    }

    final hasDevice = state.accessStatus?.hasDevice ?? false;

    // For access scan (card exists) we need NFC hardware.
    if (hasDevice) {
      final available = await nfcService.isAvailable();
      if (!available) {
        emit(state.copyWith(
          phoneNfcStatus: NfcPhoneStatus.unavailable,
          phoneNfcError: 'NFC is not available or not enabled on this device.',
        ));
        return;
      }
    }

    emit(state.copyWith(
        phoneNfcStatus: NfcPhoneStatus.reading, phoneNfcError: null));

    try {
      if (hasDevice) {
        // Card already registered — tap phone to scan access.
        await nfcService.readUid();
        final result = await repository.simulateScan();
        result.fold(
          (failure) => emit(state.copyWith(
            phoneNfcStatus: NfcPhoneStatus.failure,
            phoneNfcError: failure.message,
          )),
          (scan) {
            emit(state.copyWith(
              phoneNfcStatus: scan.allowed
                  ? NfcPhoneStatus.success
                  : NfcPhoneStatus.failure,
              phoneNfcError: scan.allowed ? null : scan.reason,
              scanStatus:
                  scan.allowed ? NfcScanStatus.granted : NfcScanStatus.denied,
              lastScanReason: scan.reason,
            ));
            add(const NfcRefreshed());
          },
        );
      } else {
        // No card yet — register phone's unique ID directly, no card tap needed.
        final phoneId = await nfcService.getPhoneId();
        final result = await repository.registerNfcCard(phoneId, 'phone');
        result.fold(
          (failure) => emit(state.copyWith(
            phoneNfcStatus: NfcPhoneStatus.failure,
            phoneNfcError: failure.message,
          )),
          (_) {
            emit(state.copyWith(phoneNfcStatus: NfcPhoneStatus.success));
            add(const NfcDataRequested());
          },
        );
      }
    } catch (e) {
      await nfcService.stopSession();
      emit(state.copyWith(
        phoneNfcStatus: NfcPhoneStatus.failure,
        phoneNfcError: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onRegisterCard(
    NfcRegisterCardRequested event,
    Emitter<NfcState> emit,
  ) async {
    emit(state.copyWith(
      registerStatus: NfcRegisterStatus.loading,
      registerError: null,
    ));
    final result =
        await repository.registerNfcCard(event.uid, event.deviceType);
    result.fold(
      (failure) => emit(state.copyWith(
        registerStatus: NfcRegisterStatus.failure,
        registerError: failure.message,
      )),
      (_) {
        emit(state.copyWith(registerStatus: NfcRegisterStatus.success));
        // Refresh status so the new card shows immediately
        add(const NfcDataRequested());
      },
    );
  }
}
