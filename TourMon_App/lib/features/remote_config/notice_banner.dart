import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'app_config.dart';

/// 지도 화면 상단에 붙는 원격 공지 한 줄(`AppGate`가 배치). 색은 테마가 아니라 level별 고정값 —
/// 지도(크림색 스케치 테마) 위에서도 확실히 눈에 띄고 어느 테마에서든 대비가 보장되게.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final AppNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final text = notice.forLocale(languageCode);
    final palette = _paletteFor(notice.level);
    final dismissible = notice.level != 'critical';
    final hasUrl = notice.url != null;

    return Material(
      color: palette.background,
      child: InkWell(
        onTap: hasUrl
            ? () => launchUrl(
                Uri.parse(notice.url!),
                mode: LaunchMode.externalApplication,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(palette.icon, size: 18, color: palette.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.title.isNotEmpty)
                      Text(
                        text.title,
                        style: TextStyle(
                          color: palette.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      text.body,
                      style: TextStyle(
                        color: palette.foreground,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUrl)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Icon(
                    Icons.open_in_new,
                    size: 15,
                    color: palette.foreground,
                  ),
                ),
              if (dismissible)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onDismiss,
                  tooltip: l10n.noticeDismissTooltip,
                  icon: Icon(Icons.close, size: 18, color: palette.foreground),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerPalette {
  const _BannerPalette(this.background, this.foreground, this.icon);
  final Color background;
  final Color foreground;
  final IconData icon;
}

_BannerPalette _paletteFor(String level) {
  switch (level) {
    case 'critical':
      return const _BannerPalette(
        Color(0xFFB3261E),
        Colors.white,
        Icons.error_outline,
      );
    case 'warn':
      return const _BannerPalette(
        Color(0xFFF2B705),
        Color(0xFF3A2E00),
        Icons.warning_amber_rounded,
      );
    default:
      return const _BannerPalette(
        Color(0xFF2C6EAD),
        Colors.white,
        Icons.info_outline,
      );
  }
}
