import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'moto_api.dart';

void main() => runApp(const MotoScan());

class MotoScan extends StatelessWidget {
  const MotoScan({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MotoScan',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: const Accueil(),
  );
}

class Accueil extends StatefulWidget {
  const Accueil({super.key});
  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  final client = http.Client();
  final marque = TextEditingController();
  final modele = TextEditingController();
  final annee = TextEditingController();
  Uint8List? photo;
  String mime = 'image/jpeg';
  String message = '';
  bool chargement = false;
  List<dynamic> motos = [];

  @override
  void dispose() {
    client.close();
    marque.dispose();
    modele.dispose();
    annee.dispose();
    super.dispose();
  }

  void afficherErreur(Object e) {
    if (!mounted) return;
    String texte = e.toString().replaceFirst('Exception: ', '');
    if (e is TimeoutException || e is http.ClientException) {
      texte = 'Connexion impossible ou trop lente. Vérifie Internet et réessaie.';
    } else if (e is FormatException) {
      texte = 'Réponse illisible du service. Réessaie.';
    } else if (e is PlatformException) {
      texte = 'Vérifie les autorisations caméra et photos dans les réglages.';
    }
    setState(() => message = texte);
  }

  // Une photo est acceptée seulement après la détection d'une moto.
  Future<void> choisirPhoto(ImageSource source) async {
    setState(() {
      chargement = true;
      message = '';
    });
    try {
      final fichier = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (fichier == null) return;
      photo = null;
      marque.clear();
      modele.clear();
      annee.clear();
      motos = [];
      if (mounted) setState(() {});
      final limiteMo = kIsWeb ? 4 : 5;
      if (await fichier.length() > limiteMo * 1024 * 1024) {
        throw Exception('Choisis une photo de moins de $limiteMo Mo.');
      }
      final octets = await fichier.readAsBytes();
      final type = lookupMimeType(fichier.name, headerBytes: octets);
      if (type == null || !['image/jpeg', 'image/png', 'image/webp'].contains(type)) {
        throw Exception('Choisis une image JPG, PNG ou WebP.');
      }
      if (mounted) {
        setState(() => message = 'Vérification que l’image contient une moto…');
      }
      if (!await MotoApi(client).verifierMoto(octets, type)) {
        throw Exception('Aucune moto détectée. Choisis une image montrant clairement une moto.');
      }
      if (!mounted) return;
      photo = octets;
      mime = type;
      marque.clear();
      modele.clear();
      annee.clear();
      motos = [];
      message = 'Moto détectée. Tu peux lancer son identification.';
    } catch (e) {
      afficherErreur(e);
    } finally {
      if (mounted) setState(() => chargement = false);
    }
  }

  Future<void> identifier() async {
    if (photo == null) return;
    setState(() => chargement = true);
    message = '';
    motos = [];
    try {
      final resultat = await MotoApi(client).identifier(photo!, mime);
      if (!mounted) return;
      marque.text = resultat['marque'];
      modele.text = resultat['modele'];
      annee.clear();
    } catch (e) {
      afficherErreur(e);
    } finally {
      if (mounted) setState(() => chargement = false);
    }
  }

  // L'année reste un choix de l'utilisateur, jamais une certitude de l'IA.
  Future<void> chercher() async {
    FocusScope.of(context).unfocus();
    if (marque.text.trim().isEmpty || modele.text.trim().isEmpty) {
      afficherErreur(Exception('Renseigne la marque et le modèle.'));
      return;
    }
    if (annee.text.trim().isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(annee.text.trim())) {
      afficherErreur(Exception('Saisis une année sur 4 chiffres, ou laisse-la vide.'));
      return;
    }
    setState(() => chargement = true);
    message = '';
    motos = [];
    try {
      final resultats = await MotoApi(client).chercher(marque.text, modele.text, annee.text);
      if (!mounted) return;
      motos = resultats;
      if (motos.isEmpty) message = 'Aucune fiche trouvée. Essaie sans année.';
    } catch (e) {
      afficherErreur(e);
    } finally {
      if (mounted) setState(() => chargement = false);
    }
  }

  Widget champ(TextEditingController controleur, String titre) => TextField(
    controller: controleur,
    enabled: !chargement,
    keyboardType: controleur == annee ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: titre),
  );

  @override
  Widget build(BuildContext context) {
    const champs = {
      'type': 'Catégorie',
      'displacement': 'Cylindrée',
      'engine': 'Moteur',
      'power': 'Puissance',
      'torque': 'Couple',
      'gearbox': 'Boîte de vitesses',
      'total_weight': 'Poids',
      'seat_height': 'Hauteur de selle',
      'fuel_capacity': 'Réservoir',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('MotoScan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (photo == null)
              const Icon(Icons.two_wheeler, size: 100, color: Colors.teal)
            else
              Image.memory(
                photo!,
                height: 130,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('Image illisible. Choisis une autre photo.'),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: chargement ? null : () => choisirPhoto(ImageSource.camera),
                  child: const Text('Caméra'),
                ),
                TextButton(
                  onPressed: chargement ? null : () => choisirPhoto(ImageSource.gallery),
                  child: const Text('Galerie'),
                ),
              ],
            ),
            FilledButton(
              onPressed: chargement || photo == null ? null : identifier,
              child: const Text('Identifier la moto'),
            ),
            Text(
              kIsWeb
                  ? 'Vérification dans le navigateur ; l’identification envoie la photo à Gemini.'
                  : 'La photo est vérifiée par le détecteur, puis envoyée à Gemini pour identification.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Modèle probable : corrige-le si besoin.\nLa recherche sans photo est possible.',
            ),
            champ(marque, 'Marque'),
            champ(modele, 'Modèle'),
            champ(annee, 'Année (facultatif)'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: chargement ? null : chercher,
              child: const Text('Voir les caractéristiques'),
            ),
            if (chargement) const LinearProgressIndicator(),
            if (message.isNotEmpty) Semantics(liveRegion: true, child: Text(message)),
            for (final moto in motos)
              ExpansionTile(
                title: Text('${moto['make']} ${moto['model']}'),
                subtitle: Text('Année : ${moto['year'] ?? 'non renseignée'}'),
                children: [
                  for (final champ in champs.entries)
                    ListTile(
                      dense: true,
                      title: Text(champ.value),
                      subtitle: Text(
                        '${moto[champ.key] ?? ''}'.trim().isEmpty
                            ? 'Non renseigné'
                            : '${moto[champ.key]}',
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'Données : API Ninjas • api-ninjas.com\n'
              'Vérifie la version et les caractéristiques auprès du constructeur.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
