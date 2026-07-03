import { StyleSheet, Text, View } from 'react-native';

import { Badge } from '../components/Badge';
import { Card } from '../components/Card';
import { CommandBlock } from '../components/CommandBlock';
import { SectionHeader } from '../components/SectionHeader';
import { phases } from '../data/labData';
import { accents, colors, spacing, typography } from '../theme';

type PhasesScreenProps = {
  isWide: boolean;
};

export function PhasesScreen({ isWide }: PhasesScreenProps) {
  return (
    <View style={styles.screen}>
      <SectionHeader
        eyebrow="Build Flow"
        title="Lab Phases"
        description="Follow the phases in order. Admin-only and manual stages are marked so demos stay realistic."
      />
      <View style={[styles.grid, isWide ? styles.gridWide : undefined]}>
        {phases.map((phase, index) => (
          <Card key={phase.id} style={styles.card}>
            <View style={styles.phaseHeader}>
              <View style={[styles.step, { backgroundColor: accents[phase.accent] }]}>
                <Text style={styles.stepText}>{index}</Text>
              </View>
              <Badge label={phase.status.replace('-', ' ')} accent={phase.accent} />
            </View>
            <Text style={styles.title}>{phase.title}</Text>
            <Text style={styles.body}>{phase.subtitle}</Text>
            <View style={styles.commandList}>
              {phase.commands.map((command) => (
                <CommandBlock key={command} command={command} />
              ))}
            </View>
            {phase.outcomes.map((outcome) => (
              <Text key={outcome} style={styles.outcome}>
                {outcome}
              </Text>
            ))}
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
    flexBasis: '32%',
  },
  phaseHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  step: {
    alignItems: 'center',
    borderRadius: 999,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  stepText: {
    color: colors.ink,
    fontSize: 16,
    fontWeight: '900',
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
  commandList: {
    gap: spacing.sm,
  },
  outcome: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 20,
  },
});
