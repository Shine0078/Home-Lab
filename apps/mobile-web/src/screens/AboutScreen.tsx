import { StyleSheet, Text, View } from 'react-native';

import { Card } from '../components/Card';
import { CommandBlock } from '../components/CommandBlock';
import { SectionHeader } from '../components/SectionHeader';
import { labSummary, safetyRules } from '../data/labData';
import { colors, spacing, typography } from '../theme';

type AboutScreenProps = {
  isWide: boolean;
};

export function AboutScreen({ isWide }: AboutScreenProps) {
  return (
    <View style={styles.screen}>
      <SectionHeader
        eyebrow="App Model"
        title="Safe Cross-Platform Dashboard"
        description="This app is designed for browsing, checklists, command reference, and demos. It intentionally does not bypass Windows administration boundaries."
      />
      <View style={[styles.columns, isWide ? styles.columnsWide : undefined]}>
        <Card style={styles.card}>
          <SectionHeader title="What It Does" />
          <Text style={styles.body}>{labSummary.positioning}</Text>
          <Text style={styles.body}>
            It turns the repository into an approachable operations console for web, iOS, and Android while preserving the PowerShell scripts as the source of truth.
          </Text>
          <CommandBlock command="npm install && npm run web" label="Run web app" />
        </Card>

        <Card style={styles.card}>
          <SectionHeader title="Security Model" />
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

const styles = StyleSheet.create({
  screen: {
    gap: spacing.xl,
  },
  columns: {
    gap: spacing.md,
  },
  columnsWide: {
    alignItems: 'stretch',
    flexDirection: 'row',
  },
  card: {
    flex: 1,
    gap: spacing.lg,
  },
  body: {
    color: colors.muted,
    fontSize: typography.body,
    lineHeight: 22,
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
    fontWeight: '900',
  },
});
