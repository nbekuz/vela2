import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'dart:io';

import '../../core/services/api_service.dart';

class NotificationHandler {
  static Future<void> requestNotificationPermission() async {
    try {
      if (Platform.isIOS) {
        await _requestIOSNotificationPermission();
      } else {
        await _requestAndroidNotificationPermission();
      }
    } catch (e) {
      // Silent error handling
    }
  }

  static Future<void> _requestIOSNotificationPermission() async {
    try {
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        try {
          String? deviceToken = await FirebaseMessaging.instance.getToken();
          if (deviceToken != null) {
            
            await _sendDeviceTokenToAPI(deviceToken);
          } else {
            String mockToken = _generateMockDeviceToken();
            await _sendDeviceTokenToAPI(mockToken);
          }
        } catch (e) {
          String mockToken = _generateMockDeviceToken();
          await _sendDeviceTokenToAPI(mockToken);
        }
      }
    } catch (e) {
      String mockToken = _generateMockDeviceToken();
      await _sendDeviceTokenToAPI(mockToken);
    }
  }

  static Future<void> _requestAndroidNotificationPermission() async {
    try {
      PermissionStatus currentStatus = await Permission.notification.status;
      
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        await openAppSettings();
        currentStatus = await Permission.notification.status;
      } else {
        currentStatus = await Permission.notification.request();
      }

      if (currentStatus.isGranted || currentStatus.isLimited) {
        try {
          String? deviceToken = await FirebaseMessaging.instance.getToken();
          if (deviceToken != null) {
            await _sendDeviceTokenToAPI(deviceToken);
          } else {
            String mockToken = _generateMockDeviceToken();
            await _sendDeviceTokenToAPI(mockToken);
          }
        } catch (e) {
          String mockToken = _generateMockDeviceToken();
          await _sendDeviceTokenToAPI(mockToken);
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  static String _generateMockDeviceToken() {
    return 'mock_device_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> _sendDeviceTokenToAPI(String deviceToken) async {
    try {
      String platform = Platform.isIOS ? 'ios' : 'android';

      final data = {
        'device_token': deviceToken,
        'device_type': platform,
        'platform': platform,
      };
      
      // open: false - token mavjud bo'lsa yuborish kerak (register/login qilgandan keyin)
      await ApiService.request(
        url: 'auth/create-device-token/',
        method: 'POST',
        data: data,
        open: false, // Token bilan yuborish kerak
      );
    } catch (e) {
      // Silent error handling - xatolik bo'lsa ham app ishlashda davom etadi
      print('⚠️ Error sending device token: $e');
    }
  }
} 