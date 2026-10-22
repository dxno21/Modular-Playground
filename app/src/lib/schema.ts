import Ajv from 'ajv';
import moduleSchema from '../../../schema/module.schema.json';
import patchSchema from '../../../schema/patch.schema.json';

const ajv = new Ajv({ allErrors: true });

export const validateModuleJson = ajv.compile(moduleSchema);
export const validatePatchJson = ajv.compile(patchSchema);

export function formatErrors(errors: typeof validatePatchJson.errors): string[] {
  return (errors ?? []).map((e) => `${e.instancePath || '/'} ${e.message ?? ''}`.trim());
}
