import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Alert,
  type EventSubscription,
  ActivityIndicator,
} from 'react-native';
import NativeVideoTrim, {
  cleanFiles,
  compress,
  deleteFile,
  extractAudio,
  getFrameAt,
  isValidFile,
  listFiles,
  merge,
  saveToDocuments,
  saveToPhoto,
  share,
  showEditor,
  toGif,
  trim,
  type Spec,
} from 'react-native-video-trim';
import { launchImageLibrary } from 'react-native-image-picker';
import { useEffect, useRef, useState } from 'react';

type SectionProps = { title: string; children: React.ReactNode };

function Section({ title, children }: SectionProps) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

type BtnProps = {
  label: string;
  color: string;
  onPress: () => void;
  loading?: boolean;
};

function Btn({ label, color, onPress, loading }: BtnProps) {
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={loading}
      style={[
        styles.btn,
        { backgroundColor: color, opacity: loading ? 0.6 : 1 },
      ]}
    >
      {loading ? (
        <ActivityIndicator color="#fff" size="small" />
      ) : (
        <Text style={styles.btnText}>{label}</Text>
      )}
    </TouchableOpacity>
  );
}

async function pickVideo(): Promise<string | null> {
  const result = await launchImageLibrary({
    mediaType: 'video',
    assetRepresentationMode: 'current',
  });
  return result.assets?.[0]?.uri ?? null;
}

const AUDIO_URL =
  'https://drive.usercontent.google.com/download?id=1duTfDMYYEjDWsX0InDgw7szUk46erecg&export=download';

