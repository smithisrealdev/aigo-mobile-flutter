import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sharing_service.dart';
import '../theme/app_colors.dart';

/// Share trip widget with toggle, copy link, and system share.
class ShareTripWidget extends ConsumerStatefulWidget {
  final String tripId;
  const ShareTripWidget({super.key, required this.tripId});

  @override
  ConsumerState<ShareTripWidget> createState() => _ShareTripWidgetState();
}

class _ShareTripWidgetState extends ConsumerState<ShareTripWidget> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final shareAsync = ref.watch(tripShareInfoProvider(widget.tripId));

    return shareAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (info) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.share, size: 18, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                  const Text('Share Trip',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                  else
                    Switch(
                      value: info.isPublic,
                      activeTrackColor: AppColors.brandBlue,
                      onChanged: (val) => _toggleSharing(val),
                    ),
                ],
              ),
              if (info.isPublic && info.shareUrl != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(info.shareUrl!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.brandBlue),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _copyLink(info.shareUrl!),
                        child: const Icon(Icons.copy,
                            size: 18, color: AppColors.brandBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${info.shareViews} views',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _systemShare(info.shareUrl!),
                      icon:
                          const Icon(Icons.ios_share, size: 16),
                      label: const Text('Share',
                          style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSharing(bool enable) async {
    setState(() => _loading = true);
    try {
      if (enable) {
        await SharingService.instance.enableSharing(widget.tripId);
      } else {
        await SharingService.instance.disableSharing(widget.tripId);
      }
      ref.invalidate(tripShareInfoProvider(widget.tripId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard!')));
    }
  }

  Future<void> _systemShare(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
