# Local Agent Voice Activation

Use this runbook when a dedicated local agent host needs microphone activation
for spoken requests. Keep wake detection, transcription, command routing, and
action execution as separate stages so each stage can be validated, logged, and
disabled independently.

## Recommended Architecture

Preferred v0 pipeline:

```text
USB or onboard microphone
  -> 16 kHz mono PCM capture
  -> dedicated wake-word detector
  -> short post-wake utterance capture with VAD or silence stop
  -> Whisper or equivalent STT for the post-wake clip only
  -> command parser and policy checks
  -> confirmation prompt for risky or external actions
  -> action execution
  -> spoken or visible completion summary
```

Do not use Whisper as an always-on wake gate. It can transcribe clearly after a
wake event, but it is too heavy for continuous activation and can miss or
truncate short wake phrases at chunk boundaries. Keep Whisper or equivalent STT
behind the wake detector.

## Runtime Deployment

Runtime hosts should stay small and observable:

- capture microphone input as 16 kHz mono PCM;
- use a purpose-built wake-word runtime for continuous activation;
- prefer local ONNX wake models when practical because the runtime dependency
  surface is smaller and the model file is easy to deploy;
- start post-wake recording only after a wake event;
- stop post-wake recording on VAD, silence timeout, or a conservative maximum
  duration;
- send only the post-wake clip to Whisper or another STT engine;
- keep command execution behind explicit command routing and policy checks;
- ask for confirmation before destructive, financial, outbound-message,
  credential, or broad automation actions;
- keep listeners foreground-only until wake detection, post-wake capture,
  logging, error handling, and a kill switch are validated.

Recommended local runtime layout:

```text
/opt/agent-voice/
  models/
    wake-word.onnx
  logs/
  recordings/
  config/
```

Treat the paths above as examples. Record the real service names, device names,
model paths, and log paths in host-local durable notes, not in shared guidance.

## Training And Export

Separate model training from runtime deployment. Small ARM hosts can run a
foreground smoke test, but heavy custom wake-word training should happen on a
larger workstation, GPU host, or cloud runner unless the small host has been
explicitly validated for the chosen training stack and dataset size.

Recommended custom phrase flow:

1. Choose a short phrase such as `Hey Agent`.
2. Generate or collect positive examples and representative background speech
   or noise.
3. Train and evaluate the wake model away from the runtime host when practical.
4. Export the deployable model as ONNX.
5. Copy only the exported model and runtime config to the agent host.
6. Validate false-positive and false-negative behavior in foreground mode before
   adding any service or autostart.

Keep training datasets, generated speech, checkpoints, and large intermediate
artifacts out of shared durable notes. Store only reusable process notes and
host-local artifact metadata.

## Dependency Caveats

On Raspberry Pi ARM64, `tflite-runtime==2.14.0` was validated with
`numpy==1.26.4`; NumPy 2.x caused TensorFlow Lite import/runtime failures. When
using openWakeWord or another TFLite-backed runtime on ARM64, pin NumPy below
2 until that specific runtime stack is validated with NumPy 2.x.

Example runtime pin:

```text
numpy==1.26.4
tflite-runtime==2.14.0
openwakeword==0.6.0
```

For ONNX wake-word runtimes, keep ONNX Runtime and NumPy pinned in the runtime
requirements file and rebuild the environment from scratch during validation.
Do not mix training-only packages such as PyTorch into the always-on runtime
environment unless the runtime actually needs them.

## Foreground Validation

Validate in foreground mode before creating a systemd service. The validation
should prove the model and audio pipeline without requiring command execution.

A no-microphone smoke test can verify dependency imports, model loading, and
offline scoring against a WAV file:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements-runtime.txt
python - <<'PY'
import importlib

for name in ("numpy", "onnxruntime"):
    module = importlib.import_module(name)
    print(f"{name} {module.__version__}")
PY
python validate_wake_model.py \
  --model models/wake-word.onnx \
  --wav fixtures/hey-agent-16khz-mono.wav
```

If no fixture exists, create a silent 16 kHz mono WAV to prove file handling and
negative-path scoring. This does not prove wake quality, but it should not fire:

```bash
mkdir -p fixtures
python - <<'PY'
import wave

sample_rate = 16000
seconds = 3
with wave.open("fixtures/silence-16khz-mono.wav", "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sample_rate)
    wav.writeframes(b"\x00\x00" * sample_rate * seconds)
PY
python validate_wake_model.py \
  --model models/wake-word.onnx \
  --wav fixtures/silence-16khz-mono.wav \
  --expect-no-wake
```

When microphone hardware is available, validate the live path without actions:

```bash
python listen_foreground.py \
  --model models/wake-word.onnx \
  --sample-rate 16000 \
  --channels 1 \
  --print-scores \
  --no-actions
```

Then validate the wake-to-STT path with one request and no command execution:

```bash
python wake_to_stt_once.py \
  --model models/wake-word.onnx \
  --max-capture-seconds 10 \
  --silence-stop-seconds 1.5 \
  --transcribe-only
```

Expected result: the detector fires on the phrase, records a short utterance,
the STT transcript is intelligible, logs name the model and audio settings, and
the process exits cleanly.

## Service Readiness Checklist

Do not install or enable an always-on service until all of these are true:

- foreground wake detection works with useful score separation;
- false positives are acceptable during quiet-room and normal-room tests;
- post-wake capture stops on silence or a maximum duration;
- Whisper or equivalent STT is invoked only after wake activation;
- logs include model path, threshold, sample rate, wake score, transcript state,
  and exit reason without storing sensitive spoken content by default;
- there is a documented kill switch, such as stopping a service and placing a
  local disabled marker;
- external or risky actions require confirmation;
- host-local durable notes record the real service name, config path, model
  path, log path, credential boundaries, and recovery steps.

## Scenario Review

For a USB microphone on a small Linux agent host with a custom `Hey Agent`
phrase, the expected implementation is:

- ONNX wake detector runs locally in foreground during validation;
- microphone capture is 16 kHz mono;
- a successful wake starts short post-wake recording;
- VAD or silence detection stops the recording;
- Whisper transcribes only the post-wake clip;
- command routing asks for confirmation before high-impact actions;
- no service or autostart is added until logging, kill switch, and false-positive
  behavior are reviewed.
