import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../core/stores/auth_store.dart';
import '../../core/stores/meditation_store.dart';
import '../../core/services/api_service.dart';

const String BASE_ENDPOINT = "http://31.97.98.47:8000";
const int SAMPLE_RATE = 44100;
const int CHANNELS = 2;
const int BYTES_PER_SAMPLE = 2;

/// Get endpoint based on ritualType (1, 2, 3, 4)
String getEndpoint(String? ritualType) {
  final type = ritualType ?? '1';
  switch (type) {
    case '1':
      return "$BASE_ENDPOINT/sleep";
    case '2':
      return "$BASE_ENDPOINT/spark";
    case '3':
      return "$BASE_ENDPOINT/calm";
    case '4':
      return "$BASE_ENDPOINT/dream";
    default:
      return "$BASE_ENDPOINT/calm";
  }
}

/// Capitalize ritual type for API (guided -> Guided, story -> Story)
String capitalizeRitualType(String value) {
  final lower = value.toLowerCase();
  if (lower == 'guided') return 'Guided';
  if (lower == 'story') return 'Story';
  // Default: capitalize first letter
  return value.isEmpty
      ? 'Story'
      : value[0].toUpperCase() + value.substring(1).toLowerCase();
}

/// Capitalize tone for API (dreamy -> Dreamy, asmr -> ASMR)
String capitalizeTone(String value) {
  final lower = value.toLowerCase();
  if (lower == 'dreamy') return 'Dreamy';
  if (lower == 'asmr') return 'ASMR';
  // Default: capitalize first letter
  return value.isEmpty
      ? 'Dreamy'
      : value[0].toUpperCase() + value.substring(1).toLowerCase();
}

/// Capitalize voice for API (male -> Male, female -> Female)
String capitalizeVoice(String value) {
  final lower = value.toLowerCase();
  if (lower == 'male') return 'Male';
  if (lower == 'female') return 'Female';
  // Default: capitalize first letter
  return value.isEmpty
      ? 'Female'
      : value[0].toUpperCase() + value.substring(1).toLowerCase();
}

