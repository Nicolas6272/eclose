const frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String formatFrenchDate(DateTime date) {
  const weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  final weekday = weekdays[date.weekday - 1];
  final month = frenchMonths[date.month - 1];
  return '$weekday ${date.day} $month';
}

String formatFrenchMonthYear(DateTime date) {
  final month = frenchMonths[date.month - 1];
  return '${month[0].toUpperCase()}${month.substring(1)} ${date.year}';
}

/// Mid-month approximate date when the user only remembers the month.
DateTime approximateMidMonth(int year, int month) {
  return DateTime(year, month, 15);
}
