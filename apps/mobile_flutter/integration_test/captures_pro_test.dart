// Captures App Store réelles de RESERVA Pro, connecté avec le prestataire de démo
// « Clinique Bonne Santé » (+243970000001, PIN de démo 1234 — base locale du workflow).
// Même mécanisme que captures_store_test.dart (serveur_captures.py sur le port 8765).
//
// flutter test integration_test/captures_pro_test.dart --flavor pro \
//   -d <udid> --dart-define=API_URL=http://127.0.0.1:4000/api

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:reserva/app_flavor.dart';
import 'package:reserva/bootstrap.dart';
import 'package:reserva/models/models.dart';
import 'package:reserva/providers/auth_provider.dart';
import 'package:reserva/services/api_auth.dart';

Future<void> attendre(WidgetTester tester, int secondes) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(seconds: secondes)));
  await tester.pump();
}

Future<void> appelerServeur(WidgetTester tester, String chemin) async {
  await tester.runAsync(() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8765$chemin'));
      final res = await req.close();
      await res.drain<void>();
      // ignore: avoid_print
      print('serveur $chemin → HTTP ${res.statusCode}');
    } finally {
      client.close();
    }
  });
}

Future<void> capturer(WidgetTester tester, String nom) async {
  await attendre(tester, 2);
  await appelerServeur(tester, '/capture?nom=$nom');
  await tester.pump();
}

Future<BuildContext> contexteRouteur(WidgetTester tester) async {
  for (var i = 0; i < 30 && find.byType(Navigator).evaluate().isEmpty; i++) {
    await attendre(tester, 1);
  }
  return find.byType(Navigator).evaluate().last;
}

Future<void> aller(WidgetTester tester, String route) async {
  GoRouter.of(await contexteRouteur(tester)).go(route);
}

Future<void> toucherOnglet(WidgetTester tester, String libelle) async {
  final cible = find.text(libelle).first;
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('captures App Store RESERVA Pro', (tester) async {
    await demarrerApp(roleForce: AppFlavor.prestataire);
    await attendre(tester, 6);
    await capturer(tester, '00-demarrage'); // diagnostic, non publiée

    // Connexion PIN du prestataire de démo (comme l'écran « Connexion PIN »)
    final data = await tester.runAsync(() => ApiAuth.connecter('+243970000001', '1234'));
    final contexte = await contexteRouteur(tester);
    final auth = Provider.of<AuthProvider>(contexte, listen: false);
    await tester.runAsync(() => auth.connecterStore(
          data!['token'] as String,
          Utilisateur.fromJson(data['utilisateur'] as Map<String, dynamic>),
        ));
    await aller(tester, '/accueil');
    await attendre(tester, 10);
    await capturer(tester, '01-espace');

    await toucherOnglet(tester, 'Réservations');
    await attendre(tester, 6);
    await capturer(tester, '02-reservations');

    await toucherOnglet(tester, 'Services');
    await attendre(tester, 6);
    await capturer(tester, '03-services');

    await toucherOnglet(tester, 'Avis');
    await attendre(tester, 6);
    await capturer(tester, '04-avis');

    await aller(tester, '/prestataire/calendrier');
    await attendre(tester, 8);
    await capturer(tester, '05-calendrier');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