/// Build request body from user data
Future<Map<String, dynamic>> buildRequestBody(BuildContext? context) async {
  // Default values
  String name = "User";
  String goals = "";
  String dreamlife = "";
  String dreamActivities = "";
  String ritualType = "Story";
  String tone = "Dreamy";
  String voice = "Female";
  int length = 2;
  String checkIn = "string";

  // Try to get user data from stores if context is available
  if (context != null) {
    try {
      // Check if Provider is available in the widget tree
      try {
        final authStore = Provider.of<AuthStore>(context, listen: false);
        final meditationStore = Provider.of<MeditationStore>(
          context,
          listen: false,
        );

        final user = authStore.user;
        final profile = meditationStore.meditationProfile;

        // Get name
        if (user != null) {
          final firstName = user.firstName;
          final lastName = user.lastName;
          name = "$firstName $lastName".trim();
          if (name.isEmpty && user.email.isNotEmpty) {
            name = user.email.split('@').first;
          }
        }

        // Get goals
        if (user != null && user.goals != null && user.goals!.isNotEmpty) {
          goals = user.goals!;
        } else if (profile != null &&
            profile.goals != null &&
            profile.goals!.isNotEmpty) {
          goals = profile.goals!.join(", ");
        }

        // Get dreamlife
        if (user != null && user.dream != null && user.dream!.isNotEmpty) {
          dreamlife = user.dream!;
        } else if (profile != null &&
            profile.dream != null &&
            profile.dream!.isNotEmpty) {
          dreamlife = profile.dream!.join(", ");
        }

        // Get dream activities (happiness stepdagi ma'lumot)
        if (user != null && user.happiness != null && user.happiness!.isNotEmpty) {
          dreamActivities = user.happiness!;
        } else if (profile != null &&
            profile.happiness != null &&
            profile.happiness!.isNotEmpty) {
          dreamActivities = profile.happiness!.join(", ");
        }

        // Ritual type har doim "Story" bo'lishi kerak
        ritualType = "Story";

        if (meditationStore.storedTone != null &&
            meditationStore.storedTone!.isNotEmpty) {
          tone = capitalizeTone(meditationStore.storedTone!);
        } else if (profile?.tone != null && profile!.tone!.isNotEmpty) {
          tone = capitalizeTone(profile.tone!.first);
        }

        if (meditationStore.storedVoice != null &&
            meditationStore.storedVoice!.isNotEmpty) {
          voice = capitalizeVoice(meditationStore.storedVoice!);
        } else if (profile?.voice != null && profile!.voice!.isNotEmpty) {
          voice = capitalizeVoice(profile.voice!.first);
        }

        // Get duration/length
        if (meditationStore.storedDuration != null &&
            meditationStore.storedDuration!.isNotEmpty) {
          final durationStr = meditationStore.storedDuration!;
          length = int.tryParse(durationStr) ?? 2;
        } else if (profile?.duration != null && profile!.duration!.isNotEmpty) {
          final durationStr = profile.duration!.first;
          length = int.tryParse(durationStr) ?? 2;
        }

        // Get check_in - API dan auth/check-in/ endpoint orqali birinchi elementning description ni olish
        try {
          final checkInResponse = await ApiService.request(
            url: 'auth/check-in/',
            method: 'GET',
            open: false, // Token required
          );
          
          // Response array bo'lishi kerak - array?.[0] sintaksisini ishlatish
          final checkInList = checkInResponse.data;
          if (checkInList is List && checkInList.isNotEmpty) {
            final firstCheckIn = checkInList[0];
            
            // description ni olish
            if (firstCheckIn is Map<String, dynamic>) {
              final description = firstCheckIn['description']?.toString();
              if (description != null && description.isNotEmpty && description != 'string') {
                checkIn = description;
                print('✅ [buildRequestBody] Check-in description from API: $checkIn');
              }
            }
          }
        } catch (e) {
          print('⚠️ [buildRequestBody] Error fetching check-in from API: $e');
          // Fallback: user.checkIns dan olish
          if (user != null && user.checkIns.isNotEmpty) {
            final lastCheckIn = user.checkIns.last;
            // Avval description ni tekshirish, bo'sh bo'lsa checkInChoice ni olish
            checkIn = lastCheckIn.description.isNotEmpty
                ? lastCheckIn.description
                : lastCheckIn.checkInChoice.isNotEmpty
                    ? lastCheckIn.checkInChoice
                    : "string";
            print('✅ [buildRequestBody] Using check-in from user.checkIns: $checkIn');
          }
        }
        
      } catch (providerError) {
        print('⚠️ Provider error (stores not available): $providerError');
     
      }
    } catch (e) {
      print('⚠️ Using default values');
    }
  } else {
    print('⚠️ Context is null, using default values');
  }

  return {
    "ritual_type": ritualType,
    "name": name,
    "goals": goals.isNotEmpty ? goals : "Inner peace and personal growth",
    "dreamlife": dreamlife.isNotEmpty
        ? dreamlife
        : "A peaceful and fulfilling life",
    "dream_activities": dreamActivities.isNotEmpty
        ? dreamActivities
        : dreamlife.isNotEmpty
        ? dreamlife
        : "A peaceful and fulfilling life",
    "tone": tone,
    "voice": voice,
    "length": length,
    "check_in": checkIn,
  };
}

/// Создать WAV-байты из сырых PCM (Int16 LE)
Uint8List createWavBytes(
  List<Uint8List> pcmChunks,
  int sampleRate,
  int channels,
) {
  final bytesPerSample = BYTES_PER_SAMPLE;
  final dataLength = pcmChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
  const headerSize = 44;
  final totalDataSize = headerSize + dataLength;
  final header = ByteData(headerSize);

  void writeString(int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  // RIFF header
  writeString(0, "RIFF");
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeString(8, "WAVE");

  // fmt chunk
  writeString(12, "fmt ");
  header.setUint32(16, 16, Endian.little); // размер fmt
  header.setUint16(20, 1, Endian.little); // формат = 1 (PCM)
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  final byteRate = sampleRate * channels * bytesPerSample;
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, channels * bytesPerSample, Endian.little); // block align
  header.setUint16(34, 8 * bytesPerSample, Endian.little); // bits per sample

  // data chunk
  writeString(36, "data");
  header.setUint32(40, dataLength, Endian.little);

  final builder = BytesBuilder();
  builder.add(header.buffer.asUint8List());
  for (final chunk in pcmChunks) {
    builder.add(chunk);
  }

  final fullBytes = builder.toBytes();
  assert(fullBytes.length == totalDataSize);
  return fullBytes;
}

