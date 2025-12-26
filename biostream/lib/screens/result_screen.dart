import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'coach_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

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
              padding: EdgeInsets.all(horizontalPadding),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                    .withOpacity(0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back,
                          size: Responsive.iconSize(context, 24),
                          color: isDark ? Colors.white : const Color(0xFF101B0D),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Results',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF101B0D),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // TODO: Share functionality
                        debugPrint('Share tapped');
                      },
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.share,
                          size: Responsive.iconSize(context, 24),
                          color: isDark ? Colors.white : const Color(0xFF101B0D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: Responsive.padding(context, 8)),

                    // Title
                    Text(
                      'Aging Simulation',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 24),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF101B0D),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // Age Comparison
                    Row(
                      children: [
                        // Current Age
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: Responsive.fontSize(context, 80),
                                height: Responsive.fontSize(context, 80),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(19.2),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Icon(
                                        Icons.face_3,
                                        size: Responsive.iconSize(context, 32),
                                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topRight,
                                            end: Alignment.bottomLeft,
                                            colors: [
                                              Colors.black.withOpacity(0.1),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 8)),
                              Text(
                                'Now (29)',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Arrow
                        Expanded(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 2,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: Responsive.padding(context, 16),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.grey[300],
                                      border: Border(
                                        top: BorderSide(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.2)
                                              : Colors.grey[300]!,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.padding(context, 12),
                                      vertical: Responsive.padding(context, 4),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                                    ),
                                    child: Icon(
                                      Icons.double_arrow,
                                      size: Responsive.iconSize(context, 18),
                                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Target Age
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: Responsive.fontSize(context, 80),
                                height: Responsive.fontSize(context, 80),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [Colors.white, Colors.grey[200]!]
                                        : [const Color(0xFF101B0D), const Color(0xFF1F3519)],
                                  ),
                                  borderRadius: BorderRadius.circular(19.2),
                                  border: Border.all(
                                    color: const Color(0xFF37EC13),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF37EC13).withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        '65',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 28),
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFF101B0D) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF37EC13).withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 8)),
                              Text(
                                'Target Age',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF37EC13),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 8)),

                    // Comparison Images
                    SizedBox(
                      height: Responsive.fontSize(context, 416),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              // Left Image - Managed
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(32),
                                      bottomLeft: Radius.circular(32),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF37EC13).withOpacity(0.5),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF37EC13).withOpacity(0.15),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      // Background Image
                                      Positioned.fill(
                                        child: Image.network(
                                          'https://lh3.googleusercontent.com/aida-public/AB6AXuAVgLhxQjr6XcFn3pYtbFXsIgwavfdfKcUWRoxceiF00ANrQBSfg_wG0oFEgjL5WWm5kraJorj0oQC4VnrpulMvma-RuqrajUpw1jKsrwnXTH0nlWEPYyxKxtUseeW5D7o5FA_76S3fnNLBRF_ibtrRmnClgmZHhEiXdy91BjWEDNSu0Jhq-DNT3WyZQAubItHILDJC3eX1LMj1yzEEaPdU-mW6WPGWrZ7XLJjHfb9-hGnDQ-gT9A8D_TXVuGjUZZTkO_42N9N2u08',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(Icons.image, size: 64, color: Colors.grey),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // Gradient Overlay
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.1),
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.9),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Badge
                                      Positioned(
                                        top: Responsive.padding(context, 12),
                                        left: Responsive.padding(context, 12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.padding(context, 8),
                                            vertical: Responsive.padding(context, 4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF37EC13),
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: Responsive.iconSize(context, 12),
                                                color: const Color(0xFF101B0D),
                                              ),
                                              SizedBox(width: Responsive.padding(context, 4)),
                                              Text(
                                                'Managed O',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(context, 10),
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF101B0D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Bottom Text
                                      Positioned(
                                        bottom: Responsive.padding(context, 20),
                                        left: Responsive.padding(context, 16),
                                        right: Responsive.padding(context, 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Youthful',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 20),
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.0,
                                              ),
                                            ),
                                            SizedBox(height: Responsive.padding(context, 4)),
                                            Text(
                                              'Skin Age: 58',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 10),
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF37EC13),
                                                letterSpacing: 2.0,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Right Image - Not Managed
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(32),
                                      bottomRight: Radius.circular(32),
                                    ),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      // Background Image
                                      Positioned.fill(
                                        child: ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            const Color(0xFF8B6914).withOpacity(0.2),
                                            BlendMode.overlay,
                                          ),
                                          child: Image.network(
                                            'https://lh3.googleusercontent.com/aida-public/AB6AXuD8EoLjlWq_Qs_DhHULiDlDtZSuAodwVFDHJuKKr5PZPM-nNQFLjeZpQA7S12sE7f7IOll6EQYwQFtYCjzBR6aweEcx_BeF-tuhLg-34Efyjk9zCcorMwoOk-KmzxsUxX5GXjSbkAl3eiaen_ngosFQcpTbybmdpJ-WyG2LJIPKb29QF18TT4GJJNK2PInMdvHZnSr64hvULASaITFzfQ1JuT4LRza4Y6onaZiWRM3M76g8wmRURDuRrPbW-GVt3SnbgwuMBDma_xQ',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(Icons.image, size: 64, color: Colors.grey),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      // Gradient Overlay
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.9),
                                                Colors.black.withOpacity(0.1),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Badge
                                      Positioned(
                                        top: Responsive.padding(context, 12),
                                        right: Responsive.padding(context, 12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.padding(context, 8),
                                            vertical: Responsive.padding(context, 4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[600],
                                            borderRadius: BorderRadius.circular(9999),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.close,
                                                size: Responsive.iconSize(context, 12),
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: Responsive.padding(context, 4)),
                                              Text(
                                                'Managed X',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(context, 10),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Bottom Text
                                      Positioned(
                                        bottom: Responsive.padding(context, 20),
                                        left: Responsive.padding(context, 16),
                                        right: Responsive.padding(context, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Aged',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 20),
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.0,
                                              ),
                                            ),
                                            SizedBox(height: Responsive.padding(context, 4)),
                                            Text(
                                              'Skin Age: 72',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 10),
                                                fontWeight: FontWeight.w500,
                                                color: Colors.red[400],
                                                letterSpacing: 2.0,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // VS Badge
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 8)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A4025) : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.2)
                                        : Colors.grey[100]!,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 8)),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(Responsive.padding(context, 16)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.red[900]!.withOpacity(0.1)
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.red[900]!.withOpacity(0.3)
                                    : Colors.red[100]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.face_retouching_off,
                                      size: Responsive.iconSize(context, 20),
                                      color: isDark ? Colors.red[400] : Colors.red[700],
                                    ),
                                    SizedBox(width: Responsive.padding(context, 8)),
                                    Text(
                                      'Visual Gap',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 10),
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.red[300]!.withOpacity(0.7)
                                            : Colors.red[600]!.withOpacity(0.7),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  '14 Yrs',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 28),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.red[100] : Colors.red[900],
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  'Difference in apparent age',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.red[400] : Colors.red[600],
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(Responsive.padding(context, 16)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green[900]!.withOpacity(0.1)
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.green[900]!.withOpacity(0.3)
                                    : Colors.green[100]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      size: Responsive.iconSize(context, 20),
                                      color: isDark ? Colors.green[400] : Colors.green[700],
                                    ),
                                    SizedBox(width: Responsive.padding(context, 8)),
                                    Text(
                                      'Potential',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 10),
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.green[300]!.withOpacity(0.7)
                                            : Colors.green[600]!.withOpacity(0.7),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  '-25%',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 28),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.green[100] : Colors.green[900],
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  'Less wrinkles with care',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.green[400] : Colors.green[700],
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Critical Factors Section
                    Container(
                      padding: EdgeInsets.all(Responsive.padding(context, 20)),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A2C17) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey[100]!,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Critical Factors',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 18),
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
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Impact Score',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.padding(context, 16)),
                          // Collagen Preservation
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Collagen Preservation',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'High Impact',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[500],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.padding(context, 6)),
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
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(9999),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: 0.85,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red[500],
                                          borderRadius: BorderRadius.circular(9999),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red[500]!.withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 0,
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
                          SizedBox(height: Responsive.padding(context, 16)),
                          // UV Damage Control
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'UV Damage Control',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'Medium Impact',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.yellow[500],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.padding(context, 6)),
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
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(9999),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: 0.6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.yellow[500],
                                          borderRadius: BorderRadius.circular(9999),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // Action Buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: Responsive.fontSize(context, 56),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const CoachScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF37EC13),
                              foregroundColor: const Color(0xFF101B0D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              elevation: 0,
                              shadowColor: const Color(0xFF37EC13).withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View Action Plan',
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
                        SizedBox(height: Responsive.padding(context, 12)),
                        SizedBox(
                          width: double.infinity,
                          height: Responsive.fontSize(context, 56),
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Save comparison
                              debugPrint('Save Comparison tapped');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF101B0D),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.grey[200]!,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.download,
                                  size: Responsive.iconSize(context, 20),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Text(
                                  'Save Comparison',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 16),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

