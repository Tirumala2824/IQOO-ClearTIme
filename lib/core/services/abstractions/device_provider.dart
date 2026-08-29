/// Abstract interface for Android device hardware and system information.
abstract class DeviceProvider {
  /// Fetches the unique hardware installation ID.
  Future<String> getDeviceId();

  /// Gets the human-readable device marketing name and model (e.g. "Pixel 8 Pro").
  Future<String> getDeviceName();

  /// Gets the Android OS version string (e.g. "Android 14").
  Future<String> getOsVersion();

  /// Gets the app client release version.
  Future<String> getClientVersion();

  /// Checks whether power optimization or battery restriction affects background processing.
  Future<bool> isBatteryOptimizationIgnored();
}
