part of 'nfc_bloc.dart';

enum NfcLoadStatus { initial, loading, success, failure }

enum NfcScanStatus { idle, scanning, granted, denied, failure }

enum NfcRegisterStatus { idle, loading, success, failure }

enum NfcPhoneStatus { idle, reading, success, unavailable, failure }

class NfcState extends Equatable {
  final NfcLoadStatus status;
  final AccessStatusEntity? accessStatus;
  final List<AccessLogEntity> history;
  final String? error;

  final NfcScanStatus scanStatus;
  final String? scanError;
  final String? lastScanReason;

  final NfcRegisterStatus registerStatus;
  final String? registerError;

  final NfcPhoneStatus phoneNfcStatus;
  final String? phoneNfcError;

  const NfcState({
    this.status = NfcLoadStatus.initial,
    this.accessStatus,
    this.history = const [],
    this.error,
    this.scanStatus = NfcScanStatus.idle,
    this.scanError,
    this.lastScanReason,
    this.registerStatus = NfcRegisterStatus.idle,
    this.registerError,
    this.phoneNfcStatus = NfcPhoneStatus.idle,
    this.phoneNfcError,
  });

  NfcState copyWith({
    NfcLoadStatus? status,
    AccessStatusEntity? accessStatus,
    List<AccessLogEntity>? history,
    String? error,
    NfcScanStatus? scanStatus,
    String? scanError,
    String? lastScanReason,
    NfcRegisterStatus? registerStatus,
    String? registerError,
    NfcPhoneStatus? phoneNfcStatus,
    String? phoneNfcError,
  }) {
    return NfcState(
      status: status ?? this.status,
      accessStatus: accessStatus ?? this.accessStatus,
      history: history ?? this.history,
      error: error,
      scanStatus: scanStatus ?? this.scanStatus,
      scanError: scanError,
      lastScanReason: lastScanReason ?? this.lastScanReason,
      registerStatus: registerStatus ?? this.registerStatus,
      registerError: registerError,
      phoneNfcStatus: phoneNfcStatus ?? this.phoneNfcStatus,
      phoneNfcError: phoneNfcError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        accessStatus,
        history,
        error,
        scanStatus,
        scanError,
        lastScanReason,
        registerStatus,
        registerError,
        phoneNfcStatus,
        phoneNfcError,
      ];
}
