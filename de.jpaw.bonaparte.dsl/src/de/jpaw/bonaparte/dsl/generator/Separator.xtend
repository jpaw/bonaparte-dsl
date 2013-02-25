package de.jpaw.bonaparte.dsl.generator


class Separator {
    private var String current = ""

    def public String getCurrent() {
        return current
    }
    
    def public String setCurrent(String newString) {
        current = newString
        return ""
    }
}