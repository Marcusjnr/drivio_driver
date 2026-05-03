import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';

class VehicleChangePage extends ConsumerStatefulWidget {
  const VehicleChangePage({super.key});

  @override
  ConsumerState<VehicleChangePage> createState() => _VehicleChangePageState();
}

class _VehicleChangePageState extends ConsumerState<VehicleChangePage> {
  int _reason = 0;
  late final TextEditingController _make;
  late final TextEditingController _year;
  late final TextEditingController _plate;

  @override
  void initState() {
    super.initState();
    _make = TextEditingController();
    _year = TextEditingController();
    _plate = TextEditingController();
  }

  @override
  void dispose() {
    _make.dispose();
    _year.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> reasons = const <String>[
      'Sold my car',
      'Got a newer car',
      'Repairs — temporary swap',
      'Other',
    ];
    return DetailScaffold(
      title: 'Request vehicle change',
      footer: DrivioButton(
        label: 'Submit request',
        onPressed: () => AppNavigation.pop(),
      ),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.amber.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
            border: Border.all(color: context.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('⚠️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vehicle changes require re-verification (usually 24-48 hours). You can stay online with your current vehicle while we review.',
                  style: TextStyle(fontSize: 12, color: context.text, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('CURRENT VEHICLE',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('🚘', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Toyota Corolla · 2020',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LAG 234 AB · White',
                      style: TextStyle(fontSize: 12, color: context.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('REASON', style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Column(
          children: List<Widget>.generate(reasons.length, (int i) {
            final bool selected = i == _reason;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => setState(() => _reason = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? context.accent : context.border,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? context.accent : context.borderStrong,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: selected
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.accent,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        reasons[i],
                        style: TextStyle(fontSize: 13, color: context.text),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text('NEW VEHICLE DETAILS',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        DrivioInput(
          label: 'Make & model',
          hint: 'e.g. Honda Civic',
          controller: _make,
          compact: true,
        ),
        const SizedBox(height: 10),
        DrivioInput(
          label: 'Year',
          hint: '2022',
          controller: _year,
          compact: true,
        ),
        const SizedBox(height: 10),
        DrivioInput(
          label: 'Plate number',
          hint: 'LAG 000 AA',
          controller: _plate,
          compact: true,
        ),
      ],
    );
  }
}
