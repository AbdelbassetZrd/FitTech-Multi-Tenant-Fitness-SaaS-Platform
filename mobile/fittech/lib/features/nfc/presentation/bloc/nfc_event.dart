part of 'nfc_bloc.dart';

abstract class NfcEvent extends Equatable {
  const NfcEvent();
  @override
  List<Object?> get props => [];
}

class NfcDataRequested extends NfcEvent {
  final int limit;
  const NfcDataRequested({this.limit = 20});
  @override
  List<Object?> get props => [limit];
}

class NfcRefreshed extends NfcEvent {
  final int limit;
  const NfcRefreshed({this.limit = 20});
  @override
  List<Object?> get props => [limit];
}

class NfcSimulateScanRequested extends NfcEvent {
  const NfcSimulateScanRequested();
}

class NfcRegisterCardRequested extends NfcEvent {
  final String uid;
  final String deviceType;
  const NfcRegisterCardRequested({required this.uid, this.deviceType = 'card'});
  @override
  List<Object?> get props => [uid, deviceType];
}

class NfcPhoneScanRequested extends NfcEvent {
  const NfcPhoneScanRequested();
}
