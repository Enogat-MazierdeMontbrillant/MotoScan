(() => {
  const imageSize = 640;
  const motorcycleClass = 3;
  const firstClassScore = 4;
  const confidenceThreshold = 0.25;
  const modelUrl =
    'https://cdn.jsdelivr.net/gh/enesagu/Object_detection_fastAPI_docker@9aaca6063fca31719143e882b81ca3a04cacd252/Object_Detection_Yolo_with_FastAPI/yolov8n.onnx';
  const runtimeBase =
    'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/';
  let sessionPromise;

  function getSession() {
    if (!sessionPromise) {
      if (!globalThis.ort) {
        throw new Error('Le moteur de détection est indisponible. Recharge la page.');
      }
      globalThis.ort.env.wasm.wasmPaths = runtimeBase;
      globalThis.ort.env.wasm.numThreads = 1;
      sessionPromise = globalThis.ort.InferenceSession.create(modelUrl, {
        executionProviders: ['wasm'],
      }).catch((error) => {
        sessionPromise = undefined;
        throw new Error(`Impossible de télécharger le modèle moto : ${error.message}`);
      });
    }
    return sessionPromise;
  }

  async function imageTensor(photoBase64, mime) {
    const binary = atob(photoBase64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const bitmap = await createImageBitmap(new Blob([bytes], { type: mime }));
    try {
      const scale = Math.min(imageSize / bitmap.width, imageSize / bitmap.height);
      const width = Math.round(bitmap.width * scale);
      const height = Math.round(bitmap.height * scale);
      const left = Math.floor((imageSize - width) / 2);
      const top = Math.floor((imageSize - height) / 2);
      const canvas = document.createElement('canvas');
      canvas.width = imageSize;
      canvas.height = imageSize;
      const context = canvas.getContext('2d', { willReadFrequently: true });
      if (!context) throw new Error('Impossible de préparer cette image.');
      context.fillStyle = 'rgb(114, 114, 114)';
      context.fillRect(0, 0, imageSize, imageSize);
      context.drawImage(bitmap, left, top, width, height);
      const pixels = context.getImageData(0, 0, imageSize, imageSize).data;
      const planeSize = imageSize * imageSize;
      const values = new Float32Array(3 * planeSize);
      for (let i = 0; i < planeSize; i++) {
        values[i] = pixels[i * 4] / 255;
        values[planeSize + i] = pixels[i * 4 + 1] / 255;
        values[2 * planeSize + i] = pixels[i * 4 + 2] / 255;
      }
      return new globalThis.ort.Tensor('float32', values, [1, 3, imageSize, imageSize]);
    } finally {
      bitmap.close();
    }
  }

  globalThis.motoDetect = async (photoBase64, mime) => {
    const session = await getSession();
    const input = await imageTensor(photoBase64, mime);
    const outputs = await session.run({ [session.inputNames[0]]: input });
    const output = outputs[session.outputNames[0]];
    if (output.dims.length !== 3 || output.dims[1] <= firstClassScore + motorcycleClass) {
      throw new Error('Le modèle de détection a renvoyé un résultat inattendu.');
    }
    const classScores = output.data;
    const candidates = output.dims[2];
    for (let i = 0; i < candidates; i++) {
      if (classScores[(firstClassScore + motorcycleClass) * candidates + i] >= confidenceThreshold) {
        return true;
      }
    }
    return false;
  };
})();
