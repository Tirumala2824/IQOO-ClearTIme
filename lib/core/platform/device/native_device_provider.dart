import 'package:flutter/services.dart';
import '../../services/abstractions/device_provider.dart';

/// Native implementation of DeviceProvider communicating over MethodChannel with Android APIs.
class NativeDeviceProvider implements DeviceProvider {
  static const MethodChannel _channel =
      MethodChannel('com.cleartime.cleartime/device_info');

  @override
  Future<String> getDeviceId() async {
    try {
      final id = await _channel.invokeMethod<String>('getDeviceId');
      return id ?? '';
    } catch (_) {
      // No fabricated identifier: callers treat an empty id as unknown.
      return '';
    }
  }

  @override
  Future<String> getDeviceName() async {
    try {
      final name = await _channel.invokeMethod<String>('getDeviceName');
      return name ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<String> getOsVersion() async {
    try {
      final os = await _channel.invokeMethod<String>('getOsVersion');
      return os ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<String> getClientVersion() async {
    try {
      final v = await _channel.invokeMethod<String>('getClientVersion');
      return v ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final ignored =
          await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return ignored ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Returns total/available device RAM for local SLM loading.
  Future<int> getAvailableMemoryMb() async {
    try {
      final mem = await _channel.invokeMethod<int>('getAvailableMemoryMb');
      return mem ?? 3800;
    } catch (_) {
      return 3800;
    }
  }
}
