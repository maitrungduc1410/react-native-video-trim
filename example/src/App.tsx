import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  NativeEventEmitter,
  NativeModules,
  Modal,
} from 'react-native';
import { isValidVideo, showEditor } from 'react-native-video-trim';
import { launchImageLibrary } from 'react-native-image-picker';
import { useEffect, useState } from 'react';

export default function App() {
  const [modalVisible, setModalVisible] = useState(false);

  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(NativeModules.VideoTrim);
    const subscription = eventEmitter.addListener('VideoTrim', (event) => {
      switch (event.name) {
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
        case 'onError': {
          console.log('onError', event);
          break;
        }
      }
    });

    return () => {
      subscription.remove();
    };
  }, []);

  return (
    <View style={styles.container}>
      <TouchableOpacity
        onPress={async () => {
          const result = await launchImageLibrary({
            mediaType: 'video',
          });

          isValidVideo(result.assets![0]?.uri || '').then((res) =>
            console.log('isValidVideo:', res)
          );

          showEditor(result.assets![0]?.uri || '', {
            maxDuration: 30,
            cancelButtonText: 'hello',
            saveButtonText: 'world',
            title: 'JAMESSSS',
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
          isValidVideo(
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
              });

              isValidVideo(result.assets![0]?.uri || '').then((res) =>
                console.log('isValidVideo:', res)
              );

              showEditor(result.assets![0]?.uri || '', {
                maxDuration: 30,
              })
                .then((res) => console.log(res))
                .catch((e) => console.log(e));
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