/// Extract amplitude samples from PCM data for visualization
List<double> extractAmplitudes(List<Uint8List> pcmChunks, int maxSamples) {
  if (pcmChunks.isEmpty) return [];

  // Combine all chunks
  final totalBytes = pcmChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
  if (totalBytes < BYTES_PER_SAMPLE * CHANNELS) return [];

  final allBytes = Uint8List(totalBytes);
  int offset = 0;
  for (final chunk in pcmChunks) {
    allBytes.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }

  // Extract samples (Int16 LE, stereo)
  final samples = <double>[];
  final bytesPerFrame = BYTES_PER_SAMPLE * CHANNELS;
  final step = math.max(1, (totalBytes ~/ bytesPerFrame) ~/ maxSamples);

  for (int i = 0; i < totalBytes - bytesPerFrame; i += bytesPerFrame * step) {
    // Read left channel (first sample)
    final sampleValue = allBytes.buffer.asByteData().getInt16(i, Endian.little);
    // Normalize to 0-1 range
    final amplitude = (sampleValue.abs() / 32768.0).clamp(0.0, 1.0);
    samples.add(amplitude);

    if (samples.length >= maxSamples) break;
  }

  return samples;
}

/// Create meditation with WAV file upload
/// Bu funksiya streaming tugagach WAV faylni /meditation/create-with-file/ API ga yuboradi
Future<Map<String, dynamic>?> createMeditationWithFile({
  required BuildContext context,
  required Uint8List wavBytes,
}) async {
  try {
    // Ma'lumotlarni olish
    final requestBody = await buildRequestBody(context);
    
    // Plan type ni olish
    final meditationStore = Provider.of<MeditationStore>(context, listen: false);
    final planType = meditationStore.storedPlanType ?? 1;
    
    // API ga yuborish uchun data tayyorlash
    // API kichik harflarni kutmoqda, shuning uchun toLowerCase() qilamiz
    final ritualTypeValue = (requestBody['ritual_type'] ?? 'Story').toString().toLowerCase();
    final toneValue = (requestBody['tone'] ?? 'Dreamy').toString().toLowerCase();
    final voiceValue = (requestBody['voice'] ?? 'Female').toString().toLowerCase();
    
    print('🔄 [createMeditationWithFile] API formatga o\'girilgan qiymatlar:');
    print('   - ritual_type: "${requestBody['ritual_type']}" -> "$ritualTypeValue"');
    print('   - tone: "${requestBody['tone']}" -> "$toneValue"');
    print('   - voice: "${requestBody['voice']}" -> "$voiceValue"');
    print('   - plan_type: $planType (type: ${planType.runtimeType})');
    
    final data = <String, dynamic>{
      'plan_type': planType,
      'ritual_type': ritualTypeValue,
      'tone': toneValue,
      'voice': voiceValue,
      'duration': requestBody['length']?.toString() ?? '2',
    };
    
    // Qo'shimcha ma'lumotlarni qo'shish
    if (requestBody['name'] != null && requestBody['name'].toString().isNotEmpty) {
      data['name'] = requestBody['name'];
    }
    if (requestBody['goals'] != null && requestBody['goals'].toString().isNotEmpty) {
      data['goals'] = requestBody['goals'];
    }
    if (requestBody['dreamlife'] != null && requestBody['dreamlife'].toString().isNotEmpty) {
      data['dreamlife'] = requestBody['dreamlife'];
    }
    if (requestBody['dream_activities'] != null && requestBody['dream_activities'].toString().isNotEmpty) {
      data['dream_activities'] = requestBody['dream_activities'];
    }
    if (requestBody['check_in'] != null && requestBody['check_in'].toString().isNotEmpty && requestBody['check_in'] != 'string') {
      data['check_in'] = requestBody['check_in'];
    }
    
    // WAV faylni form data sifatida qo'shish
    // ApiService.uploadFile avtomatik ravishda Uint8List ni MultipartFile ga aylantiradi
    data['file_wav'] = wavBytes;
    
    // Debug: Request data ni print qilish
    print('🔄 [createMeditationWithFile] Request data keys: ${data.keys.toList()}');
    print('🔄 [createMeditationWithFile] WAV file size: ${wavBytes.length} bytes');
    print('🔄 [createMeditationWithFile] Data fields:');
    data.forEach((key, value) {
      if (key != 'file_wav') {
        print('   - $key: $value');
      } else {
        print('   - $key: Uint8List(${wavBytes.length} bytes)');
      }
    });
    
    // API ga form data (multipart/form-data) sifatida yuborish
    // file_wav parametri MultipartFile sifatida yuboriladi
    print('🔄 [createMeditationWithFile] API ga request yuborilmoqda...');
    print('🔄 [createMeditationWithFile] URL: auth/meditation/create-with-file/');
    
    final response = await ApiService.uploadFile(
      url: 'auth/meditation/create-with-file/',
      method: 'POST',
      data: data,
    );
    
    print('✅ [createMeditationWithFile] API dan javob keldi: ${response.statusCode}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      // Account update allaqachon parallel yuborilgan, shuning uchun bu yerda qayta yubormaymiz
      print('✅ [createMeditationWithFile] Meditation muvaffaqiyatli yaratildi');
      return response.data as Map<String, dynamic>?;
    } else {
      print('❌ Error creating meditation: ${response.statusCode}');
      print('❌ Response data: ${response.data}');
      return null;
    }
  } catch (e) {
    print('❌ Error creating meditation with file: $e');
    
    // DioException bo'lsa, batafsil ma'lumotlarni print qilish
    if (e is DioException) {
      print('❌ DioException details:');
      print('   - Type: ${e.type}');
      print('   - Message: ${e.message}');
      print('   - Request path: ${e.requestOptions.path}');
      print('   - Request method: ${e.requestOptions.method}');
      print('   - Request data: ${e.requestOptions.data}');
      print('   - Request headers: ${e.requestOptions.headers}');
      
      if (e.response != null) {
        print('   - Response status code: ${e.response?.statusCode}');
        print('   - Response data: ${e.response?.data}');
        
        // Response data ni batafsil print qilish
        if (e.response?.data is Map) {
          final responseData = e.response!.data as Map;
          print('   - API Validation Errors:');
          responseData.forEach((key, value) {
            if (value is List) {
              print('     • $key: ${value.join(", ")}');
            } else {
              print('     • $key: $value');
            }
          });
        }
        
        print('   - Response headers: ${e.response?.headers}');
      } else {
        print('   - No response received');
      }
    }
    
    return null;
  }
}

