// Captures App Store réelles de l'app RESERVA (client), en mode invité.
//
// Lancé par le workflow « Captures App Store » sur un simulateur iOS, contre une
// plateforme locale remplie avec les données de démonstration du dépôt.
// Le test affiche chaque écran puis appelle le petit serveur du workflow
// (integration_test/serveur_captures.py, port 8765) qui prend la capture avec
// `xcrun simctl io <udid> screenshot` (vraie barre d'état iOS) avant de répondre.
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

/// Demande la capture au serveur du workflow ; il ne répond qu'une fois l'image écrite.
Future<void> capturer(WidgetTester tester, String nom) async {
  await attendre(tester, 2);
  await tester.runAsync(() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8765/capture?nom=$nom'));
      final res = await req.close();
      await res.drain<void>();
      // ignore: avoid_print
      print('capture $nom → HTTP ${res.statusCode}');
    } finally {
      client.close();
    }
  });
  await tester.pump();
}

/// Navigue avec le GoRouter de l'app (contexte = Navigator créé par le routeur).
Future<void> aller(WidgetTester tester, String route, {Object? extra}) async {
  for (var i = 0; i < 30 && find.byType(Navigator).evaluate().isEmpty; i++) {
    await attendre(tester, 1);
  }
  final navigateurs = find.byType(Navigator).evaluate().toList();
  if (navigateurs.isEmpty) {
    throw StateError('Aucun Navigator : l\'app ne s\'est pas affichée');
  }
  GoRouter.of(navigateurs.last).go(route, extra: extra);
}

Future<dynamic> getJson(WidgetTester tester, String chemin) async {
  return tester.runAsync(() => _getJson(chemin));
}

Future<dynamic> _getJson(String chemin) async {
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
    await capturer(tester, '00-demarrage'); // diagnostic, non publiée

    // Comme un visiteur qui touche « Découvrir sans compte »
    await aller(tester, '/accueil');
    await attendre(tester, 8);
    await capturer(tester, '01-accueil');

    await aller(tester, '/services');
    await attendre(tester, 8);
    await capturer(tester, '02-services');

    // Fiche d'un prestataire de santé de la démo
    final services = await getJson(tester, '/services?limit=50');
    final items = (services is Map ? services['items'] : services) as List<dynamic>;
    final sante = items.cast<Map<String, dynamic>>().firstWhere(
          (s) => '${s['prestataire']?['nomEntreprise']}'.contains('Clinique'),
          orElse: () => items.first as Map<String, dynamic>,
        );
    await aller(tester, '/service/${sante['id']}');
    await attendre(tester, 8);
    await capturer(tester, '03-service-detail');

    await aller(tester, '/hotels');
    await attendre(tester, 10);
    await capturer(tester, '04-hotels');

    await toucherTexte(tester, 'Fleuve Congo');
    await attendre(tester, 10);
    await capturer(tester, '05-hotel-detail');

    await aller(tester, '/transport');
    await attendre(tester, 10);
    await capturer(tester, '06-transport');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
