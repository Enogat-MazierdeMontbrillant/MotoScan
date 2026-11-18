import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('motoDetect')
external JSPromise<JSBoolean> _motoDetect(JSString photoBase64, JSString mime);

Future<bool> verifierMoto(Uint8List photo, String mime) async {
  final resultat = await _motoDetect(base64Encode(photo).toJS, mime.toJS).toDart;
  return resultat.toDart;
}
