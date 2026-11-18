import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoscan/main.dart';

void main() {
  testWidgets('Sur un petit écran, pas de scan sans photo et champs accessibles', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MotoScan());
    await tester.scrollUntilVisible(
      find.text('Voir les caractéristiques'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final scan = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Identifier la moto'),
    );
    expect(scan.onPressed, isNull);
    final recherche = find.text('Voir les caractéristiques');
    await tester.ensureVisible(recherche);
    await tester.tap(recherche);
    await tester.pumpAndSettle();
    expect(find.text('Renseigne la marque et le modèle.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Une année invalide est signalée avant un appel API', (tester) async {
    await tester.pumpWidget(const MotoScan());
    await tester.scrollUntilVisible(
      find.text('Voir les caractéristiques'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).at(0), 'Yamaha');
    await tester.enterText(find.byType(TextField).at(1), 'MT-07');
    await tester.enterText(find.byType(TextField).at(2), 'abc');
    final recherche = find.text('Voir les caractéristiques');
    await tester.ensureVisible(recherche);
    await tester.tap(recherche);
    await tester.pumpAndSettle();
    expect(find.text('Saisis une année sur 4 chiffres, ou laisse-la vide.'), findsOneWidget);
  });

  testWidgets('Sans clé la recherche explique la configuration puis se débloque', (tester) async {
    await tester.pumpWidget(const MotoScan());
    await tester.scrollUntilVisible(
      find.text('Voir les caractéristiques'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).at(0), 'Yamaha');
    await tester.enterText(find.byType(TextField).at(1), 'MT-07');
    final recherche = find.text('Voir les caractéristiques');
    await tester.ensureVisible(recherche);
    await tester.tap(recherche);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ajoute la clé API Ninjas'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Voir les caractéristiques'))
          .onPressed,
      isNotNull,
    );
  });
}
