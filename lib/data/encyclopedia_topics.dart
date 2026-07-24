/// Static catalog for the "Ensiklopedia Indonesia" hub: categories, their
/// subtopics, and the Indonesian-Wikipedia search query each subtopic maps
/// to. Content itself is fetched live from id.wikipedia.org.
class EncyclopediaSubtopic {
  final String label;
  final String query;

  const EncyclopediaSubtopic(this.label, this.query);
}

class EncyclopediaCategory {
  final String emoji;
  final String name;
  final List<EncyclopediaSubtopic> subtopics;

  /// Illustration used as the category card's background (bundled asset).
  /// Categories without one fall back to the accent-colored card style.
  final String? imageAsset;

  const EncyclopediaCategory({
    required this.emoji,
    required this.name,
    required this.subtopics,
    this.imageAsset,
  });
}

const kEncyclopediaCategories = [
  EncyclopediaCategory(
    emoji: '🇮🇩',
    name: 'Budaya',
    imageAsset: 'assets/menu/budaya.jpg',
    subtopics: [
      EncyclopediaSubtopic('Suku', 'suku bangsa di Indonesia'),
      EncyclopediaSubtopic('Rumah Adat', 'rumah adat Indonesia'),
      EncyclopediaSubtopic('Tarian', 'tarian tradisional Indonesia'),
      EncyclopediaSubtopic('Pakaian Adat', 'pakaian adat Indonesia'),
      EncyclopediaSubtopic('Bahasa Daerah', 'bahasa daerah di Indonesia'),
      EncyclopediaSubtopic('Makanan Khas', 'makanan khas Indonesia'),
      EncyclopediaSubtopic('Upacara Adat', 'upacara adat Indonesia'),
      EncyclopediaSubtopic('Kerajinan', 'kerajinan tradisional Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '📜',
    name: 'Sejarah Indonesia',
    imageAsset: 'assets/menu/sejarah.jpg',
    subtopics: [
      EncyclopediaSubtopic('Kerajaan Nusantara', 'kerajaan di Nusantara'),
      EncyclopediaSubtopic(
        'Perjuangan Kemerdekaan',
        'perjuangan kemerdekaan Indonesia',
      ),
      EncyclopediaSubtopic('Tokoh Nasional', 'tokoh nasional Indonesia'),
      EncyclopediaSubtopic(
        'Peristiwa Bersejarah',
        'peristiwa bersejarah Indonesia',
      ),
      EncyclopediaSubtopic('Sejarah Provinsi', 'sejarah provinsi Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🏛️',
    name: 'Pahlawan Nasional',
    imageAsset: 'assets/menu/pahlawan.jpg',
    subtopics: [
      EncyclopediaSubtopic('Biografi', 'pahlawan nasional Indonesia'),
      EncyclopediaSubtopic('Jasa', 'jasa pahlawan nasional Indonesia'),
      EncyclopediaSubtopic('Foto', 'pahlawan nasional Indonesia foto'),
      EncyclopediaSubtopic('Hari Peringatan', 'hari pahlawan Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🌋',
    name: 'Geografi Indonesia',
    imageAsset: 'assets/menu/geografi.jpg',
    subtopics: [
      EncyclopediaSubtopic('Gunung', 'gunung di Indonesia'),
      EncyclopediaSubtopic('Sungai', 'sungai di Indonesia'),
      EncyclopediaSubtopic('Danau', 'danau di Indonesia'),
      EncyclopediaSubtopic('Pulau', 'pulau di Indonesia'),
      EncyclopediaSubtopic('Selat', 'selat di Indonesia'),
      EncyclopediaSubtopic('Laut', 'laut di Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🦜',
    name: 'Flora & Fauna',
    imageAsset: 'assets/menu/flora_fauna.jpg',
    subtopics: [
      EncyclopediaSubtopic('Hewan Endemik', 'hewan endemik Indonesia'),
      EncyclopediaSubtopic('Tumbuhan Langka', 'tumbuhan langka Indonesia'),
      EncyclopediaSubtopic('Satwa Dilindungi', 'satwa dilindungi Indonesia'),
      EncyclopediaSubtopic('Taman Nasional', 'taman nasional di Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🕌',
    name: 'Tempat Bersejarah & Wisata',
    imageAsset: 'assets/menu/tempat_bersejarah.jpg',
    subtopics: [
      EncyclopediaSubtopic('Candi', 'candi di Indonesia'),
      EncyclopediaSubtopic('Keraton', 'keraton di Indonesia'),
      EncyclopediaSubtopic('Museum', 'museum di Indonesia'),
      EncyclopediaSubtopic('Monumen', 'monumen di Indonesia'),
      EncyclopediaSubtopic(
        'Situs UNESCO',
        'situs warisan dunia UNESCO di Indonesia',
      ),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🍜',
    name: 'Kuliner Nusantara',
    imageAsset: 'assets/menu/kuliner.jpg',
    subtopics: [
      EncyclopediaSubtopic('Makanan', 'makanan Indonesia'),
      EncyclopediaSubtopic('Minuman', 'minuman khas Indonesia'),
      EncyclopediaSubtopic(
        'Jajanan Tradisional',
        'jajanan pasar tradisional Indonesia',
      ),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🗣️',
    name: 'Bahasa Daerah',
    imageAsset: 'assets/menu/bahasa_daerah.jpg',
    subtopics: [
      EncyclopediaSubtopic('Salam', 'salam dalam bahasa daerah Indonesia'),
      EncyclopediaSubtopic('Angka', 'sistem bilangan bahasa daerah'),
      EncyclopediaSubtopic('Percakapan Dasar', 'percakapan bahasa daerah'),
      EncyclopediaSubtopic('Aksara Daerah', 'aksara Nusantara'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '📚',
    name: 'Cerita Rakyat & Legenda',
    imageAsset: 'assets/menu/cerita_rakyat.jpg',
    subtopics: [
      EncyclopediaSubtopic('Dongeng', 'dongeng Indonesia'),
      EncyclopediaSubtopic('Mitos', 'mitos Indonesia'),
      EncyclopediaSubtopic('Legenda', 'legenda Indonesia'),
      EncyclopediaSubtopic('Hikayat', 'hikayat Nusantara'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🎭',
    name: 'Seni Indonesia',
    imageAsset: 'assets/menu/seni.jpg',
    subtopics: [
      EncyclopediaSubtopic('Wayang', 'wayang Indonesia'),
      EncyclopediaSubtopic('Musik Tradisional', 'musik tradisional Indonesia'),
      EncyclopediaSubtopic('Alat Musik', 'alat musik tradisional Indonesia'),
      EncyclopediaSubtopic('Seni Lukis', 'seni lukis Indonesia'),
      EncyclopediaSubtopic('Seni Ukir', 'seni ukir Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '⚖️',
    name: 'Pemerintahan',
    imageAsset: 'assets/menu/pemerintahan.jpg',
    subtopics: [
      EncyclopediaSubtopic('Presiden', 'presiden Indonesia'),
      EncyclopediaSubtopic('Wakil Presiden', 'wakil presiden Indonesia'),
      EncyclopediaSubtopic('Kementerian', 'kementerian Indonesia'),
      EncyclopediaSubtopic('Lambang Negara', 'Garuda Pancasila lambang negara'),
      EncyclopediaSubtopic('Konstitusi', 'Undang-Undang Dasar 1945'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '💰',
    name: 'Ekonomi Indonesia',
    imageAsset: 'assets/menu/ekonomi.jpg',
    subtopics: [
      EncyclopediaSubtopic('Mata Uang', 'rupiah mata uang Indonesia'),
      EncyclopediaSubtopic('Komoditas', 'komoditas ekspor Indonesia'),
      EncyclopediaSubtopic('BUMN', 'badan usaha milik negara Indonesia'),
      EncyclopediaSubtopic(
        'Ekspor-Impor',
        'perdagangan ekspor impor Indonesia',
      ),
    ],
  ),
  EncyclopediaCategory(
    emoji: '📍',
    name: 'Provinsi & Kota',
    imageAsset: 'assets/menu/provinsi_kota.jpg',
    subtopics: [
      EncyclopediaSubtopic('Profil 38 Provinsi', 'provinsi di Indonesia'),
      EncyclopediaSubtopic('Ibu Kota', 'ibu kota provinsi Indonesia'),
      EncyclopediaSubtopic('Lambang', 'lambang provinsi Indonesia'),
      EncyclopediaSubtopic('Jumlah Penduduk', 'demografi Indonesia'),
      EncyclopediaSubtopic('Tempat Wisata', 'tempat wisata di Indonesia'),
    ],
  ),
  EncyclopediaCategory(
    emoji: '🏆',
    name: 'Prestasi Indonesia',
    imageAsset: 'assets/menu/prestasi.jpg',
    subtopics: [
      EncyclopediaSubtopic('Atlet', 'atlet Indonesia'),
      EncyclopediaSubtopic('Olimpiade', 'Indonesia pada Olimpiade'),
      EncyclopediaSubtopic('Sains', 'ilmuwan Indonesia'),
      EncyclopediaSubtopic('Teknologi', 'teknologi Indonesia'),
      EncyclopediaSubtopic('Rekor Dunia', 'rekor dunia Indonesia'),
    ],
  ),
];
