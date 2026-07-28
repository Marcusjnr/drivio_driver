import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/driver_amenities_repository.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/commons/utils/amenity_icons.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/controller/add_vehicle_controller.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/vehicle_options.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';

class AddVehiclePage extends ConsumerStatefulWidget {
  const AddVehiclePage({super.key});

  @override
  ConsumerState<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends ConsumerState<AddVehiclePage> {
  late final TextEditingController _plate;
  late final TextEditingController _vin;
  late final TextEditingController _mileage;

  @override
  void initState() {
    super.initState();
    _plate = TextEditingController();
    _vin = TextEditingController();
    _mileage = TextEditingController();
  }

  @override
  void dispose() {
    _plate.dispose();
    _vin.dispose();
    _mileage.dispose();
    super.dispose();
  }

  List<String> _years() {
    final int now = DateTime.now().year;
    return <String>[
      for (int y = now; y >= kMinVehicleYear; y--) y.toString(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AddVehicleState state = ref.watch(addVehicleControllerProvider);
    final AddVehicleController c =
        ref.read(addVehicleControllerProvider.notifier);

    final List<String> models = modelsForMake(state.make);
    final bool freeTextModel =
        state.make.isEmpty || state.make == 'Other' || models.isEmpty;

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
                  style: AppTextStyles.mono.copyWith(
                    color: context.textMuted,
                    letterSpacing: 1.8,
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

            // Make + Model — searchable pickers.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _SelectField(
                    label: 'Make',
                    value: state.make.isEmpty ? null : state.make,
                    hint: 'Toyota',
                    onTap: () async {
                      final String? picked = await _pickOne(
                        context,
                        title: 'Select make',
                        options: kVehicleMakeNames,
                      );
                      if (picked != null) c.onMakeChanged(picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: freeTextModel
                      ? _InlineTextField(
                          label: 'Model',
                          hint: 'Corolla',
                          initial: state.model,
                          onChanged: c.onModelChanged,
                        )
                      : _SelectField(
                          label: 'Model',
                          value: state.model.isEmpty ? null : state.model,
                          hint: 'Corolla',
                          onTap: () async {
                            final String? picked = await _pickOne(
                              context,
                              title: 'Select model',
                              options: models,
                            );
                            if (picked != null) c.onModelChanged(picked);
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Year + Colour.
            Row(
              children: <Widget>[
                Expanded(
                  child: _SelectField(
                    label: 'Year',
                    value: state.year.isEmpty ? null : state.year,
                    hint: '2020',
                    onTap: () async {
                      final String? picked = await _pickOne(
                        context,
                        title: 'Select year',
                        options: _years(),
                      );
                      if (picked != null) c.onYearChanged(picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SelectField(
                    label: 'Colour',
                    value: state.colour.isEmpty ? null : state.colour,
                    hint: 'White',
                    onTap: () async {
                      final String? picked = await _pickColour(context);
                      if (picked != null) c.onColourChanged(picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Transmission + Fuel type.
            Row(
              children: <Widget>[
                Expanded(
                  child: _SelectField(
                    label: 'Transmission',
                    value: _labelFor(kTransmissionOptions, state.transmission),
                    hint: 'Automatic',
                    onTap: () async {
                      final String? picked = await _pickPair(
                        context,
                        title: 'Transmission',
                        options: kTransmissionOptions,
                      );
                      if (picked != null) c.onTransmissionChanged(picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SelectField(
                    label: 'Fuel type',
                    value: _labelFor(kFuelTypeOptions, state.fuelType),
                    hint: 'Fuel',
                    onTap: () async {
                      final String? picked = await _pickPair(
                        context,
                        title: 'Fuel type',
                        options: kFuelTypeOptions,
                      );
                      if (picked != null) c.onFuelTypeChanged(picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Licence plate.
            DrivioInput(
              label: 'Licence plate',
              controller: _plate,
              onChanged: c.onPlateChanged,
              hint: 'LAG 234 AB',
              compact: true,
            ),
            if (state.plate.trim().isNotEmpty && !state.hasValidPlate) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Plate should be 6–10 letters and numbers, like LAG 234 AB.',
                style: AppTextStyles.captionSm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 10),

            // VIN + mileage.
            DrivioInput(
              label: 'Vehicle Identification Number (VIN)',
              controller: _vin,
              onChanged: c.onVinChanged,
              hint: 'e.g. JT2BF22K1W0123456',
              compact: true,
            ),
            if (state.vin.trim().isNotEmpty && !state.hasValidVin) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Enter the VIN from your registration (usually 17 characters).',
                style: AppTextStyles.captionSm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 10),
            DrivioInput(
              label: 'Current mileage (KM)',
              controller: _mileage,
              onChanged: c.onMileageChanged,
              hint: '85000',
              keyboardType: TextInputType.number,
              compact: true,
            ),
            const SizedBox(height: 18),

            // Amenities — pick at least one.
            _AmenitiesSection(state: state, controller: c),
            const SizedBox(height: 18),

            // Documents + photos.
            Text(
              'DOCUMENTS',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 8),
            _UploadCard(
              label: 'Vehicle registration',
              kind: DocumentKind.vehicleReg,
            ),
            const SizedBox(height: 18),
            Text(
              'VEHICLE PHOTOS',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 8),
            _UploadCard(label: 'Front', kind: DocumentKind.vehiclePhotoFront),
            const SizedBox(height: 8),
            _UploadCard(label: 'Back', kind: DocumentKind.vehiclePhotoBack),
            const SizedBox(height: 8),
            _UploadCard(label: 'Side', kind: DocumentKind.vehiclePhotoSide),
            const SizedBox(height: 8),
            _UploadCard(
                label: 'Interior', kind: DocumentKind.vehiclePhotoInterior),

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
                if (AppNavigation.canPop()) {
                  AppNavigation.pop();
                } else {
                  AppNavigation.replaceAll<void>(AppRoutes.home);
                }
                Future<void>.delayed(
                  const Duration(milliseconds: 800),
                  c.endLoading,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Colour picker: 10 primaries + "Other…" that reveals 20 more.
  Future<String?> _pickColour(BuildContext context) async {
    final String? first = await _pickOne(
      context,
      title: 'Select colour',
      options: <String>[...kPrimaryColours, 'Other…'],
    );
    if (first == null) return null;
    if (first != 'Other…') return first;
    if (!context.mounted) return null;
    return _pickOne(context, title: 'More colours', options: kMoreColours);
  }
}

/// Resolves a (wire,label) pair list to the label for a stored wire value.
String? _labelFor(List<(String, String)> options, String? wire) {
  if (wire == null) return null;
  for (final (String, String) o in options) {
    if (o.$1 == wire) return o.$2;
  }
  return null;
}

/// Opens a searchable single-select sheet; returns the chosen string.
Future<String?> _pickOne(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) => _PickerSheet(title: title, options: options),
  );
}

/// Same as [_pickOne] but for (wire,label) pairs; returns the wire value.
Future<String?> _pickPair(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
}) async {
  final String? label = await _pickOne(
    context,
    title: title,
    options: options.map((o) => o.$2).toList(growable: false),
  );
  if (label == null) return null;
  for (final (String, String) o in options) {
    if (o.$2 == label) return o.$1;
  }
  return null;
}

/// A tappable field that looks like a DrivioInput but opens a picker sheet.
class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool filled = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.captionSm.copyWith(color: context.textDim),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: AppRadius.md,
              border: Border.all(color: context.borderStrong),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    filled ? value! : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: filled ? context.text : context.textMuted,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded,
                    size: 20, color: context.textDim),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline text field for the free-text model when the make isn't curated.
class _InlineTextField extends StatefulWidget {
  const _InlineTextField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<_InlineTextField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(_InlineTextField old) {
    super.didUpdateWidget(old);
    // Keep in sync when a make change clears the model.
    if (widget.initial.isEmpty && _ctrl.text.isNotEmpty) {
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DrivioInput(
      label: widget.label,
      hint: widget.hint,
      controller: _ctrl,
      onChanged: widget.onChanged,
      compact: true,
    );
  }
}

/// Searchable single-select bottom sheet.
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final List<String> filtered = q.isEmpty
        ? widget.options
        : widget.options
            .where((String o) => o.toLowerCase().contains(q))
            .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                widget.title,
                style: AppTextStyles.bodyLg.copyWith(
                  color: context.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.bg,
                  borderRadius: AppRadius.md,
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search_rounded,
                        size: 18, color: context.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        style:
                            AppTextStyles.body.copyWith(color: context.text),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          border: InputBorder.none,
                          hintText: 'Search',
                          hintStyle: AppTextStyles.body
                              .copyWith(color: context.textMuted),
                        ),
                        onChanged: (String v) => setState(() => _query = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No matches.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySm
                              .copyWith(color: context.textDim),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext _, int i) {
                          final String option = filtered[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 2),
                              child: Text(
                                option,
                                style: AppTextStyles.body
                                    .copyWith(color: context.text),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amenities multi-select — the driver must pick at least one.
class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.state, required this.controller});

  final AddVehicleState state;
  final AddVehicleController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'AMENITIES',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(width: 8),
            Text(
              'Pick at least one',
              style: AppTextStyles.captionSm.copyWith(color: context.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (state.amenitiesLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.accent,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.amenityCatalog.map((AmenityOption a) {
              final bool selected = state.selectedAmenities.contains(a.code);
              return GestureDetector(
                onTap: () => controller.toggleAmenity(a.code),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? context.accent.withValues(alpha: 0.14)
                        : context.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: selected ? context.accent : context.borderStrong,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        amenityIcon(a.code),
                        size: 15,
                        color: selected ? context.accent : context.textDim,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        a.label,
                        style: AppTextStyles.captionSm.copyWith(
                          color: selected ? context.accent : context.text,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _UploadCard extends ConsumerWidget {
  const _UploadCard({required this.label, required this.kind});

  final String label;
  final DocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DocumentSlotState slot = ref.watch(
      addVehicleControllerProvider.select(
        (AddVehicleState s) => s.slot(kind),
      ),
    );
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
      onTap: busy ? null : () => _openSourceSheet(context, c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (uploaded ? context.accent : context.textDim)
                    .withValues(alpha: 0.14),
                borderRadius: AppRadius.sm,
              ),
              alignment: Alignment.center,
              child: Icon(
                uploaded
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                size: 16,
                color: uploaded ? context.accent : context.textDim,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    busy
                        ? 'Uploading…'
                        : uploaded
                            ? (slot.fileName ?? 'Uploaded')
                            : 'Tap to upload · PDF or photo',
                    style: AppTextStyles.captionSm.copyWith(
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
                      style: AppTextStyles.captionSm
                          .copyWith(fontSize: 11, color: context.red),
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
                child:
                    Icon(DrivioIcons.close, size: 18, color: context.textDim),
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
                  'Add file',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: ctx.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SheetOption(
                  icon: DrivioIcons.camera,
                  label: 'Take a photo',
                  onTap: () => Navigator.of(ctx).pop(DocPickerSource.camera),
                ),
                _SheetOption(
                  icon: DrivioIcons.image,
                  label: 'Choose from gallery',
                  onTap: () => Navigator.of(ctx).pop(DocPickerSource.gallery),
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
