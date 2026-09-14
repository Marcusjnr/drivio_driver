import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/data/document_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/driver_amenities_repository.dart';
import 'package:drivio_driver/modules/commons/data/vehicle_catalog_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/vehicle_options.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_draft_repository.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository_impl.dart';

const int _maxFileBytes = 5 * 1024 * 1024; // 5 MB

/// The four required vehicle photos, in display order.
const List<DocumentKind> kVehiclePhotoKinds = <DocumentKind>[
  DocumentKind.vehiclePhotoFront,
  DocumentKind.vehiclePhotoBack,
  DocumentKind.vehiclePhotoSide,
  DocumentKind.vehiclePhotoInterior,
];

enum DocPickerSource { camera, gallery, file }

class DocumentSlotState {
  const DocumentSlotState({
    this.isUploading = false,
    this.filePath,
    this.fileName,
    this.error,
  });

  final bool isUploading;
  final String? filePath;
  final String? fileName;
  final String? error;

  bool get isUploaded => filePath != null;

  DocumentSlotState copyWith({
    bool? isUploading,
    String? filePath,
    String? fileName,
    String? error,
    bool clearError = false,
    bool clearFile = false,
  }) {
    return DocumentSlotState(
      isUploading: isUploading ?? this.isUploading,
      filePath: clearFile ? null : (filePath ?? this.filePath),
      fileName: clearFile ? null : (fileName ?? this.fileName),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddVehicleState {
  const AddVehicleState({
    this.step = 1,
    this.hydrating = true,
    this.make = '',
    this.model = '',
    this.year = '',
    this.colour = '',
    this.plate = '',
    this.vin = '',
    this.transmission,
    this.fuelType,
    this.mileage = '',
    this.amenityCatalog = const <AmenityOption>[],
    this.selectedAmenities = const <String>{},
    this.amenitiesLoading = true,
    this.vehicleCatalog = const <VehicleCatalogEntry>[],
    this.documents = const <DocumentKind, DocumentSlotState>{},
    this.isLoading = false,
    this.error,
  });

  /// Which of the three steps is showing (1 = details, 2 = amenities,
  /// 3 = documents).
  final int step;

  /// True while the saved draft is being loaded on open; the page shows
  /// a spinner instead of flashing step 1 before jumping.
  final bool hydrating;

  final String make;
  final String model;
  final String year;
  final String colour;
  final String plate;
  final String vin;

  /// Wire values ('auto'|'manual'), ('diesel'|'electric'|'fuel'|'fuel_cng').
  final String? transmission;
  final String? fuelType;

  /// Current mileage (KM) as raw input.
  final String mileage;

  final List<AmenityOption> amenityCatalog;
  final Set<String> selectedAmenities;
  final bool amenitiesLoading;

  /// Server-driven make/model catalog (`get_vehicle_catalog`), curated
  /// from the admin dashboard so new cars land without an app release.
  /// Empty while loading or when the fetch failed — the getters below
  /// fall back to the bundled static list so onboarding never blocks.
  final List<VehicleCatalogEntry> vehicleCatalog;

  /// Make names for the picker, with "Other" always appended (it's a UI
  /// affordance for free-text entry, never a catalog row).
  List<String> get makeNames {
    if (vehicleCatalog.isEmpty) return kVehicleMakeNames;
    return <String>[
      ...vehicleCatalog.map((VehicleCatalogEntry e) => e.make),
      'Other',
    ];
  }

  /// Models for [forMake]; empty for "Other" / unknown makes, which the
  /// page renders as a free-text model field.
  List<String> modelsFor(String forMake) {
    if (vehicleCatalog.isEmpty) return modelsForMake(forMake);
    for (final VehicleCatalogEntry e in vehicleCatalog) {
      if (e.make == forMake) return e.models;
    }
    return const <String>[];
  }

  final Map<DocumentKind, DocumentSlotState> documents;
  final bool isLoading;
  final String? error;

  DocumentSlotState slot(DocumentKind kind) =>
      documents[kind] ?? const DocumentSlotState();

  bool get hasValidYear {
    final int? parsed = int.tryParse(year.trim());
    if (parsed == null) return false;
    final int current = DateTime.now().year;
    return parsed >= 2004 && parsed <= current;
  }

  bool get hasValidPlate {
    final String stripped =
        plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return stripped.length >= 6 && stripped.length <= 10;
  }

  bool get hasValidVin {
    // Accept the standard 17-char VIN but stay lenient for older imports —
    // require a plausible alphanumeric string.
    final String stripped = vin.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return stripped.length >= 6 && stripped.length <= 17;
  }

  int? get mileageValue {
    final int? parsed = int.tryParse(mileage.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  bool _hasUploaded(DocumentKind kind) => slot(kind).isUploaded;

  bool get hasVehicleReg => _hasUploaded(DocumentKind.vehicleReg);

  bool get hasAllPhotos => kVehiclePhotoKinds.every(_hasUploaded);

  bool get hasRequiredDocuments => hasVehicleReg && hasAllPhotos;

  /// Step 1 is complete when every vehicle detail is valid.
  bool get detailsValid =>
      make.trim().length >= 2 &&
      model.trim().length >= 2 &&
      hasValidYear &&
      colour.trim().isNotEmpty &&
      hasValidPlate &&
      hasValidVin &&
      transmission != null &&
      fuelType != null &&
      mileageValue != null;

  /// Amenities are optional (the driver may Skip), so the final submit
  /// needs valid details and all documents only.
  bool get canSubmit => detailsValid && hasRequiredDocuments;

  AddVehicleState copyWith({
    int? step,
    bool? hydrating,
    String? make,
    String? model,
    String? year,
    String? colour,
    String? plate,
    String? vin,
    String? transmission,
    String? fuelType,
    String? mileage,
    List<AmenityOption>? amenityCatalog,
    Set<String>? selectedAmenities,
    bool? amenitiesLoading,
    List<VehicleCatalogEntry>? vehicleCatalog,
    Map<DocumentKind, DocumentSlotState>? documents,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AddVehicleState(
      step: step ?? this.step,
      hydrating: hydrating ?? this.hydrating,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      colour: colour ?? this.colour,
      plate: plate ?? this.plate,
      vin: vin ?? this.vin,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      mileage: mileage ?? this.mileage,
      amenityCatalog: amenityCatalog ?? this.amenityCatalog,
      selectedAmenities: selectedAmenities ?? this.selectedAmenities,
      amenitiesLoading: amenitiesLoading ?? this.amenitiesLoading,
      vehicleCatalog: vehicleCatalog ?? this.vehicleCatalog,
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddVehicleController extends StateNotifier<AddVehicleState> {
  AddVehicleController(
    this._vehicles,
    this._documents,
    this._amenities,
    this._drafts,
    this._catalog,
  ) : super(const AddVehicleState()) {
    _loadAmenities();
    _loadCatalog();
    _hydrate();
  }

  final VehicleRepository _vehicles;
  final DocumentRepository _documents;
  final DriverAmenitiesRepository _amenities;
  final VehicleDraftRepository _drafts;
  final VehicleCatalogRepository _catalog;
  final ImagePicker _imagePicker = ImagePicker();

  /// Server catalog, fail-open: any error leaves `vehicleCatalog` empty
  /// and the state getters serve the bundled static list instead, so a
  /// driver with a flaky connection can always finish onboarding. A
  /// successful fetch with zero rows (catalog wiped by mistake) is
  /// treated the same way.
  Future<void> _loadCatalog() async {
    try {
      final List<VehicleCatalogEntry> rows = await _catalog.getCatalog();
      if (!mounted || rows.isEmpty) return;
      state = state.copyWith(vehicleCatalog: rows);
    } catch (_) {
      // Bundled fallback covers it.
    }
  }

  /// Restores saved progress so a driver who left mid-flow resumes at
  /// the step AFTER the last one they completed, with everything they
  /// entered (including already-uploaded files) intact. Fail-soft: a
  /// load error simply starts at step 1.
  Future<void> _hydrate() async {
    try {
      final VehicleDraft? draft = await _drafts.load();
      if (!mounted) return;
      if (draft == null) {
        state = state.copyWith(hydrating: false);
        return;
      }
      final Map<String, dynamic> d = draft.details ?? <String, dynamic>{};
      final Map<DocumentKind, DocumentSlotState> docs =
          <DocumentKind, DocumentSlotState>{};
      for (final MapEntry<String, dynamic> e in draft.documents.entries) {
        final DocumentKind? kind = DocumentKind.values
            .where((DocumentKind k) => k.name == e.key)
            .firstOrNull;
        final Object? v = e.value;
        if (kind == null || v is! Map) continue;
        docs[kind] = DocumentSlotState(
          filePath: v['path'] as String?,
          fileName: v['name'] as String?,
        );
      }
      state = state.copyWith(
        hydrating: false,
        step: (draft.stepCompleted + 1).clamp(1, 3),
        make: (d['make'] as String?) ?? '',
        model: (d['model'] as String?) ?? '',
        year: (d['year'] as String?) ?? '',
        colour: (d['colour'] as String?) ?? '',
        plate: (d['plate'] as String?) ?? '',
        vin: (d['vin'] as String?) ?? '',
        transmission: d['transmission'] as String?,
        fuelType: d['fuel_type'] as String?,
        mileage: (d['mileage'] as String?) ?? '',
        selectedAmenities: draft.amenities.toSet(),
        documents: docs,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(hydrating: false);
    }
  }

  /// Step 1 CTA: persist the details and advance. Returns false when the
  /// save failed (the page stays put and shows the error).
  Future<bool> completeDetails() async {
    if (!state.detailsValid) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _drafts.saveDetails(<String, dynamic>{
        'make': state.make.trim(),
        'model': state.model.trim(),
        'year': state.year.trim(),
        'colour': state.colour.trim(),
        'plate': state.plate.trim(),
        'vin': state.vin.trim(),
        'transmission': state.transmission,
        'fuel_type': state.fuelType,
        'mileage': state.mileage.trim(),
      });
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, step: 2);
      return true;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't save. Check your connection and try again.",
      );
      return false;
    }
  }

  /// Step 2 CTA (Continue with a selection, or Skip with none): persist
  /// the choice and advance.
  Future<bool> completeAmenities() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _drafts.saveAmenities(state.selectedAmenities.toList());
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, step: 3);
      return true;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't save. Check your connection and try again.",
      );
      return false;
    }
  }

  /// Back within the flow: previous step, no draft change. Returns false
  /// on step 1 so the page pops instead.
  bool goBackStep() {
    if (state.step <= 1) return false;
    state = state.copyWith(step: state.step - 1, clearError: true);
    return true;
  }

  /// Mirrors the uploaded slots into the draft so files survive an app
  /// kill mid-step-3. Best effort: the file itself is already safe in
  /// storage.
  Future<void> _persistDocumentSlots() async {
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final MapEntry<DocumentKind, DocumentSlotState> e
        in state.documents.entries) {
      if (e.value.filePath == null) continue;
      out[e.key.name] = <String, dynamic>{
        'path': e.value.filePath,
        'name': e.value.fileName,
      };
    }
    try {
      await _drafts.saveDocuments(out);
    } catch (_) {
      // Re-upload on next visit is the worst case.
    }
  }

  Future<void> _loadAmenities() async {
    try {
      final List<AmenityOption> catalog = await _amenities.catalog();
      if (!mounted) return;
      state = state.copyWith(amenityCatalog: catalog, amenitiesLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(amenitiesLoading: false);
    }
  }

  void onMakeChanged(String v) {
    // Changing the make invalidates the previously chosen model.
    state = state.copyWith(make: v, model: '', clearError: true);
  }

  void onModelChanged(String v) =>
      state = state.copyWith(model: v, clearError: true);
  void onYearChanged(String v) =>
      state = state.copyWith(year: v, clearError: true);
  void onColourChanged(String v) =>
      state = state.copyWith(colour: v, clearError: true);
  void onPlateChanged(String v) =>
      state = state.copyWith(plate: v, clearError: true);
  void onVinChanged(String v) =>
      state = state.copyWith(vin: v, clearError: true);
  void onTransmissionChanged(String v) =>
      state = state.copyWith(transmission: v, clearError: true);
  void onFuelTypeChanged(String v) =>
      state = state.copyWith(fuelType: v, clearError: true);
  void onMileageChanged(String v) =>
      state = state.copyWith(mileage: v, clearError: true);

  void toggleAmenity(String code) {
    final Set<String> next = Set<String>.from(state.selectedAmenities);
    if (next.contains(code)) {
      next.remove(code);
    } else {
      next.add(code);
    }
    state = state.copyWith(selectedAmenities: next, clearError: true);
  }

  void _setSlot(DocumentKind kind, DocumentSlotState slot) {
    final Map<DocumentKind, DocumentSlotState> next =
        Map<DocumentKind, DocumentSlotState>.from(state.documents);
    next[kind] = slot;
    state = state.copyWith(documents: next);
  }

  Future<void> pickAndUploadDocument(
    DocumentKind kind,
    DocPickerSource source,
  ) async {
    _setSlot(
      kind,
      state.slot(kind).copyWith(isUploading: true, clearError: true),
    );

    try {
      final _PickedFile? picked = await _pick(source);
      if (picked == null) {
        _setSlot(kind, state.slot(kind).copyWith(isUploading: false));
        return;
      }

      if (picked.bytes.length > _maxFileBytes) {
        _setSlot(
          kind,
          state.slot(kind).copyWith(
                isUploading: false,
                error: 'File is over 5 MB. Pick a smaller one.',
              ),
        );
        return;
      }

      final String filePath = await _documents.uploadFile(
        kind: kind,
        bytes: picked.bytes,
        fileExtension: picked.extension,
        contentType: picked.contentType,
      );

      _setSlot(
        kind,
        DocumentSlotState(filePath: filePath, fileName: picked.fileName),
      );
      await _persistDocumentSlots();
    } on DocumentAuthException {
      _setSlot(
        kind,
        state.slot(kind).copyWith(
              isUploading: false,
              error: 'Session expired. Please sign in again.',
            ),
      );
    } on StorageException catch (e) {
      _setSlot(
        kind,
        state.slot(kind).copyWith(
              isUploading: false,
              error: 'Upload failed: ${e.message}',
            ),
      );
    } catch (_) {
      _setSlot(
        kind,
        state.slot(kind).copyWith(
              isUploading: false,
              error: 'Upload failed. Please try again.',
            ),
      );
    }
  }

  void clearSlot(DocumentKind kind) {
    _setSlot(kind, const DocumentSlotState());
    _persistDocumentSlots();
  }

  Future<_PickedFile?> _pick(DocPickerSource source) async {
    switch (source) {
      case DocPickerSource.camera:
      case DocPickerSource.gallery:
        final XFile? x = await _imagePicker.pickImage(
          source: source == DocPickerSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2400,
        );
        if (x == null) return null;
        final Uint8List bytes = await x.readAsBytes();
        final String name = p.basename(x.path);
        final String ext =
            p.extension(x.path).replaceFirst('.', '').toLowerCase();
        final String contentType =
            x.mimeType ?? lookupMimeType(x.path) ?? 'image/jpeg';
        return _PickedFile(
          bytes: bytes,
          fileName: name.isEmpty ? 'photo.$ext' : name,
          extension: ext.isEmpty ? 'jpg' : ext,
          contentType: contentType,
        );
      case DocPickerSource.file:
        final FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const <String>[
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'heic',
            'webp',
          ],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final PlatformFile f = result.files.single;
        final Uint8List? bytes = f.bytes ??
            (f.path != null ? await File(f.path!).readAsBytes() : null);
        if (bytes == null) return null;
        final String ext = (f.extension ?? '').toLowerCase();
        final String contentType =
            lookupMimeType(f.name) ?? 'application/octet-stream';
        return _PickedFile(
          bytes: bytes,
          fileName: f.name,
          extension: ext.isEmpty ? 'pdf' : ext,
          contentType: contentType,
        );
    }
  }

  void endLoading() => state = state.copyWith(isLoading: false);

  Future<Vehicle?> submit() async {
    if (!state.canSubmit) return null;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final Vehicle vehicle = await _vehicles.addVehicle(
        make: state.make,
        model: state.model,
        year: int.parse(state.year.trim()),
        plate: state.plate,
        colour: state.colour,
        vin: state.vin,
        transmission: state.transmission,
        fuelType: state.fuelType,
        mileageKm: state.mileageValue,
      );

      // Persist the driver's amenity selection (per-driver set).
      try {
        await _amenities.setMyCodes(state.selectedAmenities.toList());
      } catch (_) {
        // Non-fatal — the vehicle itself saved; amenities can be edited
        // later from the profile amenities screen.
      }

      // Register each uploaded doc/photo against the new vehicle id.
      for (final MapEntry<DocumentKind, DocumentSlotState> entry
          in state.documents.entries) {
        if (entry.value.filePath == null) continue;
        await _documents.registerDocument(
          kind: entry.key,
          filePath: entry.value.filePath!,
          vehicleId: vehicle.id,
        );
      }

      locator<MixpanelService>().track(
        AnalyticsEvents.vehicleAdded,
        properties: <String, dynamic>{'vehicle_type': vehicle.category.name},
      );

      // The flow is done; next add-vehicle starts fresh.
      try {
        await _drafts.clear();
      } catch (_) {
        // A stale draft only means a pre-filled form next time.
      }

      return vehicle;
    } on VehicleAuthException {
      state = state.copyWith(
        isLoading: false,
        error: 'Session expired. Please sign in again.',
      );
      return null;
    } on PostgrestException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message.contains('duplicate')
            ? 'You already have a vehicle with that plate.'
            : 'Could not save vehicle. Please try again.',
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
      return null;
    }
  }
}

class _PickedFile {
  const _PickedFile({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String contentType;
}

final StateNotifierProvider<AddVehicleController, AddVehicleState>
    addVehicleControllerProvider =
    StateNotifierProvider<AddVehicleController, AddVehicleState>(
  (Ref _) => AddVehicleController(
    locator<VehicleRepository>(),
    locator<DocumentRepository>(),
    locator<DriverAmenitiesRepository>(),
    locator<VehicleDraftRepository>(),
    locator<VehicleCatalogRepository>(),
  ),
);
