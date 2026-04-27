import 'package:flutter/services.dart';

class NativeTrackingService {
  static const MethodChannel _channel =
  MethodChannel('offline_challenge/tracking');

  Future<void> startTrackingService() async {
    await _channel.invokeMethod('startTrackingService');
  }

  Future<void> stopTrackingService() async {
    await _channel.invokeMethod('stopTrackingService');
  }
}