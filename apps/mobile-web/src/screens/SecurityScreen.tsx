import { StyleSheet, Text, View } from 'react-native';

import { Badge } from '../components/Badge';
import { Card } from '../components/Card';
import { SectionHeader } from '../components/SectionHeader';
import { securityControls } from '../data/labData';
import { colors, spacing, typography } from '../theme';

type SecurityScreenProps = {
  isWide: boolean;
};

export function SecurityScreen({ isWide }: SecurityScreenProps) {
  return (
    <View style={styles.screen}>
      <SectionHeader
        eyebrow="Defensive Posture"
        title="Security Controls"
        description="A dashboard-friendly map of the lab hardening and monitoring controls with evidence locations."
      />
      <View style={[styles.grid, isWide ? styles.gridWide : undefined]}>
        {securityControls.map((control) => (
          <Card key={control.id} style={styles.card}>
            <View style={styles.header}>
              <Badge label={control.family} accent="purple" />
              <Badge label={control.severity} severity={control.severity} />
            </View>
            <Text style={styles.title}>{control.title}</Text>
            <Text style={styles.body}>{control.implementation}</Text>
            <View style={styles.evidenceBox}>
              <Text style={styles.evidenceLabel}>Evidence</Text>
              <Text style={styles.evidence}>{control.evidence}</Text>
            </View>
          </Card>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    gap: spacing.xl,
  },
  grid: {
    gap: spacing.md,
  },
  gridWide: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  card: {
    gap: spacing.md,
    minWidth: 300,
    flexBasis: '48%',
  },
  header: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  title: {
    color: colors.text,
    fontSize: typography.subtitle,
    fontWeight: '900',
  },
  body: {
    color: colors.muted,
    fontSize: typography.body,
    lineHeight: 22,
  },
  evidenceBox: {
    backgroundColor: colors.inkSoft,
    borderColor: colors.line,
    borderRadius: 14,
    borderWidth: 1,
    gap: spacing.xs,
    padding: spacing.md,
  },
  evidenceLabel: {
    color: colors.brand,
    fontSize: typography.caption,
    fontWeight: '900',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  evidence: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 20,
  },
});
