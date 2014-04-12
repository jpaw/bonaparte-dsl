package de.jpaw.bonaparte.dsl.generator;

// keep this in sync with the enum of same name in bonaparte-core / meta.bon
public enum DataCategory {
	OBJECT, ENUM, NUMERIC, STRING, TEMPORAL, MISC, BINARY, BASICNUMERIC, XENUM  // misc is boolean, char, uuid, ...
}
