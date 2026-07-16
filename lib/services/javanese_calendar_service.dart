// Pasaran cycle: Legi → Pahing → Pon → Wage → Kliwon (5-day cycle)
// Reference: 2024-01-01 = Senin Pahing — verified against two independent
// historical anchors (17 Aug 1945 = Jumat Legi; the Javanese calendar epoch
// 8 Jul 1633 = Jumat Legi), both of which land on Pahing for 2024-01-01.
// An earlier version of this file wrongly assumed 2024-01-01 was Legi,
// shifting every computed pasaran back by one day in the cycle.
const List<String> _kPasaran = ['Legi', 'Pahing', 'Pon', 'Wage', 'Kliwon'];
const List<String> _kDayNames = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
];
final DateTime _kRefDate = DateTime(2024, 1, 1);
const int _kRefPasaranIndex = 1; // Pahing

String getPasaran(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(_kRefDate).inDays;
  return _kPasaran[((diff + _kRefPasaranIndex) % 5 + 5) % 5];
}

String getWeton(DateTime date) {
  return '${_kDayNames[date.weekday - 1]} ${getPasaran(date)}';
}
