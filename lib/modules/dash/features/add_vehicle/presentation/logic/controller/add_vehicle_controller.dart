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
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
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
    this.documents = const <DocumentKind, DocumentSlotState>{},
    this.isLoading = false,
    this.error,
  });

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

  bool get canSubmit =>
      make.trim().length >= 2 &&
      model.trim().length >= 2 &&
      hasValidYear &&
      colour.trim().isNotEmpty &&
      hasValidPlate &&
      hasValidVin &&
      transmission != null &&
      fuelType != null &&
      mileageValue != null &&
      selectedAmenities.isNotEmpty &&
      hasRequiredDocuments;

  AddVehicleState copyWith({
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
    Map<DocumentKind, DocumentSlotState>? documents,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AddVehicleState(
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
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddVehicleController extends StateNotifier<AddVehicleState> {
  AddVehicleController(this._vehicles, this._documents, this._amenities)
      : super(const AddVehicleState()) {
    _loadAmenities();
  }

  final VehicleRepository _vehicles;
  final DocumentRepository _documents;
  final DriverAmenitiesRepository _amenities;
  final ImagePicker _imagePicker = ImagePicker();

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
  ),
);
