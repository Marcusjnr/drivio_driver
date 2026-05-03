import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/controller/add_vehicle_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';

class AddVehiclePage extends ConsumerStatefulWidget {
  const AddVehiclePage({super.key});

  @override
  ConsumerState<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends ConsumerState<AddVehiclePage> {
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _color;
  late final TextEditingController _plate;

  @override
  void initState() {
    super.initState();
    _make = TextEditingController();
    _model = TextEditingController();
    _year = TextEditingController();
    _color = TextEditingController();
    _plate = TextEditingController();
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AddVehicleState state = ref.watch(addVehicleControllerProvider);
    final AddVehicleController c =
        ref.read(addVehicleControllerProvider.notifier);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 10),
                Text(
                  'STEP 1 OF 2',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                    fontFamily: 'monospace',
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tell us about\nyour vehicle.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'This appears to riders when you accept a trip.',
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: DrivioInput(
                    label: 'Make',
                    hint: 'Toyota',
                    controller: _make,
                    onChanged: c.onMakeChanged,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DrivioInput(
                    label: 'Model',
                    hint: 'Corolla',
                    controller: _model,
                    onChanged: c.onModelChanged,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: DrivioInput(
                    label: 'Year',
                    hint: '2020',
                    keyboardType: TextInputType.number,
                    controller: _year,
                    onChanged: c.onYearChanged,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DrivioInput(
                    label: 'Colour',
                    hint: 'White',
                    controller: _color,
                    onChanged: c.onColourChanged,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DrivioInput(
              label: 'Licence plate',
              controller: _plate,
              onChanged: c.onPlateChanged,
              hint: 'LAG 234 AB',
              compact: true,
            ),
            const SizedBox(height: 16),
            Text(
              'DOCUMENTS',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 8),
            _UploadCard(
              label: 'Vehicle registration',
              kind: DocumentKind.vehicleReg,
            ),
            const SizedBox(height: 8),
            _UploadCard(
              label: 'Proof of insurance',
              kind: DocumentKind.insurance,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 16),
            DrivioButton(
              label: state.isLoading ? 'Saving…' : 'Save & submit for review',
              disabled: !state.canSubmit || state.isLoading,
              onPressed: () async {
                final Vehicle? vehicle = await c.submit();
                if (!mounted || vehicle == null) return;
                ref.read(homeControllerProvider.notifier).setHasVehicle(true);
                AppNavigation.replaceAll<void>(AppRoutes.home);
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Review takes under 15 minutes on average.',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadCard extends ConsumerWidget {
  const _UploadCard({required this.label, required this.kind});

  final String label;
  final DocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DocumentSlotState slot =
        ref.watch(addVehicleControllerProvider.select(
      (AddVehicleState s) => s.slot(kind),
    ));
    final AddVehicleController c =
        ref.read(addVehicleControllerProvider.notifier);

    final bool uploaded = slot.isUploaded;
    final bool busy = slot.isUploading;
    final Color borderColor =
        uploaded ? context.accent : context.borderStrong;
    final IconData trailingIcon = uploaded
        ? DrivioIcons.check
        : busy
            ? DrivioIcons.refresh
            : DrivioIcons.plus;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy
          ? null
          : () => _openSourceSheet(context, c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            const Text('📄', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    busy
                        ? 'Uploading…'
                        : uploaded
                            ? (slot.fileName ?? 'Uploaded')
                            : 'Tap to upload · PDF or photo',
                    style: TextStyle(
                      fontSize: 11,
                      color: uploaded
                          ? context.accent
                          : (slot.error != null
                              ? context.red
                              : context.textDim),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (slot.error != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      slot.error!,
                      style: TextStyle(fontSize: 11, color: context.red),
                    ),
                  ],
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accent,
                ),
              )
            else if (uploaded)
              GestureDetector(
                onTap: () => c.clearSlot(kind),
                child: Icon(DrivioIcons.close,
                    size: 18, color: context.textDim),
              )
            else
              Icon(trailingIcon, size: 18, color: context.textDim),
          ],
        ),
      ),
    );
  }

  Future<void> _openSourceSheet(
      BuildContext context, AddVehicleController c) async {
    final DocPickerSource? choice = await showModalBottomSheet<DocPickerSource>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: ctx.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  'Add document',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: ctx.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SheetOption(
                  icon: DrivioIcons.camera,
                  label: 'Take a photo',
                  onTap: () =>
                      Navigator.of(ctx).pop(DocPickerSource.camera),
                ),
                _SheetOption(
                  icon: DrivioIcons.image,
                  label: 'Choose from gallery',
                  onTap: () =>
                      Navigator.of(ctx).pop(DocPickerSource.gallery),
                ),
                _SheetOption(
                  icon: DrivioIcons.document,
                  label: 'Choose a PDF',
                  onTap: () => Navigator.of(ctx).pop(DocPickerSource.file),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null) {
      await c.pickAndUploadDocument(kind, choice);
    }
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: context.text),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.body.copyWith(color: context.text),
            ),
          ],
        ),
      ),
    );
  }
}
