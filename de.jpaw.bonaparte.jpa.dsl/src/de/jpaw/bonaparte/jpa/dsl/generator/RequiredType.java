package de.jpaw.bonaparte.jpa.dsl.generator;

public enum RequiredType {
    FORCE_NOT_NULL,     // if the field is part of a primary key or such
    FORCE_NULL,         // if the field is part of an embeddable, which is optional
    DEFAULT             // do as specified by the field's directives
}
