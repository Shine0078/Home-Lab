import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors, radii, spacing } from '../theme';

type CommandBlockProps = {
  command: string;
  label?: string;
};

export function CommandBlock({ command, label = 'Command' }: CommandBlockProps) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`${label}: ${command}`} style={styles.shell}>
      <View style={styles.header}>
        <Text style={styles.label}>{label}</Text>
        <Text style={styles.copyHint}>Copy manually</Text>
      </View>
      <Text selectable style={styles.command}>
        {command}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  shell: {
    backgroundColor: colors.ink,
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    gap: spacing.sm,
    padding: spacing.md,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  label: {
    color: colors.muted,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
  },
  copyHint: {
    color: colors.slate,
    fontSize: 12,
  },
  command: {
    color: colors.text,
    fontFamily: 'Courier New',
    fontSize: 13,
    lineHeight: 18,
  },
});