export default function App() {
  const listeners = useRef<Record<string, EventSubscription>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [lastOutput, _setLastOutput] = useState<string | null>(null);
  const lastOutputRef = useRef<string | null>(null);
  const setLastOutput = (v: string | null) => {
    lastOutputRef.current = v;
    _setLastOutput(v);
  };

  useEffect(() => {
    listeners.current.onLoad = (NativeVideoTrim as Spec).onLoad(
      ({ duration }) => console.log('onLoad', duration)
    );
    listeners.current.onShow = (NativeVideoTrim as Spec).onShow(() =>
      console.log('onShow')
    );
    listeners.current.onHide = (NativeVideoTrim as Spec).onHide(() =>
      console.log('onHide')
    );
    listeners.current.onCancel = (NativeVideoTrim as Spec).onCancel(() =>
      console.log('onCancel')
    );
    listeners.current.onStartTrimming = (
      NativeVideoTrim as Spec
    ).onStartTrimming(() => console.log('onStartTrimming'));
    listeners.current.onFinishTrimming = (
      NativeVideoTrim as Spec
    ).onFinishTrimming(({ outputPath, startTime, endTime, duration }) => {
      console.log('onFinishTrimming', outputPath, startTime, endTime, duration);
      setLastOutput(outputPath);
    });
    listeners.current.onCancelTrimming = (
      NativeVideoTrim as Spec
    ).onCancelTrimming(() => console.log('onCancelTrimming'));
    listeners.current.onLog = (NativeVideoTrim as Spec).onLog(({ message }) =>
      console.log('onLog', message)
    );
    listeners.current.onStatistics = (NativeVideoTrim as Spec).onStatistics(
      (stats) => console.log('onStatistics', JSON.stringify(stats))
    );
    listeners.current.onError = (NativeVideoTrim as Spec).onError(
      ({ message, errorCode }) => console.log('onError', message, errorCode)
    );

    return () => {
      Object.values(listeners.current).forEach((s) => s?.remove());
      listeners.current = {};
    };
  }, []);

  const run = async (key: string, fn: () => Promise<void>) => {
    setBusy(key);
    try {
      await fn();
    } catch (e: any) {
      Alert.alert('Error', e?.message ?? String(e));
      console.log(11111, e);
    } finally {
      setBusy(null);
    }
  };

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}>
      <Text style={styles.heading}>react-native-video-trim</Text>

      {lastOutput ? (
        <View style={styles.outputBar}>
          <Text style={styles.outputLabel} numberOfLines={1}>
            Last output: {lastOutput}
          </Text>
        </View>
      ) : null}

      {/* ── Editor ── */}
      <Section title="Editor">
        <Btn
          label="Open Video Editor"
          color="#007AFF"
          onPress={async () => {
            const uri = await pickVideo();
            if (!uri) return;
            showEditor(uri, {
              maxDuration: 60000,
              autoplay: true,
              fullScreenModalIOS: true,
              saveToPhoto: true,
              removeAfterSavedToPhoto: true,
            });
          }}
        />
        <Btn
          label="Open Audio Editor"
          color="#5856D6"
          onPress={async () => {
            showEditor(AUDIO_URL, {
              type: 'audio',
              outputExt: 'wav',
              maxDuration: 30000,
              autoplay: true,
              fullScreenModalIOS: true,
            });
          }}
        />
        <Btn
          label="Editor with Speed 2x + Muted"
          color="#34C759"
          onPress={async () => {
            const uri = await pickVideo();
            if (!uri) return;
            showEditor(uri, {
              speed: 2.0,
              removeAudio: true,
              autoplay: true,
              fullScreenModalIOS: true,
            });
          }}
        />
        <Btn
          label="Editor (durationFormat mm:ss)"
          color="#FF9500"
          onPress={async () => {
            const uri = await pickVideo();
            if (!uri) return;
            showEditor(uri, {
              durationFormat: 'mm:ss',
              autoplay: true,
              fullScreenModalIOS: true,
            });
          }}
        />
        <Btn
          label="Editor (durationFormat hh:mm:ss)"
          color="#FF9500"
          onPress={async () => {
            const uri = await pickVideo();
            if (!uri) return;
            showEditor(uri, {
              durationFormat: 'hh:mm:ss',
              autoplay: true,
              fullScreenModalIOS: true,
            });
          }}
        />
      </Section>

      {/* ── Headless Trim ── */}
      <Section title="Headless Trim">
        <Btn
          label="Trim (0-15s)"
          color="#FF9500"
          loading={busy === 'trim'}
          onPress={() =>
            run('trim', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await trim(uri, {
                startTime: 0,
                endTime: 15000,
              });
              setLastOutput(result.outputPath);
              Alert.alert('Trimmed', `Duration: ${result.duration}ms`);
            })
          }
        />
        <Btn
          label="Trim with Speed 0.5x"
          color="#FF9500"
          loading={busy === 'trim-speed'}
          onPress={() =>
            run('trim-speed', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await trim(uri, {
                startTime: 0,
                endTime: 10000,
                speed: 0.5,
              });
              setLastOutput(result.outputPath);
              Alert.alert('Trimmed (0.5x)', `Duration: ${result.duration}ms`);
            })
          }
        />
      </Section>

      {/* ── New Headless APIs ── */}
      <Section title="Frame Extraction">
        <Btn
          label="Extract Frame at 3s"
          color="#AF52DE"
          loading={busy === 'frame'}
          onPress={() =>
            run('frame', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await getFrameAt(uri, {
                time: 3000,
                format: 'jpeg',
                quality: 90,
              });
              setLastOutput(result.outputPath);
              Alert.alert('Frame Extracted', result.outputPath);
            })
          }
        />
      </Section>

      <Section title="Extract Audio">
        <Btn
          label="Extract Audio (M4A)"
          color="#FF2D55"
          loading={busy === 'extract-audio'}
          onPress={() =>
            run('extract-audio', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await extractAudio(uri, { outputExt: 'm4a' });
              setLastOutput(result.outputPath);
              Alert.alert('Audio Extracted', `Duration: ${result.duration}ms`);
            })
          }
        />
      </Section>

      <Section title="Compress">
        <Btn
          label="Compress (Medium)"
          color="#FF3B30"
          loading={busy === 'compress'}
          onPress={() =>
            run('compress', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await compress(uri, {
                quality: 'medium',
              });
              setLastOutput(result.outputPath);
              Alert.alert('Compressed', result.outputPath);
            })
          }
        />
        <Btn
          label="Compress (Low, 480p, No Audio)"
          color="#FF3B30"
          loading={busy === 'compress-custom'}
          onPress={() =>
            run('compress-custom', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await compress(uri, {
                quality: 'low',
                width: 480,
                removeAudio: true,
              });
              setLastOutput(result.outputPath);
              Alert.alert('Compressed (custom)', result.outputPath);
            })
          }
        />
      </Section>

      <Section title="GIF Conversion">
        <Btn
          label="Convert to GIF (0-5s)"
          color="#5AC8FA"
          loading={busy === 'gif'}
          onPress={() =>
            run('gif', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await toGif(uri, {
                startTime: 0,
                endTime: 5000,
                fps: 10,
                width: 320,
              });
              setLastOutput(result.outputPath);
              Alert.alert('GIF Created', result.outputPath);
            })
          }
        />
      </Section>

      <Section title="Merge">
        <Btn
          label="Pick 2 Videos & Merge"
          color="#30B0C7"
          loading={busy === 'merge'}
          onPress={() =>
            run('merge', async () => {
              Alert.alert('Pick First Video', 'Select the first clip');
              const uri1 = await pickVideo();
              if (!uri1) return;
              Alert.alert('Pick Second Video', 'Select the second clip');
              const uri2 = await pickVideo();
              if (!uri2) return;
              const result = await merge([uri1, uri2]);
              setLastOutput(result.outputPath);
              Alert.alert('Merged', `Duration: ${result.duration}ms`);
            })
          }
        />
      </Section>

      {/* ── Utility Functions ── */}
      <Section title="Utility Functions">
        <Btn
          label="Save Last Output to Photo"
          color="#34C759"
          loading={busy === 'save-photo'}
          onPress={() =>
            run('save-photo', async () => {
              const path = lastOutputRef.current;
              if (!path) {
                Alert.alert('No Output', 'Run an operation first');
                return;
              }
              console.log('saveToPhoto:', path);
              const result = await saveToPhoto(path);
              Alert.alert(
                'Save to Photo',
                result.success ? `Saved!\n${path}` : 'Cancelled'
              );
            })
          }
        />
        <Btn
          label="Save Last Output to Documents"
          color="#007AFF"
          loading={busy === 'save-docs'}
          onPress={() =>
            run('save-docs', async () => {
              const path = lastOutputRef.current;
              if (!path) {
                Alert.alert('No Output', 'Run an operation first');
                return;
              }
              console.log('saveToDocuments:', path);
              const result = await saveToDocuments(path);
              Alert.alert(
                'Save to Documents',
                result.success ? `Saved!\n${path}` : 'Cancelled'
              );
            })
          }
        />
        <Btn
          label="Share Last Output"
          color="#5856D6"
          loading={busy === 'share'}
          onPress={() =>
            run('share', async () => {
              const path = lastOutputRef.current;
              if (!path) {
                Alert.alert('No Output', 'Run an operation first');
                return;
              }
              console.log('share:', path);
              const result = await share(path);
              Alert.alert(
                'Share',
                result.success ? `Shared!\n${path}` : 'Cancelled'
              );
            })
          }
        />
      </Section>

      {/* ── File Management ── */}
      <Section title="File Management">
        <Btn
          label="Validate File"
          color="#8E8E93"
          loading={busy === 'validate'}
          onPress={() =>
            run('validate', async () => {
              const uri = await pickVideo();
              if (!uri) return;
              const result = await isValidFile(uri);
              Alert.alert(
                'File Validation',
                `Valid: ${result.isValid}\nType: ${result.fileType}\nDuration: ${result.duration}ms`
              );
            })
          }
        />
        <Btn
          label="List Files"
          color="#8E8E93"
          onPress={async () => {
            const files = await listFiles();
            Alert.alert(
              'Files',
              files.length ? files.join('\n\n') : 'No files'
            );
          }}
        />
        <Btn
          label="Clean All Files"
          color="#FF3B30"
          onPress={async () => {
            const count = await cleanFiles();
            setLastOutput(null);
            Alert.alert('Cleaned', `Deleted ${count} files`);
          }}
        />
        <Btn
          label="Delete Last Output"
          color="#FF9500"
          onPress={async () => {
            const path = lastOutputRef.current;
            if (!path) {
              Alert.alert('No Output', 'Nothing to delete');
              return;
            }
            const ok = await deleteFile(path);
            Alert.alert('Delete', ok ? 'Deleted!' : 'Failed');
            if (ok) setLastOutput(null);
          }}
        />
      </Section>

      <View style={{ height: 60 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  content: {
    padding: 16,
    paddingTop: 60,
  },
  heading: {
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: 12,
    color: '#000',
  },
  outputBar: {
    backgroundColor: '#E8E8ED',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginBottom: 16,
  },
  outputLabel: {
    fontSize: 11,
    color: '#666',
    fontFamily: 'monospace',
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#8E8E93',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
    marginLeft: 4,
  },
  btn: {
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderRadius: 10,
    marginBottom: 8,
    alignItems: 'center',
  },
  btnText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
});
