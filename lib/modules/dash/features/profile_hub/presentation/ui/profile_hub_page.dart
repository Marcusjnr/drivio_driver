import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/driver_rating.dart';
import 'package:drivio_driver/modules/commons/types/profile.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/dash/features/profile_hub/presentation/logic/controller/profile_hub_controller.dart';
import 'package:drivio_driver/modules/dash/features/profile_hub/presentation/ui/widgets/profile_hub_shimmer.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';

class ProfileHubPage extends ConsumerStatefulWidget {
  const ProfileHubPage({super.key});

  @override
  ConsumerState<ProfileHubPage> createState() => _ProfileHubPageState();
}

class _ProfileHubPageState extends ConsumerState<ProfileHubPage> {
  @override
  void initState() {
    super.initState();
    // Subscription state powers the ACCOUNT row; refresh once on
    // mount so we don't show stale "ACTIVE · 18 days" if the page
    // reopens after an expiry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subscriptionControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ProfileHubState state = ref.watch(profileHubControllerProvider);
    final ProfileHubController c =
        ref.read(profileHubControllerProvider.notifier);
    final SubscriptionState subState =
        ref.watch(subscriptionControllerProvider);

    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.profile),
      child: RefreshIndicator(
        onRefresh: c.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (state.isLoading && state.profile == null)
                // Shimmer skeleton matches the loaded layout 1:1 so the
                // page doesn't reflow once data arrives.
                const ProfileHubShimmer()
              else ...<Widget>[
                _Header(state: state),
                const SizedBox(height: 16),
                _StatsRow(state: state),
                const SizedBox(height: 18),
                _VehicleGroup(state: state),
                const SizedBox(height: 16),
                _DocumentsGroup(state: state),
                const SizedBox(height: 16),
                _ReviewsGroup(state: state),
                const SizedBox(height: 16),
                _AccountGroup(state: state, subState: subState),
                const SizedBox(height: 16),
                _SettingsGroup(),
              ],
              if (state.error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: AppTextStyles.bodySm.copyWith(color: context.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    final Profile? p = state.profile;
    final String name = p?.fullName.trim().isNotEmpty == true
        ? p!.fullName
        : 'Driver';
    // Stable avatar variant per-user so the colour doesn't shift on
    // every rebuild.
    final int variant = (p?.userId.hashCode.abs() ?? 0) % 4;
    final double rating = state.summary.ratingAvg ?? 0;
    final int trips = state.summary.lifetimeTrips;
    return Row(
      children: <Widget>[
        Avatar(name: name, variant: variant, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: AppTextStyles.h2.copyWith(color: context.text)),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Rating(value: rating == 0 ? 0 : rating),
                  const SizedBox(width: 8),
                  Text(
                    '· ${_fmtTrips(trips)}',
                    style: TextStyle(fontSize: 12, color: context.textDim),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.summary.isVerified)
          const Pill(text: 'VERIFIED', tone: PillTone.accent)
        else if (state.summary.kycStatus == 'pending_review')
          const Pill(text: 'IN REVIEW', tone: PillTone.amber)
        else
          const Pill(text: 'UNVERIFIED', tone: PillTone.neutral),
      ],
    );
  }

  static String _fmtTrips(int n) {
    if (n == 0) return 'No trips yet';
    if (n == 1) return '1 trip';
    return '${_groupThousands(n)} trips';
  }

  static String _groupThousands(int n) {
    final String s = n.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

// ── Stats row ──────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    final DateTime? joined = state.summary.joinedAt;
    final String joinedLabel = joined == null ? '—' : _monthYear(joined);
    final int lifetimeNaira = state.summary.lifetimeEarningsNaira;
    final String lifetimeLabel = lifetimeNaira == 0
        ? '₦0'
        : NairaFormatter.formatCompact(lifetimeNaira);
    final String vehicleLabel =
        state.summary.activeVehicleModel ?? 'None';
    return Row(
      children: <Widget>[
        Expanded(child: _Stat(label: 'Joined', value: joinedLabel)),
        const SizedBox(width: 8),
        Expanded(child: _Stat(label: 'Lifetime', value: lifetimeLabel)),
        const SizedBox(width: 8),
        Expanded(child: _Stat(label: 'Vehicle', value: vehicleLabel)),
      ],
    );
  }

  /// Month + 4-digit year, e.g. `May 2026`. The earlier shorthand
  /// (`May '26`) reads ambiguously as "May 26th" so the apostrophe
  /// form is gone.
  static String _monthYear(DateTime t) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final String month = m[(t.month - 1).clamp(0, 11)];
    return '$month ${t.year}';
  }
}

// ── VEHICLE group ──────────────────────────────────────────────────────

class _VehicleGroup extends StatelessWidget {
  const _VehicleGroup({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    final Vehicle? v = state.activeVehicle;
    final String vehicleTitle = v == null
        ? 'No active vehicle'
        : '${v.make} ${v.model}${v.year > 0 ? ' · ${v.year}' : ''}';
    final String? colour = v?.colour;
    final String vehicleSub = v == null
        ? 'Add or activate one to receive requests'
        : '${v.plate}${(colour == null || colour.isEmpty) ? '' : ' · ${colour.toLowerCase()}'}';
    return _Group(
      title: 'VEHICLE',
      children: <Widget>[
        FieldRow(
          label: vehicleTitle,
          value: vehicleSub,
          onTap: v == null
              ? () => AppNavigation.push(AppRoutes.addVehicle)
              : () => AppNavigation.push(AppRoutes.vehicleDetails),
        ),
        _DocLinkRow(
          label: 'Insurance',
          kind: DocumentKind.insurance,
          doc: state.documentsByKind[DocumentKind.insurance],
        ),
        _DocLinkRow(
          label: 'Vehicle inspection',
          kind: DocumentKind.inspectionReport,
          doc: state.documentsByKind[DocumentKind.inspectionReport],
          isLast: true,
        ),
      ],
    );
  }
}

// ── DOCUMENTS group ────────────────────────────────────────────────────

class _DocumentsGroup extends StatelessWidget {
  const _DocumentsGroup({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    return _Group(
      title: 'DOCUMENTS',
      children: <Widget>[
        _DocLinkRow(
          label: "Driver's licence",
          kind: DocumentKind.driversLicence,
          doc: state.documentsByKind[DocumentKind.driversLicence],
        ),
        _DocLinkRow(
          label: 'Vehicle registration',
          kind: DocumentKind.vehicleReg,
          doc: state.documentsByKind[DocumentKind.vehicleReg],
        ),
        _DocLinkRow(
          // "Background check" stored under road_worthiness per Q1.
          label: 'Background check',
          kind: DocumentKind.roadWorthiness,
          doc: state.documentsByKind[DocumentKind.roadWorthiness],
          isLast: true,
        ),
      ],
    );
  }
}

/// One row showing a document's status (Verified / In review / Required
/// / Re-do / Renew). Tapping it routes to the same KYC document
/// capture flow used during onboarding (per Q3) so the driver can
/// upload or re-upload using a familiar UI.
class _DocLinkRow extends StatelessWidget {
  const _DocLinkRow({
    required this.label,
    required this.kind,
    required this.doc,
    this.isLast = false,
  });

