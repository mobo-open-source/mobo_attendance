import 'dart:developer';
import 'dart:typed_data';

import 'package:face_detection_tflite/face_detection_tflite.dart';

/// Result of comparing a live selfie against the employee's profile photo.
/// Only [match] may let a selfie check-in/out through.
enum FaceMatchOutcome {
  match,
  mismatch,
  noFaceInSelfie,
  noProfilePhoto,
  profilePhotoNoFace,
  verificationError,
}

/// On-device face verification (offline, MobileFaceNet embeddings).
class FaceMatchService {
  /// Cosine similarity at/above which two faces count as the same person.
  static const double _matchThreshold = 0.6;

  static FaceDetector? _detector;

  static Future<FaceDetector> _getDetector() async {
    return _detector ??= await FaceDetector.create(
      model: FaceDetectionModel.frontCamera,
    );
  }

  /// Compares [selfieBytes] with [profileBytes]. Fails closed: any detector
  /// error is reported as [FaceMatchOutcome.verificationError] and callers
  /// must treat it as a rejection.
  static Future<FaceMatchOutcome> verify({
    required Uint8List? profileBytes,
    required Uint8List selfieBytes,
  }) async {
    if (profileBytes == null || profileBytes.isEmpty) {
      return FaceMatchOutcome.noProfilePhoto;
    }
    try {
      final detector = await _getDetector();

      List<Face> profileFaces;
      try {
        profileFaces = await detector.detectFacesFromBytes(
          profileBytes,
          mode: FaceDetectionMode.fast,
        );
      } catch (_) {
        // Undecodable image (e.g. the default SVG avatar).
        return FaceMatchOutcome.profilePhotoNoFace;
      }
      if (profileFaces.isEmpty) return FaceMatchOutcome.profilePhotoNoFace;

      final selfieFaces = await detector.detectFacesFromBytes(
        selfieBytes,
        mode: FaceDetectionMode.fast,
      );
      if (selfieFaces.isEmpty) return FaceMatchOutcome.noFaceInSelfie;

      final profileEmbedding = await detector.getFaceEmbedding(
        profileFaces.first,
        profileBytes,
      );
      final selfieEmbedding = await detector.getFaceEmbedding(
        selfieFaces.first,
        selfieBytes,
      );

      final similarity = FaceDetector.compareFaces(
        profileEmbedding,
        selfieEmbedding,
      );
      return similarity >= _matchThreshold
          ? FaceMatchOutcome.match
          : FaceMatchOutcome.mismatch;
    } catch (e) {
      log('FaceMatchService.verify error: $e');
      return FaceMatchOutcome.verificationError;
    }
  }

  /// User-facing message for a rejected outcome (null for [match]).
  static String? messageFor(FaceMatchOutcome outcome) {
    switch (outcome) {
      case FaceMatchOutcome.match:
        return null;
      case FaceMatchOutcome.mismatch:
        return 'Face does not match your profile photo';
      case FaceMatchOutcome.noFaceInSelfie:
        return 'No face detected in the selfie. Please try again';
      case FaceMatchOutcome.noProfilePhoto:
        return 'Please set a profile photo before using selfie check-in';
      case FaceMatchOutcome.profilePhotoNoFace:
        return 'Your profile photo has no clear face. Please update it';
      case FaceMatchOutcome.verificationError:
        return 'Could not verify your face. Please try again';
    }
  }
}
