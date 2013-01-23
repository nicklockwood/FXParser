//
//  ParserTests.m
//  UnitTests
//
//  Created by Nick Lockwood on 15/01/2013.
//
//

#import "ParserTests.h"
#import "FXParser.h"


@implementation ParserTests

- (void)testCharacter
{
    //create parser
    FXParser *parser = [FXParser regexp:@"\\d"];
    
    //test success
    NSAssert([parser parse:@"5"].success, @"Something went wrong");
    
    //test failure
    NSAssert(![parser parse:@"A"].success, @"Something went wrong");
}

- (void)testPrimitives
{
    //create parser
    FXParser *parser = [FXParser string:@"foo"];
    
    //test success
    NSAssert([parser parse:@"foo"].success, @"Something went wrong");
    NSAssert([parser parse:@"foobar"].success, @"Something went wrong");
    
    //test failure
    NSAssert(![parser parse:@"bar"].success, @"Something went wrong");
    NSAssert(![parser parse:@"barfoo"].success, @"Something went wrong");
}

- (void)testChoice
{
    //create parser
    FXParser *parser = [[FXParser string:@"foo"] or:[FXParser string:@"bar"]];
    
    //test success
    NSAssert([parser parse:@"foo"].success, @"Something went wrong");
    NSAssert([parser parse:@"bar"].success, @"Something went wrong");
    NSAssert([parser parse:@"foobar"].success, @"Something went wrong");
    
    //test failure
    NSAssert(![parser parse:@"boo"].success, @"Something went wrong");
}

- (void)testSequence
{
    //create parser
    FXParser *parser = [[FXParser string:@"foo"] then:[FXParser string:@"bar"]];
    
    //test success
    NSAssert([parser parse:@"foobar"].success, @"Something went wrong");
    NSAssert([parser parse:@"foobarfoo"].success, @"Something went wrong");
    
    //test failure
    NSAssert(![parser parse:@"foo"].success, @"Something went wrong");
    NSAssert(![parser parse:@"bar"].success, @"Something went wrong");
    NSAssert(![parser parse:@"barfoo"].success, @"Something went wrong");
}

- (void)testReplacement
{
    FXParser *parser = [FXParser regexp:@"D(.)g" replacement:@"C$1g"];
    NSAssert([[parser parse:@"Dog"].value isEqualToString:@"Cog"], @"Something went wrong");
}

- (void)testJSON
{
    //create parser
    FXParser *json = [FXParser forwardDeclaration];
    
    //spacing
    FXParser *whitespace = [[FXParser regexp:@"\\s*"] discard];
    
    //punctuation
    FXParser *openBracket = [[[FXParser string:@"["] surroundedBy:whitespace] discard];
    FXParser *closeBracket = [[[FXParser string:@"]"] surroundedBy:whitespace] discard];
    FXParser *openBrace = [[[FXParser string:@"{"] surroundedBy:whitespace] discard];
    FXParser *closeBrace = [[[FXParser string:@"}"] surroundedBy:whitespace] discard];
    FXParser *comma = [[[FXParser string:@","] surroundedBy:whitespace] discard];
    FXParser *colon = [[[FXParser string:@":"] surroundedBy:whitespace] discard];
    
    //primitives
    FXParser *number = [[[FXParser regexp:@"-?0|([1-9][0-9]*)(\\.[0-9]+)?"] surroundedBy:whitespace] withValueForKeyPath:@"doubleValue"];
    FXParser *boolean = [[[FXParser regexp:@"true|false"] surroundedBy:whitespace] withValueForKeyPath:@"boolValue"];
    FXParser *null = [[[FXParser string:@"null"] surroundedBy:whitespace] withValue:[NSNull null]];
    
    //string
    FXParser *quote = [[FXParser string:@"\""] discard];
    FXParser *escape = [FXParser regexp:@"\\\\."];
    FXParser *string = [FXParser sequence:@[whitespace, quote, [[[[escape or:[FXParser regexp:@"[^\\\"]"]] oneOrMore] optional] join:@""] ,quote, whitespace]];
    
    //complex types
    FXParser *pair = [FXParser sequence:@[string, colon, json]];
    FXParser *object = [[[FXParser sequence:@[openBrace, [[pair separatedBy:comma] optional], closeBrace]] dictionary] surroundedBy:whitespace];
    FXParser *array = [[[FXParser sequence:@[openBracket, [[json separatedBy:comma] optional], closeBracket]] array] surroundedBy:whitespace];
    
    //final parser
    json.implementation = [FXParser oneOf:@[number, boolean, null, string, array, object]];
    
    //test primitive matching
    NSAssert([json parse:@" 5"].success, @"Something went wrong");
    NSAssert([json parse:  @"10.5 "].success, @"Something went wrong");
    NSAssert([json parse:@"null\n "].success, @"Something went wrong");
    NSAssert([json parse:@" true"].success, @"Something went wrong");
    NSAssert([json parse:@"false  "].success, @"Something went wrong");
    
    //test string matching
    FXParserResult *result = [json parse:@" \"foo\"   "];
    NSAssert(result.success && [result.value isEqualToString:@"foo"], @"Something went wrong");

    //test array
    result = [json parse:@"[1  ,2 ,  \n3]"];
    NSAssert((result.success && [result.value isEqualTo:@[@1,@2,@3]]), @"Something went wrong");
    
    //test empty array
    result = [json parse:@"[] "];
    NSAssert((result.success && [result.value isEqualTo:@[]]), @"Something went wrong");
    
    //test array of empty arrays
    result = [json parse:@"[[],[]]"];
    NSAssert((result.success && [result.value isEqualTo:@[@[],@[]]]), @"Something went wrong");
    
    //test dictionary
    result = [json parse:@"{ \n\"foo\"  :\n1, \"bar\" :2}   "];
    NSAssert((result.success && [result.value isEqualTo:@{@"foo":@1, @"bar":@2}]), @"Something went wrong");
    
    //test empty dictionary
    result = [json parse:@"{ }"];
    NSAssert((result.success && [result.value isEqualTo:@{}]), @"Something went wrong");
    
    //test failure
    NSAssert(![json parse:@"foo"].success, @"Something went wrong");
    NSAssert(![json parse:@"bar"].success, @"Something went wrong");
    NSAssert(![json parse:@"barfoo"].success, @"Something went wrong");
}

@end
