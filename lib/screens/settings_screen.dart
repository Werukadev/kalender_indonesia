import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/theme_presets.dart';
import '../models/holiday.dart';
import '../models/theme_preset.dart';
import '../providers/settings_provider.dart';
import '../widgets/about_app_dialog.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Tentang Aplikasi',
            onPressed: () => AboutAppDialog.show(context),
          ),
        ],
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
          _SettingsCard(
            children: [
              for (int i = 0; i < kThemePresets.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                _ThemePresetTile(
                  preset: kThemePresets[i],
                  isSelected: settings.selectedThemeId == kThemePresets[i].id,
                  onTap: () => settings.setThemePreset(kThemePresets[i].id),
                ),
              ],
            ],
          ),
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
          const SizedBox(height: 20),
          _sectionLabel('PRATINJAU'),
          _PreviewCard(settings: settings, preset: preset),
          const SizedBox(height: 8),
        ],
      ),
    );
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

// ── Theme Preset Tile ──────────────────────────────────────────────────────────

class _ThemePresetTile extends StatelessWidget {
  final ThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            _ThemeColorPreview(preset: preset, isSelected: isSelected),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? preset.primaryColor
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _ColorChip(
                        color: preset.primaryColor,
                        label: 'AppBar',
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 6),
                      _ColorChip(
                        color: preset.headerColor,
                        label: 'Header',
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 6),
                      _ColorChip(
                        color: preset.accentColor,
                        label: 'Aksen',
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: isSelected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey(true),
                      color: preset.primaryColor,
                      size: 22,
                    )
                  : Icon(
                      Icons.radio_button_unchecked,
                      key: const ValueKey(false),
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 22,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeColorPreview extends StatelessWidget {
  final ThemePreset preset;
  final bool isSelected;

  const _ThemeColorPreview({required this.preset, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isSelected
              ? preset.primaryColor
              : Colors.black.withValues(alpha: 0.1),
          width: isSelected ? 2 : 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.5),
        child: SizedBox(
          width: 52,
          height: 40,
          child: Column(
            children: [
              // AppBar layer
              Container(height: 14, color: preset.primaryColor),
              // Header layer
              Container(height: 10, color: preset.headerColor),
              // Accent layer
              Expanded(child: ColoredBox(color: preset.accentColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final String label;
  final ColorScheme colorScheme;

  const _ColorChip({
    required this.color,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
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

  const _PreviewCard({required this.settings, required this.preset});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fw = settings.resolvedFontWeight;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mini AppBar
          Container(
            color: preset.primaryColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Kalender Indonesia',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          // Mini Month Header
          Container(
            color: preset.headerColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 18),
                Text(
                  'Juni 2026',
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hari libur nasional & cuti bersama',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: fw == FontWeight.bold ? FontWeight.bold : FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pratinjau tampilan teks dengan ukuran dan ketebalan yang dipilih.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: fw,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
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
                      'Warna aksen tema',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: fw,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
