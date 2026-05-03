import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/data/document_repository_impl.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository_impl.dart';

const int _minVehicleYear = 2008;
const int _maxFileBytes = 5 * 1024 * 1024; // 5 MB

enum DocPickerSource { camera, gallery, file }

class DocumentSlotState {
  const DocumentSlotState({
    this.isUploading = false,
    this.filePath,
    this.fileName,
    this.error,
  });

  /// True while the file is being uploaded to Storage.
  final bool isUploading;

  /// Storage path once uploaded; null otherwise.
  final String? filePath;

  /// Original file name for display in the UI.
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
    this.documents = const <DocumentKind, DocumentSlotState>{},
    this.isLoading = false,
    this.error,
  });

  final String make;
  final String model;
  final String year;
  final String colour;
  final String plate;
  final Map<DocumentKind, DocumentSlotState> documents;
  final bool isLoading;
  final String? error;

  DocumentSlotState slot(DocumentKind kind) =>
      documents[kind] ?? const DocumentSlotState();

  bool get hasValidYear {
    final int? parsed = int.tryParse(year.trim());
    if (parsed == null) return false;
    final int current = DateTime.now().year;
    return parsed >= _minVehicleYear && parsed <= current + 1;
  }

  bool get hasValidPlate {
    final String stripped =
        plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return stripped.length >= 6 && stripped.length <= 10;
  }

  bool _hasUploaded(DocumentKind kind) => slot(kind).isUploaded;

  bool get hasRequiredDocuments =>
      _hasUploaded(DocumentKind.vehicleReg) &&
      _hasUploaded(DocumentKind.insurance);

  bool get canSubmit =>
      make.trim().length >= 2 &&
      model.trim().length >= 2 &&
      hasValidYear &&
      hasValidPlate &&
      hasRequiredDocuments;

  AddVehicleState copyWith({
    String? make,
    String? model,
    String? year,
    String? colour,
    String? plate,
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
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddVehicleController extends StateNotifier<AddVehicleState> {
  AddVehicleController(this._vehicles, this._documents)
      : super(const AddVehicleState());

  final VehicleRepository _vehicles;
  final DocumentRepository _documents;
  final ImagePicker _imagePicker = ImagePicker();

  void onMakeChanged(String v) =>
      state = state.copyWith(make: v, clearError: true);
  void onModelChanged(String v) =>
      state = state.copyWith(model: v, clearError: true);
  void onYearChanged(String v) =>
      state = state.copyWith(year: v, clearError: true);
  void onColourChanged(String v) =>
      state = state.copyWith(colour: v, clearError: true);
  void onPlateChanged(String v) =>
      state = state.copyWith(plate: v, clearError: true);

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
        DocumentSlotState(
          filePath: filePath,
          fileName: picked.fileName,
        ),
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
        final String ext = p.extension(x.path).replaceFirst('.', '').toLowerCase();
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
          allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final PlatformFile f = result.files.single;
        final Uint8List? bytes =
            f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
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
      );

      // Register each uploaded doc against the new vehicle id.
      for (final MapEntry<DocumentKind, DocumentSlotState> entry
          in state.documents.entries) {
        if (entry.value.filePath == null) continue;
        await _documents.registerDocument(
          kind: entry.key,
          filePath: entry.value.filePath!,
          vehicleId: vehicle.id,
        );
      }

      state = state.copyWith(isLoading: false);
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
  ),
);
