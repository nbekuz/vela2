import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/meditation_profile_data.dart';
import '../../../core/stores/meditation_store.dart';
import '../step_scaffold.dart';

class VisionStep extends StatefulWidget {
  final MeditationProfileData profileData;
  final Function(MeditationProfileData) onProfileDataChanged;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int currentStep;
  final int totalSteps;
  final int stepperIndex;
  final int stepperCount;

  const VisionStep({
    required this.profileData,
    required this.onProfileDataChanged,
    required this.onNext,
    this.onBack,
    required this.currentStep,
    required this.totalSteps,
    required this.stepperIndex,
    required this.stepperCount,
    super.key,
  });

  @override
  State<VisionStep> createState() => _VisionStepState();
}

class _VisionStepState extends State<VisionStep> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _textScroll = ScrollController();
  final FocusNode _textFocus = FocusNode();

  // Чтобы знать границы поля и отличать жесты внутри/снаружи
  final GlobalKey _textFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.profileData.dream != null &&
        widget.profileData.dream!.isNotEmpty) {
      _controller.text = widget.profileData.dream!.join(' ');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textScroll.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  bool _isPointInsideTextField(Offset globalPos) {
    final ctx = _textFieldKey.currentContext;
    if (ctx == null) return false;
    final rb = ctx.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) return false;
    final topLeft = rb.localToGlobal(Offset.zero);
    final rect = topLeft & rb.size;
    return rect.contains(globalPos);
  }

  void _onDreamChanged(String value) {
    // Treat the entire text as a single dream, don't split by commas
    final dreams = value.trim().isNotEmpty ? <String>[value.trim()] : <String>[];

    final updatedProfile = widget.profileData.copyWith(dream: dreams);
    widget.onProfileDataChanged(updatedProfile);
    Provider.of<MeditationStore>(
      context,
      listen: false,
    ).setMeditationProfile(updatedProfile);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityBuilder(
      controller: KeyboardVisibilityController(),
      builder: (context, isKeyboardVisible) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Скрыть клавиатуру на вертикальном свайпе ВНЕ поля (вверх/вниз)
          onVerticalDragUpdate: (details) {
            if (!_isPointInsideTextField(details.globalPosition)) {
              _dismissKeyboard();
            }
          },
          // Скрыть клавиатуру при тапе ВНЕ поля
          onTapDown: (details) {
            if (!_isPointInsideTextField(details.globalPosition)) {
              _dismissKeyboard();
            }
          },
          child: StepScaffold(
            title: '',
            onBack: widget.onBack,
            onNext: widget.onNext,
            currentStep: widget.currentStep,
            totalSteps: widget.totalSteps,
            nextEnabled: _controller.text.trim().isNotEmpty,
            stepperIndex: widget.stepperIndex,
            stepperCount: widget.stepperCount,
            showTitles: true,
            // Без onDrag-автоскрытия, чтобы не ловить драги внутри TextField
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tell me about your dream life',
                      style: TextStyle(
                        fontFamily: 'Canela',
                        fontWeight: FontWeight.w300,
                        fontSize: 32.sp,
                        letterSpacing: -0.5,
                        color: Color(0xFFF2EFEA),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 0),
                    const Text(
                      'Be sure to include Sensory Details: \n What does  it look and feel like? What are you doing? Who are you with? What do you see, hear, smell?',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                        color: Color(0xFFF2EFEA),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Поле ввода: свайпы/тапы внутри НЕ закрывают клавиатуру
                    SizedBox(
                      key: _textFieldKey, // важно: ключ на контейнер с полем
                      width: double.infinity,
                      height: isKeyboardVisible ? 120 : 160,
                      child: ScrollbarTheme(
                        data: ScrollbarThemeData(
                          thickness: const MaterialStatePropertyAll(0),
                          radius: const Radius.circular(8),
                          thumbColor: MaterialStatePropertyAll(
                            Colors.white.withOpacity(0),
                          ),
                          trackColor: const MaterialStatePropertyAll(
                            Colors.transparent,
                          ),
                          trackVisibility: const MaterialStatePropertyAll(true),
                        ),
                        child: Scrollbar(
                          controller: _textScroll,
                          thumbVisibility: true,
                          child: TextField(
                            focusNode: _textFocus,
                            controller: _controller,
                            scrollController: _textScroll,
                            textAlign: TextAlign.center,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Satoshi',
                              fontSize: 14.sp,
                              decoration: TextDecoration.none,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'I see living in a cozy house and I am waking up with energy...',
                              hintStyle: const TextStyle(
                                color: Color(0xFFFFFFFF),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF5882B6),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0x152B561A),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF152B56),
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            onChanged: _onDreamChanged,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isKeyboardVisible ? 10 : 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
