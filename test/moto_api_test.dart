import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motoscan/moto_api.dart';

void main() {
  final photo = Uint8List.fromList([1, 2, 3]);

  http.Response reponseGemini(String texte) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': texte},
            ],
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('Le détecteur reçoit l’image et confirme la classe moto', () async {
    final client = MockClient.streaming((requete, corps) async {
      expect(requete.method, 'POST');
      expect(requete.url, Uri.parse('http://localhost:8000/detect/'));
      expect(requete.headers['content-type'], startsWith('multipart/form-data; boundary='));
      final corpsOctets = await corps.toBytes();
      expect(corpsOctets, containsAllInOrder([1, 2, 3]));
      final corpsTexte = latin1.decode(corpsOctets);
      expect(corpsTexte, contains('name="label"\r\n\r\nmotorcycle'));
      expect(corpsTexte, contains('name="image"; filename="photo.png"'));
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'objects': [
                {'label': 'motorcycle', 'confidence': 0.92},
              ],
            }),
          ),
        ),
        200,
      );
    });
    addTearDown(client.close);
    final api = MotoApi(client, detectionUrl: 'http://localhost:8000');
    expect(await api.verifierMoto(photo, 'image/png'), isTrue);
  });

  test('Une image sans détection de moto est refusée', () async {
    final client = MockClient((_) async => http.Response('{"objects":[]}', 200));
    addTearDown(client.close);
    final api = MotoApi(client, detectionUrl: 'http://localhost:8000');
    expect(await api.verifierMoto(photo, 'image/jpeg'), isFalse);
  });

  test('Gemini reçoit la photo et lit les parties de réponse sans les pensées', () async {
    final client = MockClient((requete) async {
      expect(requete.method, 'POST');
      expect(requete.url.host, 'generativelanguage.googleapis.com');
      expect(requete.headers['x-goog-api-key'], 'test-gemini');
      final corps = jsonDecode(requete.body);
      final image = corps['contents'][0]['parts'][1]['inlineData'];
      expect(image['mimeType'], 'image/png');
      expect(base64Decode(image['data']), photo);
      expect(corps['generationConfig']['responseMimeType'], 'application/json');
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'parts': [
                  {'thought': true, 'text': 'Texte à ignorer'},
                  {'text': '{"marque":"Yamaha",'},
                  {'text': '"modele":"MT-07"}'},
                ],
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    final api = MotoApi(client, geminiKey: 'test-gemini');
    expect(await api.identifier(photo, 'image/png'), {'marque': 'Yamaha', 'modele': 'MT-07'});
  });

  test('Une photo bloquée ne donne pas de modèle inventé', () async {
    final client = MockClient(
      (_) async => http.Response('{"promptFeedback":{"blockReason":"SAFETY"}}', 200),
    );
    addTearDown(client.close);
    final api = MotoApi(client, geminiKey: 'test');
    await expectLater(
      api.identifier(photo, 'image/jpeg'),
      throwsA(predicate((e) => e.toString().contains('Photo non reconnue'))),
    );
  });

  test('Une identification vide est refusée', () async {
    final client = MockClient((_) async => reponseGemini('{"marque":"  ","modele":""}'));
    addTearDown(client.close);
    await expectLater(
      MotoApi(client, geminiKey: 'test').identifier(photo, 'image/jpeg'),
      throwsA(predicate((e) => e.toString().contains('Modèle incertain'))),
    );
  });

  test('Une réponse IA qui ne contient pas du JSON est refusée', () async {
    final client = MockClient((_) async => reponseGemini('Je ne sais pas'));
    addTearDown(client.close);
    await expectLater(
      MotoApi(client, geminiKey: 'test').identifier(photo, 'image/jpeg'),
      throwsFormatException,
    );
  });

  test('Ninjas encode les noms, conserve les versions et accepte un champ absent', () async {
    final client = MockClient((requete) async {
      expect(requete.method, 'GET');
      expect(requete.url.host, 'api.api-ninjas.com');
      expect(requete.headers['X-Api-Key'], 'test-ninjas');
      expect(requete.url.queryParameters, {'make': 'Royal Enfield', 'model': 'Classic & Special'});
      return http.Response('[{"year":"2021","power":"20 HP"},{"year":"2022"}]', 200);
    });
    addTearDown(client.close);
    final motos = await MotoApi(
      client,
      ninjasKey: 'test-ninjas',
    ).chercher(' Royal Enfield ', ' Classic & Special ', ' ');
    expect(motos, hasLength(2));
    expect(motos[0]['year'], '2021');
    expect(motos[1]['year'], '2022');
    expect(motos[1]['power'], isNull);
  });

  test('Ninjas envoie une année saisie et peut ne trouver aucune fiche', () async {
    final client = MockClient((requete) async {
      expect(requete.url.queryParameters['year'], '2022');
      return http.Response('[]', 200);
    });
    addTearDown(client.close);
    expect(await MotoApi(client, ninjasKey: 'test').chercher('Yamaha', 'MT-07', ' 2022 '), isEmpty);
  });

  for (final code in [429, 403, 500]) {
    test('L’erreur HTTP $code produit un message compréhensible', () async {
      final client = MockClient((_) async => http.Response('erreur serveur', code));
      addTearDown(client.close);
      final texte = code == 429
          ? 'quota atteint'
          : code == 403
          ? 'ta clé'
          : '(500)';
      await expectLater(
        MotoApi(client, ninjasKey: 'test').chercher('Yamaha', 'MT-07', ''),
        throwsA(predicate((e) => e.toString().contains(texte))),
      );
    });
  }

  test('Une réponse Ninjas mal formée est refusée', () async {
    final client = MockClient((_) async => http.Response('{"error":"inattendu"}', 200));
    addTearDown(client.close);
    await expectLater(
      MotoApi(client, ninjasKey: 'test').chercher('Yamaha', 'MT-07', ''),
      throwsFormatException,
    );
  });

  test('Sans clés, aucun appel réseau ne part', () async {
    var appels = 0;
    final client = MockClient((_) async {
      appels++;
      return http.Response('[]', 200);
    });
    addTearDown(client.close);
    final api = MotoApi(client, geminiKey: '', ninjasKey: '');
    await expectLater(api.identifier(photo, 'image/jpeg'), throwsException);
    await expectLater(api.chercher('Yamaha', 'MT-07', ''), throwsException);
    expect(appels, 0);
  });
}
