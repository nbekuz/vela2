import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'auth_store.dart';

class CheckInStore extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Actions
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Check-in action with API call
  Future<void> submitCheckIn({
    required String checkInChoice,
    required String description,
    VoidCallback? onSuccess,
    AuthStore? authStore,
  }) async {
    setLoading(true);
    setError(null);

    try {
      final response = await ApiService.request(
        url: 'auth/check-in/',
        method: 'POST',
        data: {
          'check_in_choice': checkInChoice,
          'description': description,
        },
      );

      // Check if the request was successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Check-in response: $response');
        // Refresh user data to update check-ins
        if (authStore != null) {
          await authStore.getUserDetails();
        }
        
        // Call success callback
        onSuccess?.call();
        
     
      }
    } catch (e) {
      String errorMessage = 'Check-in failed. Please try again.';

      if (e.toString().contains('400')) {
        errorMessage = 'Invalid check-in data. Please try again.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please login again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      }

      setError(errorMessage);
      developer.log('❌ Check-in error: $e');
      
      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setLoading(false);
    }
  }
} 