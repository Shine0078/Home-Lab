import { StyleSheet, Text, View } from 'react-native';

import { Badge } from '../components/Badge';
import { Card } from '../components/Card';
import { SectionHeader } from '../components/SectionHeader';
import { scripts } from '../data/labData';
import { colors, spacing, typography } from '../theme';
import type { ScriptLocation } from '../types';

type ScriptsScreenProps = {
  isWide: boolean;
};

const runOnLabel: Record<ScriptLocation, string> = {
  host: 'Hyper-V host',
  dc01: 'DC01',
  client: 'Client VM',
  any: 'Any shell',
};

export function ScriptsScreen({ isWide }: ScriptsScreenProps) {
  return (
    <View style={styles.screen}>
      <SectionHeader
        eyebrow="Automation Catalog"
        title="PowerShell Scripts"
        description="A field guide for where each script runs, what it changes, and why it is safe to rerun."
      />
      <View style={[styles.grid, isWide ? styles.gridWide : undefined]}>
        {scripts.map((script) => (
          <Card key={script.id} style={styles.card}>
            <View style={styles.header}>
              <Badge label={runOnLabel[script.runOn]} accent={script.runOn === 'host' ? 'blue' : 'green'} />
              {script.requiresElevation ? <Badge label="Admin" accent="red" /> : <Badge label="Read mostly" accent="slate" />}
            </View>
            <Text style={styles.name}>{script.name}</Text>
            <Text selectable style={styles.path}>{script.path}</Text>
            <Text style={styles.body}>{script.purpose}</Text>
            <View style={styles.safetyBox}>
              <Text style={styles.safetyLabel}>Safety</Text>
              <Text style={styles.body}>{script.safety}</Text>
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
    minWidth: 280,
    flexBasis: '32%',
  },
  header: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  name: {
    color: colors.text,
    fontSize: typography.subtitle,
    fontWeight: '900',
  },
  path: {
    color: colors.brand,
    fontFamily: 'Courier New',
    fontSize: 13,
  },
  body: {
    color: colors.muted,
    fontSize: typography.body,
    lineHeight: 22,
  },
  safetyBox: {
    backgroundColor: colors.inkSoft,
    borderColor: colors.line,
    borderRadius: 14,
    borderWidth: 1,
    gap: spacing.xs,
    padding: spacing.md,
  },
  safetyLabel: {
    color: colors.text,
    fontSize: typography.caption,
    fontWeight: '900',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
});
