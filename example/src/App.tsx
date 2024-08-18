import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  NativeEventEmitter,
  NativeModules,
  Modal,
  BackHandler,
} from 'react-native';
import {
  cleanFiles,
  deleteFile,
  listFiles,
  showEditor,
  isValidFile,
} from 'react-native-video-trim';
import {
  launchImageLibrary,
  type ImagePickerResponse,
} from 'react-native-image-picker';
import { useEffect, useState } from 'react';

export default function App() {
  const [modalVisible, setModalVisible] = useState(false);

  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(NativeModules.VideoTrim);
    const subscription = eventEmitter.addListener('VideoTrim', (event) => {
      switch (event.name) {
        case 'onLoad': {
          console.log('onLoadListener', event);
          break;
        }
        case 'onShow': {
          console.log('onShowListener', event);
          break;
        }
        case 'onHide': {
          console.log('onHide', event);
          break;
        }
        case 'onStartTrimming': {
          console.log('onStartTrimming', event);
          break;
        }
        case 'onFinishTrimming': {
          console.log('onFinishTrimming', event);
          break;
        }
        case 'onCancelTrimming': {
          console.log('onCancelTrimming', event);
          break;
        }
        case 'onCancel': {
          console.log('onCancel', event);
          break;
        }
        case 'onError': {
          console.log('onError', event);
          break;
        }
        case 'onLog': {
          console.log('onLog', event);
          break;
        }
        case 'onStatistics': {
          console.log('onStatistics', event);
          break;
        }
      }
    });

    return () => {
      subscription.remove();
    };
  }, []);

  useEffect(() => {
    const backHandler = BackHandler.addEventListener(
      'hardwareBackPress',
      () => {
        console.log(9999999999);
        return true;
      }
    );
    return () => backHandler.remove();
  }, []);

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

            const url =
              'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

            const url1 =
              'https://www2.cs.uic.edu/~i101/SoundFiles/BabyElephantWalk60.wav';
            const url2 = 'https://example.com';
            isValidFile(url).then((res) => console.log('1isValidVideo:', res));
            isValidFile(url1).then((res) => console.log('2isValidVideo:', res));
            isValidFile(url2).then((res) => console.log('3isValidVideo:', res));
            const url3 =
              'https://file-examples.com/storage/fe825adda4669e5de9419e0/2017/11/file_example_MP3_5MG.mp3';
            // showEditor(result.assets![0]?.uri || '', {
            showEditor(url3, {
              type: 'audio',
              outputExt: 'wav',
              // maxDuration: 20,
              // closeWhenFinish: false,
              minDuration: 10,
              fullScreenModalIOS: true,
              saveToPhoto: true,
              removeAfterSavedToPhoto: true,
              enableHapticFeedback: false,
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
              })
                .then((res) => console.log(res))
                .catch((e) => console.log(e, 1111));
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
