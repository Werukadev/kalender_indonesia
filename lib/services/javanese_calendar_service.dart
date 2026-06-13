// Pasaran cycle: Legi → Pahing → Pon → Wage → Kliwon (5-day cycle)
// Reference: 2024-01-01 = Senin Legi
const List<String> _kPasaran = ['Legi', 'Pahing', 'Pon', 'Wage', 'Kliwon'];
const List<String> _kDayNames = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
];
final DateTime _kRefDate = DateTime(2024, 1, 1);

String getPasaran(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(_kRefDate).inDays;
  return _kPasaran[((diff % 5) + 5) % 5];
}

String getWeton(DateTime date) {
  return '${_kDayNames[date.weekday - 1]} ${getPasaran(date)}';
}
