import { StyleSheet, Text, View } from 'react-native';

import { Card } from '../components/Card';
import { CommandBlock } from '../components/CommandBlock';
import { SectionHeader } from '../components/SectionHeader';
import { StatCard } from '../components/StatCard';
import { labSummary, metrics, phases, quickActions, safetyRules } from '../data/labData';
import { colors, spacing, typography } from '../theme';

type DashboardScreenProps = {
  isWide: boolean;
};

export function DashboardScreen({ isWide }: DashboardScreenProps) {
  const currentPhase = phases.find((phase) => phase.status === 'manual') ?? phases[0]!;

  return (
    <View style={styles.screen}>
      <View style={[styles.metricsGrid, isWide ? styles.gridWide : undefined]}>
        {metrics.map((metric) => (
          <StatCard key={metric.label} metric={metric} />
        ))}
      </View>

      <View style={[styles.columns, isWide ? styles.columnsWide : undefined]}>
        <Card style={styles.primaryCard}>
          <SectionHeader
            eyebrow="Recommended Next Step"
            title={currentPhase.title}
            description={currentPhase.subtitle}
          />
          {currentPhase.commands.map((command) => (
            <CommandBlock key={command} command={command} />
          ))}
          <Text style={styles.body}>{currentPhase.outcomes.join(' ')}</Text>
        </Card>

        <Card style={styles.sideCard}>
          <SectionHeader title="Lab Topology" description="What this dashboard represents." />
          <InfoRow label="Controller" value={labSummary.controller} />
          <InfoRow label="Network" value={labSummary.network} />
          <InfoRow label="Clients" value={labSummary.clients.join(', ')} />
          <InfoRow label="Automation" value="PowerShell, DSC, Hyper-V, Vagrant" />
        </Card>
      </View>

      <View style={[styles.columns, isWide ? styles.columnsWide : undefined]}>
        <Card style={styles.primaryCard}>
          <SectionHeader eyebrow="Safe Operations" title="Quick Commands" description="Reference commands for local execution." />
          {quickActions.map((action) => (
            <View key={action.id} style={styles.action}>
              <Text style={styles.actionTitle}>{action.title}</Text>
              <Text style={styles.body}>{action.context}</Text>
              <CommandBlock command={action.command} />
            </View>
          ))}
        </Card>

        <Card style={styles.sideCard}>
          <SectionHeader title="Safety Boundary" description="The app is intentionally non-privileged." />
          {safetyRules.map((rule) => (
            <View key={rule.title} style={styles.rule}>
              <Text style={styles.ruleTitle}>{rule.title}</Text>
              <Text style={styles.body}>{rule.description}</Text>
            </View>
          ))}
        </Card>
      </View>
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    gap: spacing.xl,
  },
  metricsGrid: {
    gap: spacing.md,
  },
  gridWide: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  columns: {
    gap: spacing.md,
  },
  columnsWide: {
    alignItems: 'stretch',
    flexDirection: 'row',
  },
  primaryCard: {
    flex: 2,
    gap: spacing.lg,
  },
  sideCard: {
    flex: 1,
    gap: spacing.lg,
  },
  body: {
    color: colors.muted,
    fontSize: typography.body,
    lineHeight: 22,
  },
  action: {
    gap: spacing.sm,
  },
  actionTitle: {
    color: colors.text,
    fontSize: typography.subtitle,
    fontWeight: '800',
  },
  rule: {
    borderTopColor: colors.line,
    borderTopWidth: 1,
    gap: spacing.xs,
    paddingTop: spacing.md,
  },
  ruleTitle: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '800',
  },
  infoRow: {
    borderBottomColor: colors.line,
    borderBottomWidth: 1,
    gap: spacing.xs,
    paddingBottom: spacing.md,
  },
  infoLabel: {
    color: colors.muted,
    fontSize: typography.caption,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  infoValue: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
});
