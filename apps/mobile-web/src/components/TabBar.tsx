import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';

import { colors, radii, spacing } from '../theme';

export type TabKey = 'dashboard' | 'phases' | 'scripts' | 'validation' | 'security' | 'runbooks' | 'about';

type TabItem = {
  key: TabKey;
  label: string;
};

type TabBarProps = {
  active: TabKey;
  items: TabItem[];
  onChange: (tab: TabKey) => void;
};

export function TabBar({ active, items, onChange }: TabBarProps) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.shell}>
      {items.map((item) => {
        const selected = item.key === active;

        return (
          <Pressable
            accessibilityRole="tab"
            accessibilityState={{ selected }}
            key={item.key}
            onPress={() => onChange(item.key)}
            style={[styles.tab, selected ? styles.selected : undefined]}
          >
            <Text style={[styles.label, selected ? styles.selectedLabel : undefined]}>{item.label}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  shell: {
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  },
  tab: {
    backgroundColor: colors.panelSoft,
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  selected: {
    backgroundColor: colors.brand,
    borderColor: colors.brand,
  },
  label: {
    color: colors.muted,
    fontSize: 14,
    fontWeight: '800',
  },
  selectedLabel: {
    color: colors.ink,
  },
});
