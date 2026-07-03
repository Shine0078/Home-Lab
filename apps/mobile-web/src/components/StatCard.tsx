import { StyleSheet, Text, View } from 'react-native';

import { accents, colors, spacing, typography } from '../theme';
import type { LabMetric } from '../types';
import { Card } from './Card';

type StatCardProps = {
  metric: LabMetric;
};

export function StatCard({ metric }: StatCardProps) {
  const accent = accents[metric.accent];

  return (
    <Card style={styles.card}>
      <View style={[styles.marker, { backgroundColor: accent }]} />
      <Text style={styles.label}>{metric.label}</Text>
      <Text style={styles.value}>{metric.value}</Text>
      <Text style={styles.detail}>{metric.detail}</Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: {
    flex: 1,
    gap: spacing.sm,
    minWidth: 150,
  },
  marker: {
    borderRadius: 999,
    height: 8,
    width: 48,
  },
  label: {
    color: colors.muted,
    fontSize: typography.caption,
    fontWeight: '800',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  value: {
    color: colors.text,
    fontSize: 26,
    fontWeight: '900',
  },
  detail: {
    color: colors.muted,
    fontSize: 13,
    lineHeight: 18,
  },
});
