import { StatusBar } from 'expo-status-bar';
import { SafeAreaView, StyleSheet } from 'react-native';

import { DashboardApp } from './src/DashboardApp';
import { colors } from './src/theme';

export default function App() {
  return (
    <SafeAreaView style={styles.shell}>
      <StatusBar style="light" />
      <DashboardApp />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  shell: {
    flex: 1,
    backgroundColor: colors.ink,
  },
});
