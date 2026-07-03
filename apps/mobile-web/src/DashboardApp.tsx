import { useState } from 'react';
import { ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';

import { TabBar, type TabKey } from './components/TabBar';
import { labSummary } from './data/labData';
import { AboutScreen } from './screens/AboutScreen';
import { DashboardScreen } from './screens/DashboardScreen';
import { PhasesScreen } from './screens/PhasesScreen';
import { RunbooksScreen } from './screens/RunbooksScreen';
import { ScriptsScreen } from './screens/ScriptsScreen';
import { SecurityScreen } from './screens/SecurityScreen';
import { ValidationScreen } from './screens/ValidationScreen';
import { colors, spacing, typography } from './theme';

const tabs: { key: TabKey; label: string }[] = [
  { key: 'dashboard', label: 'Dashboard' },
  { key: 'phases', label: 'Phases' },
  { key: 'scripts', label: 'Scripts' },
  { key: 'validation', label: 'Validation' },
  { key: 'security', label: 'Security' },
  { key: 'runbooks', label: 'Runbooks' },
  { key: 'about', label: 'About' },
];

export function DashboardApp() {
  const [activeTab, setActiveTab] = useState<TabKey>('dashboard');
  const { width } = useWindowDimensions();

  const isWide = width >= 900;

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
      <View style={[styles.page, { paddingHorizontal: isWide ? spacing.xxl : spacing.lg }]}>
        <View style={[styles.hero, isWide ? styles.heroWide : undefined]}>
          <View style={styles.heroCopy}>
            <Text style={styles.kicker}>Active Directory Operations</Text>
            <Text style={styles.title}>{labSummary.name}</Text>
            <Text style={styles.subtitle}>{labSummary.positioning}</Text>
          </View>
          <View style={styles.domainCard}>
            <Text style={styles.domainLabel}>Domain</Text>
            <Text style={styles.domain}>{labSummary.domain}</Text>
            <Text style={styles.domainMeta}>{labSummary.network} | {labSummary.controller}</Text>
          </View>
        </View>

        <TabBar active={activeTab} items={tabs} onChange={setActiveTab} />

        {activeTab === 'dashboard' ? <DashboardScreen isWide={isWide} /> : null}
        {activeTab === 'phases' ? <PhasesScreen isWide={isWide} /> : null}
        {activeTab === 'scripts' ? <ScriptsScreen isWide={isWide} /> : null}
        {activeTab === 'validation' ? <ValidationScreen isWide={isWide} /> : null}
        {activeTab === 'security' ? <SecurityScreen isWide={isWide} /> : null}
        {activeTab === 'runbooks' ? <RunbooksScreen isWide={isWide} /> : null}
        {activeTab === 'about' ? <AboutScreen isWide={isWide} /> : null}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.ink,
    flex: 1,
  },
  scrollContent: {
    alignItems: 'center',
    minHeight: '100%',
  },
  page: {
    gap: spacing.xl,
    maxWidth: 1180,
    paddingBottom: spacing.xxl,
    paddingTop: spacing.xl,
    width: '100%',
  },
  hero: {
    backgroundColor: colors.inkSoft,
    borderColor: colors.line,
    borderRadius: 28,
    borderWidth: 1,
    gap: spacing.lg,
    overflow: 'hidden',
    padding: spacing.xl,
  },
  heroWide: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  heroCopy: {
    flex: 1,
    gap: spacing.sm,
  },
  kicker: {
    color: colors.brand,
    fontSize: typography.caption,
    fontWeight: '900',
    letterSpacing: 1.8,
    textTransform: 'uppercase',
  },
  title: {
    color: colors.text,
    fontSize: typography.hero,
    fontWeight: '900',
  },
  subtitle: {
    color: colors.muted,
    fontSize: typography.subtitle,
    lineHeight: 26,
    maxWidth: 720,
  },
  domainCard: {
    backgroundColor: colors.panel,
    borderColor: colors.line,
    borderRadius: 22,
    borderWidth: 1,
    minWidth: 240,
    padding: spacing.lg,
  },
  domainLabel: {
    color: colors.muted,
    fontSize: typography.caption,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  domain: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '900',
    marginTop: spacing.xs,
  },
  domainMeta: {
    color: colors.muted,
    fontSize: 13,
    marginTop: spacing.sm,
  },
});
