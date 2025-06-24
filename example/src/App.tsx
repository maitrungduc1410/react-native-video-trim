import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  Modal,
  type EventSubscription,
} from 'react-native';
import {
  cleanFiles,
  deleteFile,
  listFiles,
  showEditor,
  isValidFile,
  // closeEditor,
  trim,
} from 'react-native-video-trim';
import {
  launchImageLibrary,
  type ImagePickerResponse,
} from 'react-native-image-picker';
import { useEffect, useRef, useState } from 'react';
import NativeVideoTrim from '../../src/NativeVideoTrim';

export default function App() {
  const [modalVisible, setModalVisible] = useState(false);
  const [isTrimming, setIsTrimming] = useState(false);
  const listenerSubscription = useRef<Record<string, EventSubscription>>({});

  useEffect(() => {
    listenerSubscription.current.onLoad = NativeVideoTrim.onLoad(
      ({ duration }) => console.log('onLoad', duration)
    );

    listenerSubscription.current.onStartTrimming =
      NativeVideoTrim.onStartTrimming(() => console.log('onStartTrimming'));

    listenerSubscription.current.onCancelTrimming =
      NativeVideoTrim.onCancelTrimming(() => console.log('onCancelTrimming'));
    listenerSubscription.current.onCancel = NativeVideoTrim.onCancel(() =>
      console.log('onCancel')
    );
    listenerSubscription.current.onHide = NativeVideoTrim.onHide(() =>
      console.log('onHide')
    );
    listenerSubscription.current.onShow = NativeVideoTrim.onShow(() =>
      console.log('onShow')
    );
    listenerSubscription.current.onFinishTrimming =
      NativeVideoTrim.onFinishTrimming(
        ({ outputPath, startTime, endTime, duration }) =>
          console.log(
            'onFinishTrimming',
            `outputPath: ${outputPath}, startTime: ${startTime}, endTime: ${endTime}, duration: ${duration}`
          )
      );
    listenerSubscription.current.onLog = NativeVideoTrim.onLog(
      ({ level, message, sessionId }) =>
        console.log(
          'onLog',
          `level: ${level}, message: ${message}, sessionId: ${sessionId}`
        )
    );
    listenerSubscription.current.onStatistics = NativeVideoTrim.onStatistics(
      ({
        sessionId,
        videoFrameNumber,
        videoFps,
        videoQuality,
        size,
        time,
        bitrate,
        speed,
      }) =>
        console.log(
          'onStatistics',
          `sessionId: ${sessionId}, videoFrameNumber: ${videoFrameNumber}, videoFps: ${videoFps}, videoQuality: ${videoQuality}, size: ${size}, time: ${time}, bitrate: ${bitrate}, speed: ${speed}`
        )
    );
    listenerSubscription.current.onError = NativeVideoTrim.onError(
      ({ message, errorCode }) =>
        console.log('onError', `message: ${message}, errorCode: ${errorCode}`)
    );

    return () => {
      listenerSubscription.current.onLoad?.remove();
      listenerSubscription.current.onStartTrimming?.remove();
      listenerSubscription.current.onCancelTrimming?.remove();
      listenerSubscription.current.onCancel?.remove();
      listenerSubscription.current.onHide?.remove();
      listenerSubscription.current.onShow?.remove();
      listenerSubscription.current.onFinishTrimming?.remove();
      listenerSubscription.current.onLog?.remove();
      listenerSubscription.current.onStatistics?.remove();
      listenerSubscription.current.onError?.remove();
      listenerSubscription.current = {};
    };
  });

  const onMediaLoaded = (response: ImagePickerResponse) => {
    console.log('Response', response);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity
        onPress={async () => {
          try {
            const result = await launchImageLibrary(
              {
                mediaType: 'video',
                includeExtra: true,
                assetRepresentationMode: 'current',
              },
              onMediaLoaded
            );

            console.log(result, 1111);

            // const url =
            //   'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

            // const url1 =
            //   'https://www2.cs.uic.edu/~i101/SoundFiles/BabyElephantWalk60.wav';
            // const url2 = 'https://example.com';
            // isValidFile(url).then((res) => console.log('1isValidVideo:', res));
            // isValidFile(url1).then((res) => console.log('2isValidVideo:', res));
            // isValidFile(url2).then((res) => console.log('3isValidVideo:', res));
            // const url3 =
            //   'https://file-examples.com/storage/fe825adda4669e5de9419e0/2017/11/file_example_MP3_5MG.mp3';
            showEditor(result.assets![0]?.uri || '', {
              // showEditor(url3, {
              //   type: 'audio',
              // outputExt: 'wav',
              // closeWhenFinish: false,
              // minDuration: 50,
              maxDuration: 15,
              fullScreenModalIOS: true,
              saveToPhoto: true,
              removeAfterSavedToPhoto: true,
              // enableHapticFeedback: false,
              autoplay: true,
              jumpToPositionOnLoad: 30000,
              // headerText: 'Bunny.wav',
              headerTextSize: 20,
              headerTextColor: '#FF0000',
              // openDocumentsOnFinish: true,
              // removeAfterSavedToDocuments: true,
              // openShareSheetOnFinish: true,
              // removeAfterShared: true,
              // cancelButtonText: 'hello',
              // saveButtonText: 'world',
              // removeAfterSavedToPhoto: true,
              // enableCancelDialog: false,
              // cancelDialogTitle: '1111',
              // cancelDialogMessage: '22222',
              // cancelDialogCancelText: '3333',
              // cancelDialogConfirmText: '4444',
              // enableSaveDialog: false,
              // saveDialogTitle: '5555',
              // saveDialogMessage: '666666',
              // saveDialogCancelText: '77777',
              // saveDialogConfirmText: '888888',
              trimmingText: 'Trimming Video...',
              // enableRotation: true,
              // rotationAngle: 90,
            });
          } catch (error) {
            console.log(error);
          }
        }}
        style={{ padding: 10, backgroundColor: 'red' }}
      >
        <Text style={{ color: 'white' }}>Launch Library</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => {
          isValidFile(
            '/storage/emulated/0/Android/data/com.videotrimexample/cache/trimmedVideo_20230910_111719.mp4'
          ).then((res) => console.log(res));
        }}
        style={{
          padding: 10,
          backgroundColor: 'blue',
          marginTop: 20,
        }}
      >
        <Text style={{ color: 'white' }}>Check Video Valid</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => {
          listFiles().then((res) => {
            console.log(res);
          });
        }}
        style={{
          padding: 10,
          backgroundColor: 'orange',
          marginTop: 20,
        }}
      >
        <Text style={{ color: 'white' }}>List Files</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => {
          cleanFiles().then((res) => console.log(res));
        }}
        style={{
          padding: 10,
          backgroundColor: 'green',
          marginTop: 20,
        }}
      >
        <Text style={{ color: 'white' }}>Clean Files</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => {
          listFiles().then((res) => {
            console.log(res);

            if (res.length) {
              deleteFile(res[0]!).then((r) => console.log('DELETE:', r));
            }
          });
        }}
        style={{
          padding: 10,
          backgroundColor: 'purple',
          marginTop: 20,
        }}
      >
        <Text style={{ color: 'white' }}>Delete file</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={async () => {
          // const result = await launchImageLibrary(
          //   {
          //     mediaType: 'video',
          //     includeExtra: true,
          //     assetRepresentationMode: 'current',
          //   },
          //   onMediaLoaded
          // );

          const url =
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

          setIsTrimming(true);
          trim(url, {
            startTime: 0,
            endTime: 15000,
            saveToPhoto: true,
            enableRotation: true,
            rotationAngle: 90,
          })
            .then((res) => {
              console.log('Trimmed file:', res);
            })
            .catch((error) => {
              console.error('Error trimming file:', error);
            })
            .finally(() => {
              setIsTrimming(false);
            });
        }}
        style={{
          padding: 10,
          backgroundColor: 'brown',
          marginTop: 20,
        }}
      >
        <Text style={{ color: 'white' }}>
          {isTrimming ? 'Trimming...' : 'Trim Video'}
        </Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => {
          setModalVisible(true);
        }}
        style={{
          padding: 10,
          backgroundColor: 'blue',
          marginTop: 20,
        }}
      >
        <Text style={{ color: 'white' }}>Open Modal</Text>
      </TouchableOpacity>

      <Modal
        animationType="slide"
        transparent={true}
        visible={modalVisible}
        onRequestClose={() => {
          setModalVisible(!modalVisible);
        }}
      >
        <View style={[styles.container, { backgroundColor: 'gray' }]}>
          <TouchableOpacity
            onPress={async () => {
              const result = await launchImageLibrary({
                mediaType: 'video',
                assetRepresentationMode: 'current',
              });

              isValidFile(result.assets![0]?.uri || '').then((res) =>
                console.log('isValidVideo:', res)
              );

              showEditor(result.assets![0]?.uri || '', {
                maxDuration: 30,
                cancelButtonText: 'hello',
                saveButtonText: 'world',
              });
            }}
            style={{ padding: 10, backgroundColor: 'red' }}
          >
            <Text style={{ color: 'white' }}>Launch Library</Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={() => {
              setModalVisible(false);
            }}
            style={{
              padding: 10,
              backgroundColor: 'blue',
              marginTop: 20,
            }}
          >
            <Text style={{ color: 'white' }}>Close Modal</Text>
          </TouchableOpacity>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'white',
  },
});
