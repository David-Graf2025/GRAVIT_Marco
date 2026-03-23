import 'package:flutter/foundation.dart';

/// State class for upload operations
class UploadState {
  final int current;
  final int total;
  final String status;
  final bool isUploading;
  final String? error;

  UploadState({
    this.current = 0,
    this.total = 0,
    this.status = 'Idle',
    this.isUploading = false,
    this.error,
  });

  UploadState copyWith({
    int? current,
    int? total,
    String? status,
    bool? isUploading,
    String? error,
  }) {
    return UploadState(
      current: current ?? this.current,
      total: total ?? this.total,
      status: status ?? this.status,
      isUploading: isUploading ?? this.isUploading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing upload state
class UploadNotifier extends ChangeNotifier {
  UploadState _state = UploadState();

  UploadState get state => _state;

  void startUpload(int total) {
    _state = _state.copyWith(
      current: 0,
      total: total,
      status: 'Starting upload...',
      isUploading: true,
      error: null,
    );
    notifyListeners();
  }

  void updateProgress(int current, String status) {
    _state = _state.copyWith(
      current: current,
      status: status,
    );
    notifyListeners();
  }

  void finishUpload() {
    _state = _state.copyWith(
      status: 'Upload completed',
      isUploading: false,
    );
    notifyListeners();
  }

  void setError(String error) {
    _state = _state.copyWith(
      status: 'Error: $error',
      isUploading: false,
      error: error,
    );
    notifyListeners();
  }

  void reset() {
    _state = UploadState();
    notifyListeners();
  }
}