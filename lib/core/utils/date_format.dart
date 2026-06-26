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
  const months = [
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

  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  return '$weekday ${date.day} $month';
}
