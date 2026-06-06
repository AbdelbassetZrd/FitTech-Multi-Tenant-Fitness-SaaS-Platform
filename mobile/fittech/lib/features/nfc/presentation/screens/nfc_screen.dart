import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fittech_theme.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../subscription/presentation/widgets/subscription_lock_overlay.dart';
import '../../domain/entities/access_log_entity.dart';
import '../../domain/entities/access_status_entity.dart';
import '../bloc/nfc_bloc.dart';

class NfcScreen extends StatelessWidget {
  const NfcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NfcBloc>(
      create: (_) => sl<NfcBloc>()..add(const NfcDataRequested()),
      child: const _NfcView(),
    );
  }
}

class _NfcView extends StatelessWidget {
  const _NfcView();

  Future<bool> _loadSubscription() async {
    final result = await sl<AuthRepository>().getProfile();
    return result.fold((_) => false, (u) => u.hasActiveSubscription);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1422),
      body: FitBackground(
        child: FutureBuilder<bool>(
          future: _loadSubscription(),
          builder: (context, subSnap) {
            final hasSubscription =
                subSnap.connectionState == ConnectionState.done &&
                    (subSnap.data ?? false);

            return SafeArea(
              child: Stack(
                children: [
                  BlocConsumer<NfcBloc, NfcState>(
                    listenWhen: (p, c) =>
                        (p.scanStatus != c.scanStatus &&
                            c.scanStatus != NfcScanStatus.scanning &&
                            c.scanStatus != NfcScanStatus.idle) ||
                        (p.registerStatus != c.registerStatus &&
                            c.registerStatus != NfcRegisterStatus.loading) ||
                        (p.phoneNfcStatus != c.phoneNfcStatus &&
                            c.phoneNfcStatus != NfcPhoneStatus.reading),
                    listener: (context, state) {
                      if (state.scanStatus == NfcScanStatus.granted ||
                          state.scanStatus == NfcScanStatus.denied ||
                          state.scanStatus == NfcScanStatus.failure) {
                        final granted =
                            state.scanStatus == NfcScanStatus.granted;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            backgroundColor: granted
                                ? FitColors.green
                                : Colors.redAccent.shade200,
                            content: Text(
                              granted
                                  ? 'Access granted ✓ ${state.lastScanReason ?? ''}'
                                  : 'Denied — ${state.scanError ?? state.lastScanReason ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ));
                      }
                      if (state.registerStatus == NfcRegisterStatus.success) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            backgroundColor: FitColors.green,
                            content: Text('NFC card registered ✓',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ));
                      } else if (state.registerStatus ==
                          NfcRegisterStatus.failure) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            backgroundColor: Colors.redAccent.shade200,
                            content: Text(
                              state.registerError ?? 'Registration failed.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ));
                      }
                      if (state.phoneNfcStatus == NfcPhoneStatus.success) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            backgroundColor: FitColors.green,
                            content: Text('Phone NFC registered ✓',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ));
                      } else if (state.phoneNfcStatus ==
                              NfcPhoneStatus.failure ||
                          state.phoneNfcStatus == NfcPhoneStatus.unavailable) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            backgroundColor: Colors.redAccent.shade200,
                            content: Text(
                              state.phoneNfcError ?? 'NFC scan failed.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ));
                      }
                    },
                    builder: (context, state) {
                      if (state.status == NfcLoadStatus.loading &&
                          state.accessStatus == null) {
                        return const Center(
                          child:
                              CircularProgressIndicator(color: FitColors.green),
                        );
                      }
                      if (state.status == NfcLoadStatus.failure &&
                          state.accessStatus == null) {
                        return _ErrorView(
                          message: state.error ?? 'Failed to load gym access.',
                          onRetry: () => context
                              .read<NfcBloc>()
                              .add(const NfcDataRequested()),
                        );
                      }

                      return RefreshIndicator(
                        color: FitColors.green,
                        backgroundColor: const Color(0xFF1A1F2E),
                        onRefresh: () async {
                          context.read<NfcBloc>().add(const NfcRefreshed());
                          await Future.delayed(
                              const Duration(milliseconds: 600));
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          children: [
                            _Header(status: state.accessStatus),
                            const SizedBox(height: 22),
                            const _SecureEntryHeading(),
                            const SizedBox(height: 16),
                            _ScanCard(
                              scanStatus: state.scanStatus,
                              hasDevice: state.accessStatus?.hasDevice ?? false,
                              onScan: () => context
                                  .read<NfcBloc>()
                                  .add(const NfcSimulateScanRequested()),
                            ),
                            const SizedBox(height: 18),
                            if (state.accessStatus?.subscriptionActive ??
                                false) ...[
                              _PhoneNfcButton(
                                isReading: state.phoneNfcStatus ==
                                    NfcPhoneStatus.reading,
                                hasDevice:
                                    state.accessStatus?.hasDevice ?? false,
                                onTap: () => context
                                    .read<NfcBloc>()
                                    .add(const NfcPhoneScanRequested()),
                              ),
                              const SizedBox(height: 18),
                            ],
                            _MembershipCard(status: state.accessStatus),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Text(
                                  'GYM HISTORY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.history,
                                      color: FitColors.muted, size: 20),
                                  onPressed: () => context
                                      .read<NfcBloc>()
                                      .add(const NfcRefreshed()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (state.history.isEmpty)
                              _EmptyHistory()
                            else
                              ..._groupedHistory(state.history),
                            const SizedBox(height: 18),
                            Center(
                              child: TextButton(
                                onPressed: () => context
                                    .read<NfcBloc>()
                                    .add(const NfcRefreshed(limit: 100)),
                                child: const Text(
                                  'VIEW ALL ACTIVITY',
                                  style: TextStyle(
                                    color: FitColors.muted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (!hasSubscription &&
                      subSnap.connectionState == ConnectionState.done)
                    SubscriptionLockOverlay(
                      onSubscribePressed: () =>
                          Navigator.pushNamed(context, '/subscription'),
                      title: 'GYM ACCESS LOCKED',
                      message:
                          'An active subscription is required to use your NFC card and access the gym.',
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _groupedHistory(List<AccessLogEntity> logs) {
    return [
      for (var i = 0; i < logs.length; i++) ...[
        _HistoryTile(log: logs[i]),
        if (i != logs.length - 1) const SizedBox(height: 10),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  final AccessStatusEntity? status;
  const _Header({required this.status});

  @override
  Widget build(BuildContext context) {
    final connected = status?.isConnected ?? false;
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'GYM ACCESS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const Spacer(),
        Text(
          status?.roleLabel ?? (connected ? 'ACTIVE MEMBER' : 'INACTIVE'),
          style: TextStyle(
            color: connected ? FitColors.green : Colors.redAccent.shade100,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

class _SecureEntryHeading extends StatelessWidget {
  const _SecureEntryHeading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2A3D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: FitColors.green.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded,
              color: FitColors.green, size: 26),
        ),
        const SizedBox(height: 10),
        const Text(
          'SECURE ENTRY POINT',
          style: TextStyle(
            color: FitColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  final NfcScanStatus scanStatus;
  final bool hasDevice;
  final VoidCallback onScan;

  const _ScanCard({
    required this.scanStatus,
    required this.onScan,
    this.hasDevice = true,
  });

  @override
  Widget build(BuildContext context) {
    final scanning = scanStatus == NfcScanStatus.scanning;
    final cardColor = hasDevice ? FitColors.green : const Color(0xFF2A3348);
    final borderGlow = hasDevice
        ? FitColors.green.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.06);
    return InkWell(
      onTap: (scanning || !hasDevice) ? null : onScan,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF101728),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: borderGlow,
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasDevice)
                  Icon(Icons.credit_card_off_rounded,
                      size: 64, color: Colors.white.withValues(alpha: 0.35))
                else if (scanning)
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                  )
                else
                  const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 64,
                    color: Color(0xFF0F2417),
                  ),
                const SizedBox(height: 12),
                Text(
                  !hasDevice
                      ? 'NO CARD REGISTERED'
                      : scanning
                          ? 'SCANNING…'
                          : 'TAP TO SCAN',
                  style: TextStyle(
                    color: hasDevice
                        ? const Color(0xFF0F2417)
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final AccessStatusEntity? status;
  const _MembershipCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final subActive = status?.subscriptionActive ?? false;
    final hasCard = status?.hasDevice ?? false;
    final connected = subActive && hasCard;
    final id = status?.membershipId ?? 'FT-—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MEMBERSHIP ID',
                  style: TextStyle(
                    color: FitColors.muted,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connected
                          ? FitColors.green
                          : subActive
                              ? Colors.orangeAccent
                              : Colors.redAccent.shade100,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connected
                        ? 'CONNECTED'
                        : subActive
                            ? 'NO CARD'
                            : 'INACTIVE',
                    style: TextStyle(
                      color: connected
                          ? FitColors.green
                          : subActive
                              ? Colors.orangeAccent
                              : Colors.redAccent.shade100,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                !hasCard
                    ? 'NO CARD'
                    : status?.deviceType?.toUpperCase() == 'PHONE'
                        ? 'PHONE NFC'
                        : 'NFC CARD',
                style: const TextStyle(
                  color: FitColors.muted,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegisterCardPanel extends StatefulWidget {
  final bool isLoading;
  final void Function(String uid, String deviceType) onRegister;

  const _RegisterCardPanel({
    required this.isLoading,
    required this.onRegister,
  });

  @override
  State<_RegisterCardPanel> createState() => _RegisterCardPanelState();
}

class _RegisterCardPanelState extends State<_RegisterCardPanel> {
  final _uidController = TextEditingController();
  String _deviceType = 'card';

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  void _submit() {
    final uid = _uidController.text.trim().replaceAll(':', '').toUpperCase();
    if (uid.isEmpty) return;
    widget.onRegister(uid, _deviceType);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FitColors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FitColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_card_rounded,
                    color: FitColors.green, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'REGISTER NFC CARD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _uidController,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter or paste card UID',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF0E1422),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: FitColors.green.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TypeChip(
                label: '🪪  Card',
                selected: _deviceType == 'card',
                onTap: () => setState(() => _deviceType = 'card'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: '📱  Phone',
                selected: _deviceType == 'phone',
                onTap: () => setState(() => _deviceType = 'phone'),
              ),
              const Spacer(),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FitColors.green,
                    foregroundColor: const Color(0xFF0F2417),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    elevation: 0,
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('REGISTER',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You can find your card UID printed on the card, or ask an admin to scan it.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? FitColors.green.withValues(alpha: 0.15)
              : const Color(0xFF0E1422),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? FitColors.green.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? FitColors.green : FitColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PhoneNfcButton extends StatelessWidget {
  final bool isReading;
  final bool hasDevice;
  final VoidCallback onTap;

  const _PhoneNfcButton(
      {required this.isReading, required this.hasDevice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isReading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isReading
                ? FitColors.green.withValues(alpha: 0.6)
                : FitColors.green.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FitColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isReading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: FitColors.green),
                    )
                  : const Icon(Icons.nfc_rounded,
                      color: FitColors.green, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReading
                        ? (hasDevice ? 'HOLD CARD TO PHONE…' : 'REGISTERING…')
                        : hasDevice
                            ? 'SCAN ACCESS'
                            : 'REGISTER PHONE NFC',
                    style: TextStyle(
                      color: isReading ? FitColors.green : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isReading
                        ? (hasDevice
                            ? 'Tap your phone to the NFC reader'
                            : 'Please wait…')
                        : hasDevice
                            ? 'Tap your phone to check gym access'
                            : 'Register your phone as your NFC access card',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!isReading)
              Icon(Icons.chevron_right_rounded,
                  color: FitColors.green.withValues(alpha: 0.6), size: 22),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AccessLogEntity log;
  const _HistoryTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateLabel(log.timestamp);
    final timeLabel =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';
    final color = log.allowed ? FitColors.green : Colors.redAccent.shade100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              log.allowed
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.deviceUid != null
                      ? 'FitTech Gym'
                      : (log.allowed ? 'FitTech Gym' : 'Access Attempt'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel · $timeLabel',
                  style: const TextStyle(
                    color: FitColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                log.allowed ? 'GRANTED' : 'DENIED',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 90,
                child: Text(
                  log.reason,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FitColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: const Center(
        child: Text(
          'No gym entries yet — tap to scan once you reach the gate.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FitColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: FitColors.muted, size: 36),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: FitColors.green),
              onPressed: onRetry,
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}
