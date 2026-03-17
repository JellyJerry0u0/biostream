import 'package:flutter/material.dart';

class FaceCardItem {
  const FaceCardItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final bool highlight;
}

class MetricItem {
  const MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool wide;
}
