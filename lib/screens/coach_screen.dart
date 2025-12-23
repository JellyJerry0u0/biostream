import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<bool> _checkedItems = [false, false, false];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  void _onMore() {
    // TODO: Show more options
    debugPrint('More tapped');
  }

  void _onSend() {
    if (_messageController.text.isNotEmpty) {
      // TODO: Send message
      debugPrint('Send: ${_messageController.text}');
      _messageController.clear();
    }
  }

  void _toggleCheckbox(int index) {
    setState(() {
      _checkedItems[index] = !_checkedItems[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 16);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.only(
                top: Responsive.padding(context, 48),
                bottom: Responsive.padding(context, 16),
                left: horizontalPadding,
                right: horizontalPadding,
              ),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                    .withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[200]!,
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
                  Column(
                    children: [
                      Text(
                        'AI Skin Coach',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 18),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: Responsive.padding(context, 4)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: Responsive.fontSize(context, 8),
                            height: Responsive.fontSize(context, 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF37EC13),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF37EC13).withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: Responsive.padding(context, 6)),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 10),
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onMore,
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.more_vert,
                          size: Responsive.iconSize(context, 24),
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chat Area
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: Responsive.padding(context, 24)),

                    // Timestamp
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 12),
                        vertical: Responsive.padding(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C2E18) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'Today, 9:41 AM',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // AI Message 1: Intro + Stats
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: Responsive.fontSize(context, 40),
                          height: Responsive.fontSize(context, 40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                              ),
                            ],
                            image: const DecorationImage(
                              image: NetworkImage(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuC8XJ1hAqdR2cDVqkoGLyVGNjLL7Y-HFuM10uLm4BS3_xz6NZ1BuKtk0iE9J1LIPvtgdu3tLnJL0htnqujK_7t23vXpeH-amYsqoAX0XBI50e4QRGIzfRxPwI1vuPjSBemfPD5Yu896cul15wo0i_SlKSHeQmBc3HpjxITJ7vACwgEQDqXZPU9FqXZV0-OCFnaR0GEPkcSZnHJd2rL8JEU6b0mKq5cQujjMwjiHoo5HdFd8Gzr1WNF91eKe05b6T4zdjPp8ZQvpO_g',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Skin Coach AI',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 8)),
                              // Text Bubble
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[100]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Hello! 👋 Based on your recent analysis, your aging speed is slightly accelerated due to sleep deprivation. Here are your key stats.',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 14),
                                    height: 1.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 12)),
                              // Stats Widget
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 20)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[100]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Opacity(
                                        opacity: 0.1,
                                        child: Icon(
                                          Icons.ssid_chart,
                                          size: Responsive.iconSize(context, 48),
                                          color: const Color(0xFF37EC13),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AGING ACCELERATION',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, 10),
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: Responsive.padding(context, 8)),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '+1.5 Years',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 28),
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            SizedBox(width: Responsive.padding(context, 8)),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: Responsive.padding(context, 8),
                                                vertical: Responsive.padding(context, 2),
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(9999),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.trending_up,
                                                    size: Responsive.iconSize(context, 14),
                                                    color: Colors.red[500],
                                                  ),
                                                  SizedBox(width: Responsive.padding(context, 2)),
                                                  Text(
                                                    'Faster',
                                                    style: TextStyle(
                                                      fontSize: Responsive.fontSize(context, 10),
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.red[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: Responsive.padding(context, 12)),
                                        Container(
                                          height: Responsive.fontSize(context, 8),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                          child: Stack(
                                            children: [
                                              FractionallySizedBox(
                                                widthFactor: 0.75,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [
                                                        Color(0xFF37EC13),
                                                        Color(0xFF16A085),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(9999),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: Responsive.padding(context, 8)),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'Compared to peer group avg.',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(context, 10),
                                              color: isDark ? Colors.grey[400] : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // AI Message 2: Plan
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: Responsive.fontSize(context, 40) + Responsive.padding(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text Bubble
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[100]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  "I've created a personalized recovery plan for you to get back on track.",
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 14),
                                    height: 1.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 12)),
                              // Checklist Widget
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 4)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[100]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Today's Goals",
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(context, 14),
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: Responsive.padding(context, 8),
                                              vertical: Responsive.padding(context, 4),
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF37EC13).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(9999),
                                            ),
                                            child: Text(
                                              '${_checkedItems.where((e) => e).length}/3',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 10),
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF37EC13),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _ChecklistItem(
                                      title: 'Hydration intake +500ml',
                                      subtitle: 'Water helps elasticity',
                                      isChecked: _checkedItems[0],
                                      onTap: () => _toggleCheckbox(0),
                                      isDark: isDark,
                                    ),
                                    _ChecklistItem(
                                      title: 'Vitamin C serum',
                                      subtitle: 'Morning application',
                                      isChecked: _checkedItems[1],
                                      onTap: () => _toggleCheckbox(1),
                                      isDark: isDark,
                                    ),
                                    _ChecklistItem(
                                      title: 'Sleep before 11 PM',
                                      subtitle: 'Critical for repair',
                                      isChecked: _checkedItems[2],
                                      onTap: () => _toggleCheckbox(2),
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // User Message
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF37EC13),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(4),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF37EC13).withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'How does coffee affect my skin?',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 14),
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 4)),
                              Padding(
                                padding: EdgeInsets.only(
                                  right: Responsive.padding(context, 4),
                                ),
                                child: Text(
                                  'Read 9:45 AM',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // AI Typing Indicator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: Responsive.fontSize(context, 32),
                          height: Responsive.fontSize(context, 32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                              width: 1,
                            ),
                            image: const DecorationImage(
                              image: NetworkImage(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuADVFcnAIjFTuuZnJ86DJ-Qv4yadoRCo4fHEAe0LGH-hGfgM27e6k7w9R0GG2BoGaDaWmaUSumjApu5AZRBk8o_KP9uHS59tSHa1gAnlhiTxfqAJrsTqQD0bTpefRCY-mX4fEmSau1i2jwU1qZBWSTyqOll9FL_aRkFkl53snCPQdzBdfIoar9neryiWtbvQYAGgYbDABT9wBBre9Nb16QyEuB15Ru-pNgxFW71WTFGv8EA_KNPfW8tjKMcDiO_6UcNKZXleBF0Mdo',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.padding(context, 16),
                            vertical: Responsive.padding(context, 12),
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[100]!,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TypingDot(delay: 0),
                              SizedBox(width: Responsive.padding(context, 4)),
                              _TypingDot(delay: 200),
                              SizedBox(width: Responsive.padding(context, 4)),
                              _TypingDot(delay: 400),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 200)),
                  ],
                ),
              ),
            ),

            // Bottom Input Area
            Container(
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                    .withOpacity(0.95),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Quick Action Chips
                  SizedBox(
                    height: Responsive.fontSize(context, 72),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: Responsive.padding(context, 12),
                      ),
                      children: [
                        _QuickActionChip(
                          text: 'Show my future face 🔮',
                          isDark: isDark,
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        _QuickActionChip(
                          text: 'More diet tips 🍎',
                          isDark: isDark,
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        _QuickActionChip(
                          text: 'Review skin scan 📸',
                          isDark: isDark,
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        _QuickActionChip(
                          text: 'Sleep advice 💤',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  // Input Field
                  Padding(
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: Responsive.padding(context, 24),
                      top: Responsive.padding(context, 4),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(Responsive.padding(context, 6)),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[200]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // TODO: Add photo
                                debugPrint('Add photo tapped');
                              },
                              borderRadius: BorderRadius.circular(9999),
                              child: Container(
                                width: Responsive.fontSize(context, 40),
                                height: Responsive.fontSize(context, 40),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.add_a_photo,
                                  size: Responsive.iconSize(context, 20),
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 14),
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ask about your skin health...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[400],
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: Responsive.padding(context, 8),
                                  vertical: Responsive.padding(context, 8),
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: const Color(0xFF37EC13),
                            borderRadius: BorderRadius.circular(9999),
                            child: InkWell(
                              onTap: _onSend,
                              borderRadius: BorderRadius.circular(9999),
                              child: Container(
                                width: Responsive.fontSize(context, 40),
                                height: Responsive.fontSize(context, 40),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF37EC13).withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_upward,
                                  size: Responsive.iconSize(context, 20),
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Checklist Item Widget
class _ChecklistItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isChecked;
  final VoidCallback onTap;
  final bool isDark;

  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.isChecked,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(Responsive.padding(context, 12)),
          decoration: BoxDecoration(
            color: isChecked
                ? (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[50])
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: Responsive.fontSize(context, 24),
                height: Responsive.fontSize(context, 24),
                decoration: BoxDecoration(
                  color: isChecked
                      ? const Color(0xFF37EC13)
                      : Colors.transparent,
                  border: Border.all(
                    color: isChecked
                        ? const Color(0xFF37EC13)
                        : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isChecked
                    ? Icon(
                        Icons.check,
                        size: Responsive.iconSize(context, 16),
                        color: Colors.black,
                      )
                    : null,
              ),
              SizedBox(width: Responsive.padding(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
                        color: isChecked
                            ? (isDark ? Colors.grey[400] : Colors.grey[400])
                            : (isDark ? Colors.white : Colors.black87),
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Typing Dot Widget
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value * 3 + (widget.delay / 1000)) % 1.0;
        final scale = value < 0.4
            ? (value / 0.4)
            : value > 0.8
                ? (1 - value) / 0.2
                : 1.0;

        return Transform.scale(
          scale: scale.clamp(0.0, 1.0),
          child: Container(
            width: Responsive.fontSize(context, 8),
            height: Responsive.fontSize(context, 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// Quick Action Chip Widget
class _QuickActionChip extends StatelessWidget {
  final String text;
  final bool isDark;

  const _QuickActionChip({
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Handle quick action
          debugPrint('Quick action: $text');
        },
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 24),
            vertical: Responsive.padding(context, 14),
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2E18) : Colors.white,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey[200]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

