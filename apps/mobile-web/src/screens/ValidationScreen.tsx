import { StyleSheet, Text, View } from 'react-native';

import { Badge } from '../components/Badge';
import { Card } from '../components/Card';
import { CommandBlock } from '../components/CommandBlock';
import { SectionHeader } from '../components/SectionHeader';
import { validationChecks } from '../data/labData';
import { colors, spacing, typography } from '../theme';

type ValidationScreenProps = {
  isWide: boolean;
};

export function ValidationScreen({ isWide }: ValidationScreenProps) {
  return (
    <View style={styles.screen}>
      <SectionHeader
        eyebrow="Acceptance Tests"
        title="Validation Checklist"
        description="Use these checks to prove the lab is functional after provisioning, rebuilds, or demos."
      />
      <View style={[styles.grid, isWide ? styles.gridWide : undefined]}>
        {validationChecks.map((check) => (
          <Card key={check.id} style={styles.card}>
            <View style={styles.header}>
              <Badge label={check.category} accent="blue" />
              <Badge label={check.severity} severity={check.severity} />
            </View>
            <Text style={styles.title}>{check.title}</Text>
            <CommandBlock command={check.command} label="Evidence command" />
            <Text style={styles.expected}>{check.expected}</Text>
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
    minWidth: 320,
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
  expected: {
    color: colors.muted,
    fontSize: typography.body,
    lineHeight: 22,
  },
});
