import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import 'result_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  // Form controllers
  final TextEditingController _birthYearController = TextEditingController();
  final TextEditingController _smokingAmountController =
      TextEditingController();
  final TextEditingController _smokingYearsController = TextEditingController();
  final TextEditingController _exerciseMinutesController =
      TextEditingController();
  final TextEditingController _sleepHoursController = TextEditingController();
  final TextEditingController _drinkingFrequencyController =
      TextEditingController();
  final TextEditingController _drinkingAmountController =
      TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _outdoorStartController = TextEditingController();
  final TextEditingController _outdoorEndController = TextEditingController();

  // Radio button values
  String _gender = 'male';
  String _smoking = 'non-smoking';
  String _exerciseRegular = 'yes';
  String _sleepConsistency = 'consistent';
  String _sunscreen = 'always';

  // Slider value
  double _futureAge = 30.0;

  // Outdoor activity times
  final List<Map<String, String>> _outdoorTimes = [];

  @override
  void dispose() {
    _birthYearController.dispose();
    _smokingAmountController.dispose();
    _smokingYearsController.dispose();
    _exerciseMinutesController.dispose();
    _sleepHoursController.dispose();
    _drinkingFrequencyController.dispose();
    _drinkingAmountController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _outdoorStartController.dispose();
    _outdoorEndController.dispose();
    super.dispose();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  void _onSkip() {
    // TODO: Navigate to main app
    debugPrint('Skip tapped');
  }

  void _onSubmit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ResultScreen(),
      ),
    );
  }

  void _addOutdoorTime() {
    // 시간이 입력되지 않아도 기본값으로 추가 가능하도록
    final start = _outdoorStartController.text.isEmpty
        ? '08:30'
        : _outdoorStartController.text;
    final end = _outdoorEndController.text.isEmpty
        ? '09:00'
        : _outdoorEndController.text;

    setState(() {
      _outdoorTimes.add({
        'start': start,
        'end': end,
      });
      _outdoorStartController.clear();
      _outdoorEndController.clear();
    });
  }

  void _removeOutdoorTime(int index) {
    setState(() {
      _outdoorTimes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: Responsive.padding(context, 12),
              ),
              decoration: BoxDecoration(
                color:
                    (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                        .withOpacity(0.9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onBack,
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back,
                          size: Responsive.iconSize(context, 24),
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '생활 습관 설문',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 18),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: _onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF37EC13),
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 8),
                      ),
                    ),
                    child: Text(
                      '건너뛰기',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: Responsive.padding(context, 16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step 2 of 3',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF37EC13),
                        ),
                      ),
                      Text(
                        '상세 정보 입력',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.padding(context, 8)),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: Responsive.fontSize(context, 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37EC13),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.padding(context, 8)),
                      Expanded(
                        child: Container(
                          height: Responsive.fontSize(context, 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37EC13),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.padding(context, 8)),
                      Expanded(
                        child: Container(
                          height: Responsive.fontSize(context, 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : const Color(0xFF37EC13).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Responsive.padding(context, 24)),

                    // Title Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '정확한 분석을 위해\n생활 습관을 알려주세요',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 26),
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 8)),
                        Text(
                          '입력하신 데이터를 기반으로 현재 노화 상태와\n미래 피부 변화를 정밀하게 예측합니다.',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // Basic Info Section
                    _SectionCard(
                      title: '기본 정보',
                      icon: Icons.person,
                      isDark: isDark,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _InputField(
                                  label: '출생년도',
                                  controller: _birthYearController,
                                  placeholder: '1990',
                                  suffix: '년',
                                  isDark: isDark,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              SizedBox(width: Responsive.padding(context, 16)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: Responsive.padding(context, 4),
                                        bottom: Responsive.padding(context, 4),
                                      ),
                                      child: Text(
                                        '성별',
                                        style: TextStyle(
                                          fontSize:
                                              Responsive.fontSize(context, 10),
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    _RadioGroup(
                                      options: ['남성', '여성'],
                                      selected: _gender == 'male' ? 0 : 1,
                                      onChanged: (index) {
                                        setState(() {
                                          _gender =
                                              index == 0 ? 'male' : 'female';
                                        });
                                      },
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Smoking Section
                    _SectionCard(
                      title: '흡연 습관',
                      icon: Icons.smoking_rooms,
                      isDark: isDark,
                      child: Column(
                        children: [
                          _RadioGroup(
                            options: ['비흡연', '흡연 중'],
                            selected: _smoking == 'non-smoking' ? 0 : 1,
                            onChanged: (index) {
                              setState(() {
                                _smoking =
                                    index == 0 ? 'non-smoking' : 'smoking';
                              });
                            },
                            isDark: isDark,
                            isHorizontal: true,
                          ),
                          if (_smoking == 'smoking') ...[
                            SizedBox(height: Responsive.padding(context, 16)),
                            Container(
                              height: 1,
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[200],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '하루 흡연량',
                                    controller: _smokingAmountController,
                                    placeholder: '0',
                                    suffix: '개비',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(
                                    width: Responsive.padding(context, 16)),
                                Expanded(
                                  child: _InputField(
                                    label: '흡연 기간',
                                    controller: _smokingYearsController,
                                    placeholder: '0',
                                    suffix: '년',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Exercise Section
                    _SectionCard(
                      title: '운동 습관',
                      icon: Icons.fitness_center,
                      isDark: isDark,
                      child: Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: '하루 운동량',
                              controller: _exerciseMinutesController,
                              placeholder: '0',
                              suffix: '분',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: Responsive.padding(context, 16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 4),
                                  ),
                                  child: Text(
                                    '정기적 운동 유무',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 10),
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                _RadioGroup(
                                  options: ['예', '아니오'],
                                  selected: _exerciseRegular == 'yes' ? 0 : 1,
                                  onChanged: (index) {
                                    setState(() {
                                      _exerciseRegular =
                                          index == 0 ? 'yes' : 'no';
                                    });
                                  },
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Sleep Section
                    _SectionCard(
                      title: '수면 습관',
                      icon: Icons.bedtime,
                      isDark: isDark,
                      child: Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: '평균 수면',
                              controller: _sleepHoursController,
                              placeholder: '7',
                              suffix: '시간',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: Responsive.padding(context, 16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 4),
                                  ),
                                  child: Text(
                                    '취침시간 일관성',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 10),
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                _RadioGroup(
                                  options: ['일관적', '불규칙'],
                                  selected:
                                      _sleepConsistency == 'consistent' ? 0 : 1,
                                  onChanged: (index) {
                                    setState(() {
                                      _sleepConsistency = index == 0
                                          ? 'consistent'
                                          : 'irregular';
                                    });
                                  },
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Drinking Section
                    _SectionCard(
                      title: '음주 습관',
                      icon: Icons.wine_bar,
                      isDark: isDark,
                      child: Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: '주당 음주 횟수',
                              controller: _drinkingFrequencyController,
                              placeholder: '0',
                              suffix: '회',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              isSmall: true,
                            ),
                          ),
                          SizedBox(width: Responsive.padding(context, 16)),
                          Expanded(
                            child: _InputField(
                              label: '1회 평균 음주량',
                              controller: _drinkingAmountController,
                              placeholder: '0',
                              suffix: '잔',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              isSmall: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Outdoor Activity Section
                    _SectionCard(
                      title: '야외 활동 및 자외선',
                      icon: Icons.sunny,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Added outdoor times list
                          if (_outdoorTimes.isNotEmpty) ...[
                            ...List.generate(_outdoorTimes.length, (index) {
                              return Container(
                                margin: EdgeInsets.only(
                                    bottom: Responsive.padding(context, 8)),
                                padding: EdgeInsets.all(
                                    Responsive.padding(context, 12)),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF132210)
                                      : const Color(0xFFF6F8F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.grey[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: Responsive.fontSize(context, 32),
                                      height: Responsive.fontSize(context, 32),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1A2C16)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.schedule,
                                        size: Responsive.iconSize(context, 14),
                                        color: const Color(0xFF37EC13),
                                      ),
                                    ),
                                    SizedBox(
                                        width: Responsive.padding(context, 12)),
                                    Expanded(
                                      child: Text(
                                        '${_outdoorTimes[index]['start']} ~ ${_outdoorTimes[index]['end']}',
                                        style: TextStyle(
                                          fontSize:
                                              Responsive.fontSize(context, 14),
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _removeOutdoorTime(index),
                                      icon: Icon(
                                        Icons.close,
                                        size: Responsive.iconSize(context, 18),
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            SizedBox(height: Responsive.padding(context, 12)),
                          ],
                          // Time input fields (always visible)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: _TimeInputField(
                                        controller: _outdoorStartController,
                                        label: 'Start',
                                        isDark: isDark,
                                      ),
                                    ),
                                    SizedBox(
                                        width: Responsive.padding(context, 8)),
                                    Expanded(
                                      child: _TimeInputField(
                                        controller: _outdoorEndController,
                                        label: 'End',
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: Responsive.padding(context, 8)),
                              Material(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: _addOutdoorTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: Responsive.fontSize(context, 42),
                                    height: Responsive.fontSize(context, 42),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.add,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      size: Responsive.iconSize(context, 20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.padding(context, 8)),
                          Text(
                            '*출퇴근, 점심시간 등 야외에 있는 시간을 모두 추가해주세요.',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 10),
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: Responsive.padding(context, 16)),
                          Container(
                            height: 1,
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey[200],
                          ),
                          SizedBox(height: Responsive.padding(context, 16)),
                          Padding(
                            padding: EdgeInsets.only(
                              left: Responsive.padding(context, 4),
                              bottom: Responsive.padding(context, 8),
                            ),
                            child: Text(
                              '선크림 도포 여부',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 10),
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          _RadioGroup(
                            options: ['안바름', '가끔', '항상'],
                            selected: _sunscreen == 'never'
                                ? 0
                                : _sunscreen == 'sometimes'
                                    ? 1
                                    : 2,
                            onChanged: (index) {
                              setState(() {
                                _sunscreen = index == 0
                                    ? 'never'
                                    : index == 1
                                        ? 'sometimes'
                                        : 'always';
                              });
                            },
                            isDark: isDark,
                            isHorizontal: true,
                            isThreeOptions: true,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Body Info Section
                    _SectionCard(
                      title: '신체 정보',
                      icon: Icons.monitor_weight,
                      isDark: isDark,
                      child: Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: '체중',
                              controller: _weightController,
                              placeholder: '60',
                              suffix: 'kg',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: Responsive.padding(context, 16)),
                          Expanded(
                            child: _InputField(
                              label: '키',
                              controller: _heightController,
                              placeholder: '170',
                              suffix: 'cm',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Future Age Section
                    _SectionCard(
                      title: '목표 미래 나이',
                      icon: Icons.timelapse,
                      isDark: isDark,
                      showBadge: true,
                      badgeText: '+${_futureAge.toInt()}년 후',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 모델이 예측할 미래 시점을 선택하세요.',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 12),
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: Responsive.padding(context, 16)),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF37EC13),
                              inactiveTrackColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0xFFD3E7CF),
                              thumbColor: const Color(0xFF37EC13),
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius:
                                    Responsive.fontSize(context, 12),
                              ),
                              overlayShape: RoundSliderOverlayShape(
                                overlayRadius: Responsive.fontSize(context, 20),
                              ),
                              overlayColor:
                                  const Color(0xFF37EC13).withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _futureAge,
                              min: 10,
                              max: 50,
                              divisions: 4,
                              label: '+${_futureAge.toInt()}년',
                              onChanged: (value) {
                                setState(() {
                                  _futureAge = value;
                                });
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '+10년',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                '+20년',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                '+30년',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF37EC13),
                                ),
                              ),
                              Text(
                                '+40년',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                '+50년',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 100)),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Button
            Container(
              padding: EdgeInsets.all(horizontalPadding),
              color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: Responsive.fontSize(context, 56),
                  child: ElevatedButton(
                    onPressed: _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF37EC13),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '결과 분석하기',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 8)),
                        Icon(
                          Icons.arrow_forward,
                          size: Responsive.iconSize(context, 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section Card Widget
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isDark;
  final bool showBadge;
  final String? badgeText;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.isDark,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C16) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: Responsive.iconSize(context, 20),
                color: Colors.grey[400],
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (showBadge && badgeText != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 12),
                    vertical: Responsive.padding(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF37EC13).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: const Color(0xFF37EC13).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 10),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF37EC13),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          child,
        ],
      ),
    );
  }
}

// Input Field Widget
class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final String suffix;
  final bool isDark;
  final TextInputType keyboardType;
  final bool isSmall;

  const _InputField({
    required this.label,
    required this.controller,
    required this.placeholder,
    required this.suffix,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 4),
            bottom: Responsive.padding(context, 4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: isSmall
                  ? Responsive.fontSize(context, 10)
                  : Responsive.fontSize(context, 10),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.center,
              inputFormatters: keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              style: TextStyle(
                fontSize: isSmall
                    ? Responsive.fontSize(context, 14)
                    : Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                  borderSide: const BorderSide(
                    color: Color(0xFF37EC13),
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 16),
                  vertical: isSmall
                      ? Responsive.padding(context, 10)
                      : Responsive.padding(context, 12),
                ),
              ),
            ),
            if (suffix.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  right: Responsive.padding(context, 12),
                ),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Time Input Field Widget
class _TimeInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;

  const _TimeInputField({
    required this.controller,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label above the field
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 8),
            bottom: Responsive.padding(context, 4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 10),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        // Text field with fixed height
        SizedBox(
          height: Responsive.fontSize(context, 42),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '00:00',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF37EC13),
                  width: 1,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 12),
                vertical: Responsive.padding(context, 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Radio Group Widget
class _RadioGroup extends StatelessWidget {
  final List<String> options;
  final int selected;
  final Function(int) onChanged;
  final bool isDark;
  final bool isHorizontal;
  final bool isThreeOptions;

  const _RadioGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.isDark,
    this.isHorizontal = false,
    this.isThreeOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return Row(
        children: List.generate(options.length, (index) {
          return Expanded(
            child: _RadioOption(
              label: options[index],
              isSelected: selected == index,
              onTap: () => onChanged(index),
              isDark: isDark,
              isSmall: isThreeOptions,
            ),
          );
        }),
      );
    }

    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 4)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          return Expanded(
            child: _RadioOption(
              label: options[index],
              isSelected: selected == index,
              onTap: () => onChanged(index),
              isDark: isDark,
              isInContainer: true,
            ),
          );
        }),
      ),
    );
  }
}

// Radio Option Widget
class _RadioOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final bool isInContainer;
  final bool isSmall;

  const _RadioOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.isInContainer = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isInContainer) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: Responsive.fontSize(context, 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1A2C16) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isSmall
            ? Responsive.fontSize(context, 40)
            : Responsive.fontSize(context, 48),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF37EC13).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmall
                ? Responsive.fontSize(context, 12)
                : Responsive.fontSize(context, 14),
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
