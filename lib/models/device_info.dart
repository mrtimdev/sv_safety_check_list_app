import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfo {
  final String deviceId;
  final String deviceModel;
  final String platform;
  final String appVersion;

  DeviceInfo({
    required this.deviceId,
    required this.deviceModel,
    required this.platform,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceModel': deviceModel,
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  // Factory method to get device info
  static Future<DeviceInfo> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceId = '';
    String deviceModel = '';
    String platform = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id; // Android ID
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      platform = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
      deviceModel = '${iosInfo.name} (${iosInfo.model})';
      platform = 'iOS ${iosInfo.systemVersion}';
    }

    return DeviceInfo(
      deviceId: deviceId,
      deviceModel: deviceModel,
      platform: platform,
      appVersion: packageInfo.version,
    );
  }
}
