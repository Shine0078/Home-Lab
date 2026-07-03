import { StyleSheet, Text, View } from 'react-native';

import { Badge } from '../components/Badge';
import { Card } from '../components/Card';
import { SectionHeader } from '../components/SectionHeader';
import { runbooks } from '../data/labData';
import { colors, spacing, typography } from '../theme';

type RunbooksScreenProps = {
  isWide: boolean;
};

export function RunbooksScreen({ isWide }: RunbooksScreenProps) {
  return (
    <View style={styles.screen}>
      <SectionHeader
        eyebrow="Incident Response"
        title="Operational Runbooks"
        description="Mobile-friendly summaries of the repository runbooks for common Active Directory lab failures."
      />
      <View style={[styles.grid, isWide ? styles.gridWide : undefined]}>
        {runbooks.map((runbook) => (
          <Card key={runbook.id} style={styles.card}>
            <View style={styles.header}>
              <Badge label={runbook.id.toUpperCase()} accent="slate" />
              <Badge label={runbook.severity} severity={runbook.severity} />
            </View>
            <Text style={styles.title}>{runbook.title}</Text>
            <Text selectable style={styles.path}>{runbook.path}</Text>
            <RunbookField label="Trigger" value={runbook.trigger} />
            <RunbookField label="First Response" value={runbook.firstResponse} />
            <RunbookField label="Escalation" value={runbook.escalation} />
          </Card>
        ))}
      </View>
    </View>
  );
}

function RunbookField({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <Text style={styles.fieldValue}>{value}</Text>
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
    minWidth: 330,
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
  path: {
    color: colors.brand,
    fontFamily: 'Courier New',
    fontSize: 13,
  },
  field: {
    borderTopColor: colors.line,
    borderTopWidth: 1,
    gap: spacing.xs,
    paddingTop: spacing.md,
  },
  fieldLabel: {
    color: colors.muted,
    fontSize: typography.caption,
    fontWeight: '900',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  fieldValue: {
    color: colors.text,
    fontSize: typography.body,
    lineHeight: 22,
  },
});
