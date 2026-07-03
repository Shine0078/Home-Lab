import { StyleSheet, Text, View } from 'react-native';

import { colors, spacing, typography } from '../theme';

type SectionHeaderProps = {
  eyebrow?: string;
  title: string;
  description?: string;
};

export function SectionHeader({ eyebrow, title, description }: SectionHeaderProps) {
  return (
    <View style={styles.shell}>
      {eyebrow ? <Text style={styles.eyebrow}>{eyebrow}</Text> : null}
      <Text style={styles.title}>{title}</Text>
      {description ? <Text style={styles.description}>{description}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  shell: {
    gap: spacing.sm,
  },
  eyebrow: {
    color: colors.brand,
    fontSize: typography.caption,
    fontWeight: '800',
    letterSpacing: 1.4,
    textTransform: 'uppercase',
  },
  title: {
    color: colors.text,
    fontSize: typography.title,
    fontWeight: '800',
  },
  description: {
    color: colors.muted,
    fontSize: typography.body,
    lineHeight: 22,
  },
});
