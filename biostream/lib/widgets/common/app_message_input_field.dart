import 'package:flutter/material.dart';

class AppMessageInputField extends StatelessWidget {
  const AppMessageInputField({
    super.key,
    required this.isDark,
    required this.controller,
    required this.hintText,
    required this.onSend,
    this.isSendDisabled = false,
    this.leading,
    this.textStyle,
    this.hintStyle,
    this.containerPadding = const EdgeInsets.all(5),
    this.borderRadius = 28,
    this.inputContentPadding =
        const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    this.sendButtonSize = 38,
    this.sendIconSize = 20,
    this.activeSendColor = const Color(0xFF37EC13),
    this.disabledSendColor = Colors.grey,
    this.sendIcon = Icons.arrow_upward,
    this.disabledSendIcon = Icons.hourglass_top,
    this.sendShadowColor,
    this.onSubmitted,
  });

  final bool isDark;
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSend;
  final bool isSendDisabled;
  final Widget? leading;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry containerPadding;
  final double borderRadius;
  final EdgeInsetsGeometry inputContentPadding;
  final double sendButtonSize;
  final double sendIconSize;
  final Color activeSendColor;
  final Color disabledSendColor;
  final IconData sendIcon;
  final IconData disabledSendIcon;
  final Color? sendShadowColor;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: containerPadding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2E18) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: TextField(
              controller: controller,
              style: textStyle ??
                  TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: hintStyle ??
                    TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 14,
                    ),
                border: InputBorder.none,
                contentPadding: inputContentPadding,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmitted ?? (_) => onSend(),
            ),
          ),
          Material(
            color: isSendDisabled ? disabledSendColor : activeSendColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isSendDisabled ? null : onSend,
              child: Container(
                width: sendButtonSize,
                height: sendButtonSize,
                alignment: Alignment.center,
                decoration: sendShadowColor == null
                    ? null
                    : BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: sendShadowColor!,
                            blurRadius: 15,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                child: Icon(
                  isSendDisabled ? disabledSendIcon : sendIcon,
                  size: sendIconSize,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