  final String label;
  final DocumentKind kind;
  final Document? doc;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (String value, IconData? icon, Color color) = _summarise(context);
    return FieldRow(
      label: label,
      value: value,
      divider: !isLast,
      onTap: () => AppNavigation.push(
        AppRoutes.kycDocumentCapture,
        arguments: kind,
      ),
      right: icon == null
          ? null
          : Icon(icon, size: 18, color: color),
    );
  }

  (String, IconData?, Color) _summarise(BuildContext context) {
    if (doc == null) {
      return ('Required', DrivioIcons.chevron, context.textMuted);
    }
    switch (doc!.status) {
      case DocumentStatus.approved:
        // Show expiry inline if set.
        final String detail = doc!.expiresOn == null
            ? 'Verified'
            : 'Verified · expires ${_fmtDate(doc!.expiresOn!)}';
        return (detail, DrivioIcons.checkCircle, context.accent);
      case DocumentStatus.pending:
        return ('In review', DrivioIcons.refresh, context.amber);
      case DocumentStatus.rejected:
        return ('Re-upload', DrivioIcons.close, context.red);
      case DocumentStatus.expired:
        return ('Expired — renew', DrivioIcons.refresh, context.amber);
    }
  }

  static String _fmtDate(DateTime t) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[(t.month - 1).clamp(0, 11)]} ${t.day}';
  }
}

// ── REVIEWS group ──────────────────────────────────────────────────────

