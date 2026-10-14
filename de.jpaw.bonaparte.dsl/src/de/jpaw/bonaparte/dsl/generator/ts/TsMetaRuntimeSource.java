package de.jpaw.bonaparte.dsl.generator.ts;

/** Source of the metadata types and the advisory validator emitted as bona-meta.ts into the portable-support owner module. */
public final class TsMetaRuntimeSource {
    /** File name (without extension) of the generated runtime support module. */
    public static final String MODULE_NAME = "bona-meta";

    private TsMetaRuntimeSource() {
    }

    public static String source() {
        return """
/** All bonaparte properties of a field or class; a property without value is `true`. */
export type BonaProps = Readonly<Record<string, string | true>>;

export interface TsFieldMeta {
    readonly required: boolean;
    /** DSL literal of the default value (explicit default, or the implicit enum default). */
    readonly default?: string;
    readonly minLength?: number;
    readonly maxLength?: number;
    readonly pattern?: string;
    readonly case?: 'uppercase' | 'lowercase';
    readonly precision?: number;
    readonly scale?: number;
    readonly maxBytes?: number;
    readonly aggregate?: {
        readonly kind: 'array' | 'list' | 'set' | 'map';
        readonly minCount?: number;
        readonly maxCount?: number;
    };
    readonly props: BonaProps;
    /** Declared object type of the field (the Ref base class for reference fields). */
    readonly objectType?: () => TsClassMeta;
    /** Secondary type of a reference field declared as (Ref...,Target). */
    readonly refTarget?: () => TsClassMeta;
}

export interface TsClassMeta {
    readonly pqon: string;
    readonly parent?: () => TsClassMeta;
    readonly props: BonaProps;
    /** If true, class properties not defined here are looked up in the parent. */
    readonly propsInherited: boolean;
    /** Fields declared by this class only; use bonAllFields() to include the inherited ones. */
    readonly own: Readonly<Record<string, TsFieldMeta>>;
}

export type BonValidationRule = 'required' | 'minLength' | 'maxLength' | 'pattern' | 'case'
    | 'integerDigits' | 'scale' | 'maxBytes' | 'minCount' | 'maxCount';

export interface BonValidationIssue {
    readonly path: string;
    readonly rule: BonValidationRule;
    readonly limit?: number | string;
    readonly actual?: number | string;
}

/** Fields of the class including inherited ones; a child field replaces a parent field of the same name. */
export function bonAllFields(meta: TsClassMeta): Record<string, TsFieldMeta> {
    const parent = meta.parent?.();
    return parent ? { ...bonAllFields(parent), ...meta.own } : { ...meta.own };
}

/** Class property, falling back to the parent classes if the class declares "properties inherited". */
export function bonClassProp(meta: TsClassMeta, key: string): string | true | undefined {
    if (Object.hasOwn(meta.props, key))
        return meta.props[key];
    const parent = meta.propsInherited ? meta.parent?.() : undefined;
    return parent ? bonClassProp(parent, key) : undefined;
}

/**
 * Advisory client side check of the constraints known from the BON definition.
 * It never throws and is never called implicitly; the server remains authoritative.
 */
export function bonValidate(meta: TsClassMeta, value: object, path = ''): BonValidationIssue[] {
    const issues: BonValidationIssue[] = [];
    const record = value as Record<string, unknown>;
    for (const [name, field] of Object.entries(bonAllFields(meta)))
        validateField(field, record[name], path ? `${path}.${name}` : name, issues);
    return issues;
}

const patterns = new Map<string, RegExp | null>();

function compiledPattern(pattern: string): RegExp | null {
    let regexp = patterns.get(pattern);
    if (regexp === undefined) {
        try {
            regexp = new RegExp(`^(?:${pattern})$`);
        } catch {
            regexp = null;
        }
        patterns.set(pattern, regexp);
    }
    return regexp;
}

function validateField(field: TsFieldMeta, value: unknown, path: string, issues: BonValidationIssue[]): void {
    if (value === undefined || value === null) {
        if (field.required)
            issues.push({ path, rule: 'required' });
        return;
    }
    const aggregate = field.aggregate;
    if (!aggregate) {
        validateElement(field, value, path, issues);
        return;
    }
    let entries: [string, unknown][];
    if (aggregate.kind === 'map' && typeof value === 'object' && !Array.isArray(value))
        entries = Object.entries(value);
    else if (aggregate.kind !== 'map' && Array.isArray(value))
        entries = value.map((item, index): [string, unknown] => [String(index), item]);
    else
        return;
    if (aggregate.minCount !== undefined && entries.length < aggregate.minCount)
        issues.push({ path, rule: 'minCount', limit: aggregate.minCount, actual: entries.length });
    if (aggregate.maxCount !== undefined && entries.length > aggregate.maxCount)
        issues.push({ path, rule: 'maxCount', limit: aggregate.maxCount, actual: entries.length });
    for (const [key, item] of entries)
        validateElement(field, item, `${path}[${key}]`, issues);
}

function validateElement(field: TsFieldMeta, item: unknown, path: string, issues: BonValidationIssue[]): void {
    if (item === undefined || item === null)
        return; // collection elements may be null
    if (typeof item === 'object') {
        if (field.objectType && !Array.isArray(item))
            issues.push(...bonValidate(field.objectType(), item, path));
        return;
    }
    if (field.precision !== undefined && (typeof item === 'number' || typeof item === 'string'))
        validateDecimal(field, item, path, issues);
    else if (field.maxBytes !== undefined && typeof item === 'string')
        validateBytes(field.maxBytes, item, path, issues);
    else if (typeof item === 'string')
        validateString(field, item, path, issues);
}

function validateString(field: TsFieldMeta, text: string, path: string, issues: BonValidationIssue[]): void {
    if (field.minLength !== undefined && text.length < field.minLength)
        issues.push({ path, rule: 'minLength', limit: field.minLength, actual: text.length });
    if (field.maxLength !== undefined && text.length > field.maxLength)
        issues.push({ path, rule: 'maxLength', limit: field.maxLength, actual: text.length });
    if (field.pattern !== undefined && compiledPattern(field.pattern)?.test(text) === false)
        issues.push({ path, rule: 'pattern', limit: field.pattern });
    if (field.case === 'uppercase' && text !== text.toUpperCase())
        issues.push({ path, rule: 'case', limit: 'uppercase' });
    if (field.case === 'lowercase' && text !== text.toLowerCase())
        issues.push({ path, rule: 'case', limit: 'lowercase' });
}

function validateBytes(maxBytes: number, base64: string, path: string, issues: BonValidationIssue[]): void {
    const clean = base64.replace(/\\s+/g, '');
    const padding = clean.endsWith('==') ? 2 : clean.endsWith('=') ? 1 : 0;
    const bytes = Math.floor(clean.length * 3 / 4) - padding;
    if (bytes > maxBytes)
        issues.push({ path, rule: 'maxBytes', limit: maxBytes, actual: bytes });
}

function validateDecimal(field: TsFieldMeta, item: number | string, path: string, issues: BonValidationIssue[]): void {
    const text = typeof item === 'number' ? (Number.isFinite(item) ? String(item) : '') : item.trim();
    const match = /^[+-]?(\\d*)(?:\\.(\\d*))?$/.exec(text); // exponent notation is not checked
    if (!match)
        return;
    const integerDigits = (match[1] ?? '').replace(/^0+/, '').length;
    const fractionDigits = (match[2] ?? '').replace(/0+$/, '').length;
    const scale = field.scale ?? 0;
    if (fractionDigits > scale)
        issues.push({ path, rule: 'scale', limit: scale, actual: fractionDigits });
    const maxIntegerDigits = (field.precision ?? 0) - scale;
    if (integerDigits > maxIntegerDigits)
        issues.push({ path, rule: 'integerDigits', limit: maxIntegerDigits, actual: integerDigits });
}
""";
    }
}
