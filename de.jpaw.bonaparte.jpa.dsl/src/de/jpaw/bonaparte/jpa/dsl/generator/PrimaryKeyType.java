package de.jpaw.bonaparte.jpa.dsl.generator;

public enum PrimaryKeyType {
    NONE,                   // no primary key at all
    SINGLE_COLUMN,          // basic single column field (for example an artificial key)
    IMPLICIT_EMBEDDABLE,    // multi-column natural key, with implicit Embeddable of name (entity)Key
    EXPLICIT_EMBEDDABLE,    // using a regular embeddable as a key
    ID_CLASS                // using an explicit ID class (multiple @Id fields)
}