class _ReviewsGroup extends StatelessWidget {
  const _ReviewsGroup({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    final DriverRating? top = state.topReview;
    return _Group(
      title: 'REVIEWS',
      children: <Widget>[
        InkWell(
          onTap: () => AppNavigation.push(AppRoutes.reviews),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: top == null
                ? _NoReviewsYet()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Avatar(
                            name: top.passengerName,
                            variant:
                                top.passengerId.hashCode.abs() % 4,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${top.passengerName} · ${_relAge(top.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Rating(value: top.rating.toDouble()),
                              ],
                            ),
                          ),
                          Icon(DrivioIcons.chevron,
                              size: 14, color: context.textMuted),
                        ],
                      ),
                      if (top.comment != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          '"${top.comment}"',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textDim,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        state.summary.ratingCount > 1
                            ? 'See all ${state.summary.ratingCount} reviews →'
                            : 'See all reviews →',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  static String _relAge(DateTime t) {
    final Duration d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
    return '${(d.inDays / 365).floor()}y ago';
  }
}

class _NoReviewsYet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text('🌱', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Reviews from your passengers show up here.',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
        ),
        Icon(DrivioIcons.chevron, size: 14, color: context.textMuted),
      ],
    );
  }
}

// ── ACCOUNT group ──────────────────────────────────────────────────────

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.state, required this.subState});
  final ProfileHubState state;
  final SubscriptionState subState;

  @override
  Widget build(BuildContext context) {
    final Subscription? sub = subState.subscription;
    final (String subSubtitle, String pillText, PillTone pillTone) =
        _subStatus(sub);
    final String referralValue = state.profile?.referralCode ?? '—';
    return _Group(
      title: 'ACCOUNT',
      children: <Widget>[
        InkWell(
          onTap: () => AppNavigation.push(AppRoutes.subscriptionManage),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.14),
                    border: Border.all(color: context.accent.withValues(alpha: 0.28)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('💳', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Subscription & billing',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subSubtitle,
                        style: TextStyle(fontSize: 12, color: context.textDim),
                      ),
                    ],
                  ),
                ),
                Pill(text: pillText, tone: pillTone),
                const SizedBox(width: 4),
                Icon(DrivioIcons.chevron, size: 14, color: context.textMuted),
              ],
            ),
          ),
        ),
        FieldRow(
          label: 'Manage payment',
          onTap: () => AppNavigation.push(AppRoutes.paymentMethods),
        ),
        FieldRow(
          label: 'Referral code',
          value: referralValue,
          divider: false,
          onTap: () => AppNavigation.push(AppRoutes.referral),
        ),
      ],
    );
  }

  (String, String, PillTone) _subStatus(Subscription? sub) {
    if (sub == null) {
      return ('No subscription', 'NONE', PillTone.neutral);
    }
    final String subtitle = () {
      final int? days = sub.daysRemaining;
      switch (sub.status) {
        case SubscriptionStatus.trialing:
          return days == null
              ? 'Trial · ends soon'
              : 'Trial · $days days left';
        case SubscriptionStatus.active:
          return days == null
              ? 'Drivio Pro · active'
              : 'Drivio Pro · $days days until renewal';
        case SubscriptionStatus.pastDue:
          return days == null
              ? 'Payment overdue · grace period'
              : 'Payment overdue · $days days grace';
        case SubscriptionStatus.expired:
          return 'Expired — tap to reactivate';
        case SubscriptionStatus.cancelled:
          return 'Cancelled';
      }
    }();
    final (String pillText, PillTone pillTone) = switch (sub.status) {
      SubscriptionStatus.trialing => ('TRIAL', PillTone.blue),
      SubscriptionStatus.active => ('ACTIVE', PillTone.accent),
      SubscriptionStatus.pastDue => ('PAST DUE', PillTone.amber),
      SubscriptionStatus.expired => ('EXPIRED', PillTone.red),
      SubscriptionStatus.cancelled => ('CANCELLED', PillTone.neutral),
    };
    return (subtitle, pillText, pillTone);
  }
}

// ── SETTINGS group ─────────────────────────────────────────────────────

/// Notification preferences row removed per Q4/Q7 — they aren't wired
/// to a server-side store yet, and shipping a non-persisting toggle
/// page would be misleading.
class _SettingsGroup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Group(
      title: 'SETTINGS',
      children: <Widget>[
        FieldRow(
          label: 'Edit profile',
          onTap: () => AppNavigation.push(AppRoutes.profileEdit),
        ),
        FieldRow(
          label: 'Appearance',
          onTap: () => AppNavigation.push(AppRoutes.appearance),
        ),
        FieldRow(
          label: 'Help & support',
          onTap: () => AppNavigation.push(AppRoutes.help),
        ),
        FieldRow(
          label: 'Sign out',
          divider: false,
          onTap: () => AppNavigation.push(AppRoutes.signOut),
        ),
      ],
    );
  }
}

// ── Shared bits ────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(),
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.metricVal.copyWith(color: context.text)),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
