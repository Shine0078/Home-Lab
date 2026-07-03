export type Accent = 'blue' | 'green' | 'amber' | 'red' | 'purple' | 'slate';

export type PhaseStatus = 'ready' | 'manual' | 'requires-admin' | 'verify';

export type Severity = 'critical' | 'high' | 'medium' | 'low' | 'info';

export type ScriptLocation = 'host' | 'dc01' | 'client' | 'any';

export type LabPhase = {
  id: string;
  title: string;
  subtitle: string;
  status: PhaseStatus;
  accent: Accent;
  commands: string[];
  outcomes: string[];
};

export type LabScript = {
  id: string;
  name: string;
  path: string;
  runOn: ScriptLocation;
  purpose: string;
  safety: string;
  requiresElevation: boolean;
};

export type ValidationCheck = {
  id: string;
  title: string;
  category: string;
  command: string;
  expected: string;
  severity: Severity;
};

export type SecurityControl = {
  id: string;
  title: string;
  family: string;
  implementation: string;
  evidence: string;
  severity: Severity;
};

export type Runbook = {
  id: string;
  title: string;
  path: string;
  trigger: string;
  firstResponse: string;
  escalation: string;
  severity: Severity;
};

export type QuickAction = {
  id: string;
  title: string;
  command: string;
  context: string;
  risk: Severity;
};

export type LabMetric = {
  label: string;
  value: string;
  detail: string;
  accent: Accent;
};

export type SafetyRule = {
  title: string;
  description: string;
};
