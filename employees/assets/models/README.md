# Face embedding model

The app needs a **MobileFaceNet** model to turn a captured face into a numeric
embedding. Place the model file here:

```
assets/models/mobilefacenet.tflite
```

## Expected model contract

- Input: `1 x 112 x 112 x 3` float32, pixel values normalized to `[-1, 1]`
  (i.e. `(pixel - 127.5) / 127.5`).
- Output: `1 x 192` float32 embedding.

`FaceEmbedder` (lib/services/face_embedder.dart) is written against this
contract. If your model outputs a different embedding size (e.g. 128 or 512),
it still works — the code reads the output length from the model at load time.

## Where to get the model

MobileFaceNet `.tflite` files are widely available from open Flutter face
recognition samples, for example:

- https://github.com/AvishakeAdhikary/FaceRecognitionFlutter
  (`assets/mobilefacenet.tflite`)
- https://github.com/mddanish-dev/Face-Recognition-Flutter

Download `mobilefacenet.tflite` from one of those repositories and copy it to
`assets/models/mobilefacenet.tflite`, then run `flutter pub get` and rebuild.

## Important

Until this file is present, the app cannot generate real embeddings. The
registration and check-in screens will show a clear "face model not available"
error instead of silently registering a fake face.
