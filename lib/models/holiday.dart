enum HolidayType {
  liburNasional,
  cutiBersama,
  hariBesarNasional,
  hariBesarInternasional;

  static HolidayType fromString(String value) {
    switch (value) {
      case 'libur_nasional':
        return HolidayType.liburNasional;
      case 'cuti_bersama':
        return HolidayType.cutiBersama;
      case 'hari_besar_internasional':
        return HolidayType.hariBesarInternasional;
      default:
        return HolidayType.hariBesarNasional;
    }
  }

  String get label {
    switch (this) {
      case HolidayType.liburNasional:
        return 'Libur Nasional';
      case HolidayType.cutiBersama:
        return 'Cuti Bersama';
      case HolidayType.hariBesarNasional:
        return 'Hari Besar Nasional';
      case HolidayType.hariBesarInternasional:
        return 'Hari Besar Internasional';
    }
  }

  String get shortLabel {
    switch (this) {
      case HolidayType.liburNasional:
        return 'Libur';
      case HolidayType.cutiBersama:
        return 'Cuti';
      case HolidayType.hariBesarNasional:
        return 'HBN';
      case HolidayType.hariBesarInternasional:
        return 'HBI';
    }
  }

  int get sortOrder {
    switch (this) {
      case HolidayType.liburNasional:
        return 0;
      case HolidayType.cutiBersama:
        return 1;
      case HolidayType.hariBesarNasional:
        return 2;
      case HolidayType.hariBesarInternasional:
        return 3;
    }
  }
}

class Holiday {
  final DateTime date;
  final String name;
  final HolidayType type;
  final bool isNationalHoliday;
  final String? description;
  final String? sejarah;
  final String? imageUrl;

  const Holiday({
    required this.date,
    required this.name,
    required this.type,
    required this.isNationalHoliday,
    this.description,
    this.sejarah,
    this.imageUrl,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['image_url'] as String?;
    final sejarah = json['sejarah'] as String?;
    return Holiday(
      date: DateTime.parse(json['date'] as String),
      name: json['name'] as String,
      type: HolidayType.fromString(json['type'] as String),
      isNationalHoliday: json['is_national_holiday'] as bool? ?? false,
      description: json['description'] as String?,
      sejarah:
          (sejarah != null && sejarah.trim().isEmpty) ? null : sejarah,
      imageUrl: (imageUrl != null && imageUrl.trim().isEmpty) ? null : imageUrl,
    );
  }
}
