// Captures App Store réelles de l'app RESERVA (client), en mode invité.
//
// Lancé par le workflow « Captures App Store » sur un simulateur iOS, contre une
// plateforme locale remplie avec les données de démonstration du dépôt.
// Le test affiche chaque écran puis écrit « CAPTURE:<nom> » : le workflow lit cette
// ligne et prend la capture avec `xcrun simctl io <udid> screenshot` (vraie barre d'état iOS).
//
// flutter test integration_test/captures_store_test.dart --flavor client \
//   -d <udid> --dart-define=API_URL=http://127.0.0.1:4000/api

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reserva/app_flavor.dart';
import 'package:reserva/bootstrap.dart';

const _apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:4000/api');

/// Laisse le temps aux appels réseau et aux photos de se charger (frames réelles).
Future<void> attendre(WidgetTester tester, int secondes) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(seconds: secondes)));
  await tester.pump();
}

/// Demande la capture au workflow puis laisse l'écran immobile pendant qu'elle est prise.
Future<void> capturer(WidgetTester tester, String nom) async {
  await attendre(tester, 2);
  // ignore: avoid_print
  print('CAPTURE:$nom');
  await attendre(tester, 6);
}

void aller(WidgetTester tester, String route, {Object? extra}) {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(route, extra: extra);
}

Future<dynamic> getJson(String chemin) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('$_apiUrl$chemin'));
    final res = await req.close();
    final corps = await res.transform(utf8.decoder).join();
    return (jsonDecode(corps) as Map<String, dynamic>)['donnees'];
  } finally {
    client.close();
  }
}

Future<void> toucherTexte(WidgetTester tester, Pattern texte) async {
  final cible = find.textContaining(texte).first;
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('captures App Store (mode invité)', (tester) async {
    await demarrerApp(roleForce: AppFlavor.client);
    await attendre(tester, 6); // splash → bienvenue

    // Comme un visiteur qui touche « Découvrir sans compte »
    aller(tester, '/accueil');
    await attendre(tester, 8);
    await capturer(tester, '01-accueil');

    aller(tester, '/services');
    await attendre(tester, 8);
    await capturer(tester, '02-services');

    // Fiche d'un prestataire de santé de la démo
    final services = await getJson('/services?limit=50');
    final items = (services is Map ? services['items'] : services) as List<dynamic>;
    final sante = items.cast<Map<String, dynamic>>().firstWhere(
          (s) => '${s['prestataire']?['nomEntreprise']}'.contains('Clinique'),
          orElse: () => items.first as Map<String, dynamic>,
        );
    aller(tester, '/service/${sante['id']}');
    await attendre(tester, 8);
    await capturer(tester, '03-service-detail');

    aller(tester, '/hotels');
    await attendre(tester, 10);
    await capturer(tester, '04-hotels');

    await toucherTexte(tester, 'Fleuve Congo');
    await attendre(tester, 10);
    await capturer(tester, '05-hotel-detail');

    aller(tester, '/transport');
    await attendre(tester, 10);
    await capturer(tester, '06-transport');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
