import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultAgingSimulationSection extends StatelessWidget {
  final bool isDark;
  final String currentAgeLabel;
  final String targetAgeLabel;
  final String? originalImageUrl;
  final String? generatedImageUrl;
  final int managedSkinAge;
  final int unmanagedSkinAge;
  final int visualGap;
  final double potentialPercentage;
  final Widget Function(String? imageUrl) imageBuilder;

  const ResultAgingSimulationSection({
    super.key,
    required this.isDark,
    required this.currentAgeLabel,
    required this.targetAgeLabel,
    required this.originalImageUrl,
    required this.generatedImageUrl,
    required this.managedSkinAge,
    required this.unmanagedSkinAge,
    required this.visualGap,
    required this.potentialPercentage,
    required this.imageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: Responsive.fontSize(context, 80),
                    height: Responsive.fontSize(context, 80),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(19.2),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
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
                                  Colors.black.withValues(alpha: 0.1),
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
                    currentAgeLabel,
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
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.grey[300],
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
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
                          color: isDark
                              ? const Color(0xFF132210)
                              : const Color(0xFFF6F8F6),
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
                            : [
                                const Color(0xFF101B0D),
                                const Color(0xFF1F3519)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(19.2),
                      border: Border.all(
                        color: const Color(0xFF37EC13),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF37EC13).withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            targetAgeLabel,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 28),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF101B0D)
                                  : Colors.white,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF37EC13)
                                  .withValues(alpha: 0.1),
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
        SizedBox(
          height: Responsive.fontSize(context, 416),
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          bottomLeft: Radius.circular(32),
                        ),
                        border: Border.all(
                          color: const Color(0xFF37EC13).withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF37EC13).withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                              child: imageBuilder(originalImageUrl)),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.9),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                                  SizedBox(
                                      width: Responsive.padding(context, 4)),
                                  Text(
                                    'Managed O',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 10),
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF101B0D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                                SizedBox(
                                    height: Responsive.padding(context, 4)),
                                Text(
                                  'Skin Age: $managedSkinAge',
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
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                const Color(0xFF8B6914).withValues(alpha: 0.2),
                                BlendMode.overlay,
                              ),
                              child: imageBuilder(generatedImageUrl),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.9),
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                                    color: Colors.black.withValues(alpha: 0.2),
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
                                  SizedBox(
                                      width: Responsive.padding(context, 4)),
                                  Text(
                                    'Managed X',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 10),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                                SizedBox(
                                    height: Responsive.padding(context, 4)),
                                Text(
                                  'Skin Age: $unmanagedSkinAge',
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
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.grey[100]!,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
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
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.red[900]!.withValues(alpha: 0.1)
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.red[900]!.withValues(alpha: 0.3)
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
                                ? Colors.red[300]!.withValues(alpha: 0.7)
                                : Colors.red[600]!.withValues(alpha: 0.7),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.padding(context, 8)),
                    Text(
                      '$visualGap Yrs',
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
                      ? Colors.green[900]!.withValues(alpha: 0.1)
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.green[900]!.withValues(alpha: 0.3)
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
                                ? Colors.green[300]!.withValues(alpha: 0.7)
                                : Colors.green[600]!.withValues(alpha: 0.7),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.padding(context, 8)),
                    Text(
                      '-${potentialPercentage.toStringAsFixed(0)}%',
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
      ],
    );
  }
}
