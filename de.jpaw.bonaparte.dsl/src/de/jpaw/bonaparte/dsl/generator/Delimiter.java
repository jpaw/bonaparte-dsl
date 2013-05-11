package de.jpaw.bonaparte.dsl.generator;

public class Delimiter {
    boolean firstCall = true;
    private final String initialText;
    private final String subsequentText;
    
    public Delimiter(String initialText, String subsequentText) {
        this.initialText = initialText;
        this.subsequentText = subsequentText;
    }
    
    public String get() {
        if (firstCall) {
            firstCall = false;
            return initialText; 
        }
        return subsequentText;
    }
}
