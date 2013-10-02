package de.jpaw.bonaparte.dsl.tests

import de.jpaw.bonaparte.dsl.BonScriptInjectorProvider
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(XtextRunner)
@InjectWith(BonScriptInjectorProvider)
class IntegrationTest extends AbstractCompilerTest {
	
	@Test def void testBaseAPI() {
		assertNoChanges(new File("./input/base-api"),64)
	}
	
	@Test def void testBaseAPI_new_syntax() {
		assertNoChanges(new File("./input/base-api-new-syntax"),0)
	}
	
	@Test def void testModel1() {
		'''
			package somepackage {
				default private unsigned trim noControlChars;
			
			    type namedType is Ascii(255);
			    enum MyEnum { FOO, BAR, BAZ }
			    
				abstract immutable class AbstractClass {
				    enum MyEnum fieldEnum;
					boolean fieldBoolean;
					required namedType requiredFieldNamedType;
					int fieldInt;
			        Integer fieldInteger;
			        ascii(20) fieldAsci20;
				}
				
				class SubClass extends AbstractClass {
			        ascii(39) [] fieldArray;
			        required Unicode(512) unicodeField;
			        
			        optional (AbstractClass...)[] fieldAbstractOrMoreConcrete;
			        (SubClass) [] subClasses;
			        
			        optional Timestamp(3) fieldTimeStamp;
			    }
			}
		'''.assertNoChanges(3)
	}
	
	@Test def void testModel1_newSyntax() {
		'''
			package somepackage {
				default private unsigned trim noControlChars;
			
			    type namedType is Ascii(255);
			    enum MyEnum { FOO, BAR, BAZ }
			    
				abstract immutable class AbstractClass {
				    MyEnum fieldEnum;
					boolean fieldBoolean;
					required namedType requiredFieldNamedType;
					int fieldInt;
			        Integer fieldInteger;
			        ascii(20) fieldAsci20;
				}
				
				class SubClass extends AbstractClass {
			        ascii(39) [] fieldArray;
			        required Unicode(512) unicodeField;
			        
			        optional AbstractClass...[] fieldAbstractOrMoreConcrete;
			        SubClass[] subClasses;
			        
			        optional Timestamp(3) fieldTimeStamp;
			    }
			}
		'''.assertNoChanges
	}
	
	@Test def void testModel2() {
		'''
			package money {
			    properties unroll;
			    
			    type amount is signed Decimal(18,6);   // this is an example, pick any precision, and allow any rounding and / or autoscaling
			
			    class PriceWithTax implements de.jpaw.money.MoneyGetter, de.jpaw.money.MoneySetter {
			        optional amount                 amount;
			        required amount required List<> componentAmounts;
			    }
			
			}
		'''.assertNoChanges
	}
}