/// Yangi registratsiya qilgan foydalanuvchining accountini update qilish
/// Bu faqat registratsiya vaqtida ishlaydi
Future<void> _updateNewUserAccount(
  BuildContext context,
  Map<String, dynamic> requestBody,
) async {
  try {
    // Yangi user ekanligini tekshirish
    final prefs = await SharedPreferences.getInstance();
    final isNewUser = prefs.getBool('first') ?? false;
    
    if (!isNewUser) {
      // Eski user, update qilish shart emas
      return;
    }
    
    print('🔄 Updating account for new user...');
    
    final authStore = Provider.of<AuthStore>(context, listen: false);
    final user = authStore.user;
    
    // Name ni update qilish (agar mavjud bo'lsa)
    final name = requestBody['name']?.toString() ?? '';
    if (name.isNotEmpty) {
      final nameParts = name.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 
          ? nameParts.sublist(1).join(' ') 
          : '';
      
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        try {
          await authStore.updateProfile(
            firstName: firstName.isNotEmpty ? firstName : (user?.firstName ?? ''),
            lastName: lastName.isNotEmpty ? lastName : (user?.lastName ?? ''),
            onSuccess: () {
              print('✅ User name updated successfully');
            },
          );
        } catch (e) {
          print('⚠️ Error updating user name: $e');
        }
      }
    }
    
    // Goals va dream ni update qilish
    final goals = requestBody['goals']?.toString() ?? '';
    final dreamlife = requestBody['dreamlife']?.toString() ?? '';
    // 🔴 CRITICAL: happiness ni requestBody'dan olish (dream_activities - bu happiness ma'lumoti)
    final happiness = requestBody['dream_activities']?.toString() ?? '';
    
    if (goals.isNotEmpty || dreamlife.isNotEmpty || happiness.isNotEmpty) {
      try {
        // Mavjud user ma'lumotlarini olish
        final existingGender = user?.gender ?? 'male';
        final existingAgeRange = user?.ageRange ?? '25-34';
        // happiness ni requestBody'dan olish, agar bo'sh bo'lsa user.happiness dan olish
        final existingHappiness = happiness.isNotEmpty ? happiness : (user?.happiness ?? '');
        
        // 🔴 CRITICAL: Generatsiya vaqtida faqat POST ishlatiladi (forcePost: true)
        await authStore.updateUserDetail(
          gender: existingGender,
          ageRange: existingAgeRange,
          dream: dreamlife.isNotEmpty ? dreamlife : (user?.dream ?? ''),
          goals: goals.isNotEmpty ? goals : (user?.goals ?? ''),
          happiness: existingHappiness,
          forcePost: true, // Generatsiya vaqtida faqat POST ishlatish
          onSuccess: () {
            print('✅ User details updated successfully');
          },
        );
      } catch (e) {
        print('⚠️ Error updating user details: $e');
      }
    }
    
    // Update qilgandan keyin 'first' flag ni false qilib qo'yish
    await prefs.setBool('first', false);
    print('✅ Account update completed for new user');
    
  } catch (e) {
    print('❌ Error updating new user account: $e');
    // Xatolik bo'lsa ham davom etish kerak
  }
}
