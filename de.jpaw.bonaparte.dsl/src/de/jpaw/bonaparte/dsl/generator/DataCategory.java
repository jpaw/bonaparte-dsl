package de.jpaw.bonaparte.dsl.generator;

// keep this in sync with the enum of same name in bonaparte-core / meta.bon
public enum DataCategory {
	OBJECT, ENUM, NUMERIC, STRING, TEMPORAL, MISC  // misc is boolean, binary, char, uuid, ...
}
