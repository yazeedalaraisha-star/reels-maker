// قوالب الشكل الجاهزة: ألوان، خطوط، انتقالات، فلاتر لونية.

class ReelStyle {
  final String id;
  final String name;
  final String captionFont; // اسم عائلة الخط داخل ملف ASS
  final int captionSize;
  final String captionColor; // RRGGBB
  final String highlightColor;
  final String outlineColor;
  final String hookColor;
  final String hookBox; // لون صندوق العنوان
  final List<String> gradient; // ألوان الخلفية المتحركة لو ما في مقاطع
  final List<String> transitions; // انتقالات xfade
  final String grade; // فلتر لوني ffmpeg
  final double captionY; // موضع الكابشن (0 فوق، 1 تحت)
  final String captionAnim; // pop / slide / fade / bounce
  final bool vignette;
  final bool grain;

  const ReelStyle({
    required this.id,
    required this.name,
    this.captionFont = 'Tajawal Black',
    this.captionSize = 84,
    this.captionColor = 'FFFFFF',
    this.highlightColor = 'FFE500',
    this.outlineColor = '000000',
    this.hookColor = 'FFFFFF',
    this.hookBox = 'E11D48',
    this.gradient = const ['1E3A8A', '9333EA', 'DB2777'],
    this.transitions = const ['fade', 'slideleft', 'circleopen', 'smoothleft'],
    this.grade = 'eq=contrast=1.06:saturation=1.15',
    this.captionY = 0.72,
    this.captionAnim = 'pop',
    this.vignette = false,
    this.grain = false,
  });
}

const reelStyles = <ReelStyle>[
  ReelStyle(
    id: 'neon',
    name: 'نيون حماسي',
    highlightColor: '22D3EE',
    hookBox: '7C3AED',
    gradient: ['0F172A', '7C3AED', '22D3EE'],
    transitions: ['slideleft', 'circleopen', 'zoomin', 'smoothleft'],
    grade: 'eq=contrast=1.08:saturation=1.25',
    vignette: true,
  ),
  ReelStyle(
    id: 'news',
    name: 'أخبار عاجلة',
    highlightColor: 'FFD400',
    hookBox: 'DC2626',
    gradient: ['111827', '7F1D1D', 'DC2626'],
    transitions: ['wipeleft', 'slideup', 'fade'],
    grade: 'eq=contrast=1.05:saturation=1.05',
    captionAnim: 'slide',
  ),
  ReelStyle(
    id: 'story',
    name: 'قصص وحكايات',
    captionFont: 'Tajawal ExtraBold',
    highlightColor: 'FBBF24',
    hookBox: '92400E',
    hookColor: 'FFF7ED',
    gradient: ['1C1917', '78350F', 'B45309'],
    transitions: ['fade', 'dissolve', 'fadeblack'],
    grade: 'eq=contrast=1.04:saturation=0.9:gamma=0.98',
    captionAnim: 'fade',
    vignette: true,
    grain: true,
  ),
  ReelStyle(
    id: 'horror',
    name: 'رعب وغموض',
    highlightColor: 'EF4444',
    hookBox: '000000',
    hookColor: 'EF4444',
    gradient: ['000000', '1F0A0A', '450A0A'],
    transitions: ['fadeblack', 'dissolve', 'pixelize'],
    grade: 'eq=contrast=1.15:saturation=0.55:brightness=-0.04',
    captionAnim: 'fade',
    vignette: true,
    grain: true,
  ),
  ReelStyle(
    id: 'clean',
    name: 'هادئ ونظيف',
    captionFont: 'Tajawal ExtraBold',
    captionSize: 76,
    highlightColor: '10B981',
    hookBox: '0F766E',
    gradient: ['F0FDFA', '99F6E4', '14B8A6'],
    transitions: ['fade', 'smoothup', 'dissolve'],
    grade: 'eq=contrast=1.02:saturation=1.05',
    captionAnim: 'slide',
  ),
  ReelStyle(
    id: 'sport',
    name: 'رياضة وطاقة',
    highlightColor: 'A3E635',
    hookBox: '16A34A',
    gradient: ['052E16', '15803D', 'A3E635'],
    transitions: ['zoomin', 'slideright', 'wiperight', 'radial'],
    grade: 'eq=contrast=1.12:saturation=1.3',
    captionAnim: 'bounce',
  ),
  ReelStyle(
    id: 'luxury',
    name: 'فخامة ذهبي',
    captionFont: 'Tajawal ExtraBold',
    highlightColor: 'FACC15',
    hookBox: '000000',
    hookColor: 'FACC15',
    gradient: ['0A0A0A', '3F2D0C', 'A16207'],
    transitions: ['fade', 'smoothleft', 'circleclose'],
    grade: 'eq=contrast=1.06:saturation=0.95',
    vignette: true,
  ),
];

ReelStyle styleById(String id) =>
    reelStyles.firstWhere((s) => s.id == id, orElse: () => reelStyles.first);
