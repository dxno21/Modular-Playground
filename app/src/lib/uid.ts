let counter = 0;

export function uid(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  counter += 1;
  return `id-${Date.now().toString(36)}-${counter}`;
}
