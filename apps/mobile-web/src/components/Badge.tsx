import { StyleSheet, Text, View } from 'react-native';

import { accents, colors, radii, spacing } from '../theme';
import type { Accent, Severity } from '../types';

type BadgeProps = {
  label: string;
  accent?: Accent;
  severity?: Severity;
};

const severityAccent: Record<Severity, Accent> = {
  critical: 'red',
  high: 'red',
  medium: 'amber',
  low: 'green',
  info: 'blue',
};

export function Badge({ label, accent = 'slate', severity }: BadgeProps) {
  const color = accents[severity ? severityAccent[severity] : accent];

  return (
    <View style={[styles.badge, { borderColor: color, backgroundColor: `${color}1f` }]}>
      <Text style={[styles.text, { color }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignSelf: 'flex-start',
    borderRadius: radii.sm,
    borderWidth: 1,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  text: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
  },
});
