import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/api_config.dart';
import '../../utils/responsive.dart';

/// `/data/image/...` 는 JWT가 필요해 [Image.network]만으로는 401 → 빈 화면이 됨.
class ResultNetworkImage extends StatefulWidget {
  const ResultNetworkImage({
    super.key,
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  State<ResultNetworkImage> createState() => _ResultNetworkImageState();
}

class _ResultNetworkImageState extends State<ResultNetworkImage> {
  static const _storage = FlutterSecureStorage();
  Map<String, String>? _headers;

  static int _effectivePort(Uri u) {
    if (u.hasPort) return u.port;
    return u.scheme == 'https' ? 443 : 80;
  }

  static bool _needsApiAuth(String url, String origin) {
    try {
      final u = Uri.parse(url);
      final o = Uri.parse(origin);
      if (u.scheme != o.scheme) return false;
      if (u.host.toLowerCase() != o.host.toLowerCase()) return false;
      if (_effectivePort(u) != _effectivePort(o)) return false;
      return u.path.contains('/data/image/');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _prepareHeaders();
  }

  @override
  void didUpdateWidget(ResultNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _prepareHeaders();
    }
  }

  Future<void> _prepareHeaders() async {
    final raw = widget.imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      if (mounted) setState(() => _headers = null);
      return;
    }
    final origin = await ApiConfig.getBaseOrigin();
    if (!_needsApiAuth(raw, origin)) {
      if (mounted) setState(() => _headers = const {});
      return;
    }
    final token = await _storage.read(key: 'jwt_token');
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() => _headers = {'Authorization': 'Bearer $token'});
    } else {
      setState(() => _headers = const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(
            Icons.image,
            size: Responsive.iconSize(context, 64),
            color: Colors.grey,
          ),
        ),
      );
    }

    if (_headers == null) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: SizedBox(
            width: Responsive.iconSize(context, 32),
            height: Responsive.iconSize(context, 32),
            child: const CircularProgressIndicator(
              color: Color(0xFF37EC13),
            ),
          ),
        ),
      );
    }

    return Image.network(
      widget.imageUrl!,
      fit: BoxFit.cover,
      headers: _headers!.isEmpty ? null : _headers,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: const Color(0xFF37EC13),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(
              Icons.image,
              size: Responsive.iconSize(context, 64),
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
