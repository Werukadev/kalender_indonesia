import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/theme_presets.dart';
import '../models/holiday.dart';
import '../models/theme_preset.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final preset = settings.selectedPreset;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: preset.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text('Pengaturan'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _sectionLabel('TAMPILAN'),
          _SettingsCard(
            children: [
              _SettingItem(
                icon: Icons.brightness_6_outlined,
                label: 'Mode Tampilan',
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                      label: Text('Terang'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                      label: Text('Gelap'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.phone_android_outlined, size: 16),
                      label: Text('Sistem'),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (v) => settings.setThemeMode(v.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('TEMA APLIKASI'),
          _ThemePreviewPager(settings: settings),
          const SizedBox(height: 20),
          _sectionLabel('TAMPILKAN JENIS'),
          _SettingsCard(
            children: [
              for (int i = 0; i < HolidayType.values.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                _HolidayTypeToggle(
                  type: HolidayType.values[i],
                  isEnabled: settings.isTypeVisible(HolidayType.values[i]),
                  isLastEnabled: settings.visibleTypes.length == 1 &&
                      settings.isTypeVisible(HolidayType.values[i]),
                  onToggle: () => settings.toggleHolidayType(HolidayType.values[i]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('NOTIFIKASI'),
          _SettingsCard(
            children: [
              _NotificationToggle(
                isEnabled: settings.notificationsEnabled,
                onToggle: () => _toggleNotifications(context, settings),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('KALENDER JAWA'),
          _SettingsCard(
            children: [
              _JavaneseCalendarToggle(
                isEnabled: settings.showJavaneseCalendar,
                onToggle: () => settings.setShowJavaneseCalendar(
                  !settings.showJavaneseCalendar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('TEKS'),
          _SettingsCard(
            children: [
              _SettingItem(
                icon: Icons.format_size_outlined,
                label: 'Ukuran Teks',
                child: SegmentedButton<AppTextSize>(
                  segments: const [
                    ButtonSegment(
                      value: AppTextSize.small,
                      label: Text('Kecil'),
                    ),
                    ButtonSegment(
                      value: AppTextSize.medium,
                      label: Text('Sedang'),
                    ),
                    ButtonSegment(
                      value: AppTextSize.big,
                      label: Text('Besar'),
                    ),
                  ],
                  selected: {settings.textSize},
                  onSelectionChanged: (v) => settings.setTextSize(v.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              _SettingItem(
                icon: Icons.format_bold_outlined,
                label: 'Ketebalan Huruf',
                child: SegmentedButton<AppFontWeight>(
                  segments: const [
                    ButtonSegment(
                      value: AppFontWeight.standard,
                      label: Text('Standar'),
                    ),
                    ButtonSegment(
                      value: AppFontWeight.bold,
                      label: Text('Tebal'),
                    ),
                  ],
                  selected: {settings.fontWeight},
                  onSelectionChanged: (v) => settings.setFontWeight(v.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              _CellBorderToggle(
                isEnabled: settings.showCellBorder,
                onToggle: () =>
                    settings.setShowCellBorder(!settings.showCellBorder),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final enabling = !settings.notificationsEnabled;
    if (enabling) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin notifikasi ditolak — aktifkan lewat pengaturan sistem.',
              ),
            ),
          );
        }
        return;
      }
      await settings.setNotificationsEnabled(true);
      // Fire-and-forget: builds the schedule for current + next month.
      NotificationService.resync(
        ApiService(),
        enabled: true,
        visibleTypes: settings.visibleTypes,
      );
    } else {
      await settings.setNotificationsEnabled(false);
      await NotificationService.cancelAll();
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }
}

// ── Theme Preview Pager ────────────────────────────────────────────────────────

/// Swipeable, live theme picker: each page previews one preset; settling on
/// a page applies that theme immediately.
class _ThemePreviewPager extends StatefulWidget {
  final SettingsProvider settings;

  const _ThemePreviewPager({required this.settings});

  @override
  State<_ThemePreviewPager> createState() => _ThemePreviewPagerState();
}

class _ThemePreviewPagerState extends State<_ThemePreviewPager> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    final initial = kThemePresets
        .indexWhere((p) => p.id == widget.settings.selectedThemeId);
    _page = initial < 0 ? 0 : initial;
    _controller = PageController(
      viewportFraction: 0.86,
      initialPage: _page,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    widget.settings.setThemePreset(kThemePresets[i].id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = kThemePresets[_page].primaryColor;

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            itemCount: kThemePresets.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, i) {
              final preset = kThemePresets[i];
              final isSelected =
                  preset.id == widget.settings.selectedThemeId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () {
                    _controller.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: _PreviewCard(
                    settings: widget.settings,
                    preset: preset,
                    isSelected: isSelected,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(kThemePresets.length, (i) {
            final isActive = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor
                    : colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Geser pratinjau untuk mengganti tema',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

// ── Holiday Type Toggle ────────────────────────────────────────────────────────

const _kTypeColors = {
  HolidayType.liburNasional: Color(0xFFE53935),
  HolidayType.cutiBersama: Color(0xFFF57C00),
  HolidayType.hariBesarNasional: Color(0xFF1565C0),
  HolidayType.hariBesarInternasional: Color(0xFF7B1FA2),
};

const _kTypeDescriptions = {
  HolidayType.liburNasional: 'Hari libur resmi yang ditetapkan pemerintah',
  HolidayType.cutiBersama: 'Cuti bersama yang ditetapkan pemerintah',
  HolidayType.hariBesarNasional: 'Peringatan hari besar nasional',
  HolidayType.hariBesarInternasional: 'Peringatan hari besar internasional',
};

class _HolidayTypeToggle extends StatelessWidget {
  final HolidayType type;
  final bool isEnabled;
  final bool isLastEnabled;
  final VoidCallback onToggle;

  const _HolidayTypeToggle({
    required this.type,
    required this.isEnabled,
    required this.isLastEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = _kTypeColors[type]!;
    final effectiveColor =
        isEnabled ? typeColor : typeColor.withValues(alpha: 0.3);

    return InkWell(
      onTap: isLastEnabled ? null : onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _kTypeDescriptions[type]!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(
                        alpha: isEnabled ? 0.45 : 0.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: isLastEnabled ? null : (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: typeColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cell Border Toggle ─────────────────────────────────────────────────────────

class _CellBorderToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const _CellBorderToggle({required this.isEnabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        child: Row(
          children: [
            Icon(
              Icons.border_all_outlined,
              size: 20,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tampilkan Border Sel',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tampilkan garis tepi pada setiap sel tanggal',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(
                        alpha: isEnabled ? 0.45 : 0.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Toggle ────────────────────────────────────────────────────────

class _NotificationToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const _NotificationToggle({
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengingat Hari Penting',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Notifikasi lewat tengah malam pada tanggal hari libur '
                    'dan hari besar',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(
                        alpha: isEnabled ? 0.45 : 0.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Javanese Calendar Toggle ───────────────────────────────────────────────────

class _JavaneseCalendarToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const _JavaneseCalendarToggle({
    required this.isEnabled,
    required this.onToggle,
  });

  static const _toggleColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        child: Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: isEnabled
                  ? _toggleColor
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tampilkan Pasaran Jawa',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Menampilkan pasaran dan weton Jawa pada kalender',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(
                        alpha: isEnabled ? 0.45 : 0.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: _toggleColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview Card ───────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final SettingsProvider settings;
  final ThemePreset preset;
  final bool isSelected;

  const _PreviewCard({
    required this.settings,
    required this.preset,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fw = settings.resolvedFontWeight;
    // Dark presets preview on a dark surface even while the app is light.
    final surfaceColor =
        preset.isDark ? const Color(0xFF1C2027) : colorScheme.surface;
    final onSurface =
        preset.isDark ? Colors.white : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? preset.primaryColor
              : colorScheme.onSurface.withValues(alpha: 0.1),
          width: isSelected ? 2 : 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: ColoredBox(
          color: surfaceColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mini AppBar
              Container(
                color: preset.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        preset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
              ),
              // Mini Month Header
              Container(
                color: preset.headerColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.chevron_left, color: Colors.white, size: 18),
                    Text(
                      'Juli 2026',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ],
                ),
              ),
              // Content preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hari libur nasional & cuti bersama',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: fw == FontWeight.bold
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pratinjau tampilan teks dengan ukuran dan '
                        'ketebalan yang dipilih.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: fw,
                          color: onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: preset.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            preset.isDark
                                ? 'Tema gelap · warna aksen'
                                : 'Warna aksen tema',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: fw,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(children: children),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
