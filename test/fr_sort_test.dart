import 'package:flutter_test/flutter_test.dart';

import 'package:eclose/core/utils/fr_sort.dart';

void main() {
  test('foldFr strips accents and lowercases', () {
    expect(foldFr('Échalote'), 'echalote');
    expect(foldFr('Épinard'), 'epinard');
    expect(foldFr('Cœur'), 'coeur');
  });

  test('compareFr sorts É with E', () {
    final names = ['Épinard', 'Carotte', 'Échalote', 'Basilic', 'Ail'];
    names.sort(compareFr);
    expect(names, ['Ail', 'Basilic', 'Carotte', 'Échalote', 'Épinard']);
  });
}
