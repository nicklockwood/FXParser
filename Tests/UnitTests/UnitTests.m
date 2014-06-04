//
//  FastCoderTests.m
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//


#import <XCTest/XCTest.h>
#import "FXParser.h"


@interface UnitTests : XCTestCase

@end


@implementation UnitTests

- (void)testCharacter
{
    //create parser
    FXParser *parser = [FXParser regexp:@"\\d"];
    
    //test success
    XCTAssertTrue([parser parse:@"5"].success, @"Something went wrong");
    
    //test failure
    XCTAssertFalse([parser parse:@"A"].success, @"Something went wrong");
}

- (void)testPrimitives
{
    //create parser
    FXParser *parser = [FXParser string:@"foo"];
    
    //test success
    XCTAssertTrue([parser parse:@"foo"].success, @"Something went wrong");
    XCTAssertTrue([parser parse:@"foobar"].success, @"Something went wrong");
    
    //test failure
    XCTAssertFalse([parser parse:@"bar"].success, @"Something went wrong");
    XCTAssertFalse([parser parse:@"barfoo"].success, @"Something went wrong");
}

- (void)testChoice
{
    //create parser
    FXParser *parser = [[FXParser string:@"foo"] or:[FXParser string:@"bar"]];
    
    //test success
    XCTAssertTrue([parser parse:@"foo"].success, @"Something went wrong");
    XCTAssertTrue([parser parse:@"bar"].success, @"Something went wrong");
    XCTAssertTrue([parser parse:@"foobar"].success, @"Something went wrong");
    
    //test failure
    XCTAssertFalse([parser parse:@"boo"].success, @"Something went wrong");
}

- (void)testSequence
{
    //create parser
    FXParser *parser = [[FXParser string:@"foo"] then:[FXParser string:@"bar"]];
    
    //test success
    XCTAssertTrue([parser parse:@"foobar"].success, @"Something went wrong");
    XCTAssertTrue([parser parse:@"foobarfoo"].success, @"Something went wrong");
    
    //test failure
    XCTAssertFalse([parser parse:@"foo"].success, @"Something went wrong");
    XCTAssertFalse([parser parse:@"bar"].success, @"Something went wrong");
    XCTAssertFalse([parser parse:@"barfoo"].success, @"Something went wrong");
}

- (void)testReplacement
{
    FXParser *parser = [FXParser regexp:@"D(.)g" replacement:@"C$1g"];
    XCTAssertEqualObjects([parser parse:@"Dog"].value, @"Cog", @"Something went wrong");
}

- (void)testJSON
{
    //create parser
    FXParser *json = [FXParser forwardDeclarationWithName:@"json"];
    
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
    FXParser *string = [[FXParser sequence:@[whitespace, quote, [[[[escape or:[FXParser regexp:@"[^\\\"]"]] zeroOrMoreTimes] optional] asString] ,quote, whitespace]] withTransformer:^(id value) {
        
        value = [value stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
        value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
        value = [value stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        value = [value stringByReplacingOccurrencesOfString:@"\\b" withString:@"\b"];
        value = [value stringByReplacingOccurrencesOfString:@"\\f" withString:@"\f"];
        value = [value stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
        value = [value stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
        value = [value stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
        return value; //TODO: unicode literals
    }];
    
    //complex types
    FXParser *pair = [FXParser sequence:@[string, colon, json]];
    FXParser *object = [[[FXParser sequence:@[openBrace, [[pair separatedBy:comma] optional], closeBrace]] asDictionary] surroundedBy:whitespace];
    FXParser *array = [[[FXParser sequence:@[openBracket, [[json separatedBy:comma] optional], closeBracket]] asArray] surroundedBy:whitespace];
    
    //final parser
    json.implementation = [FXParser oneOf:@[number, boolean, null, string, array, object]];
    
    //test primitive matching
    XCTAssertTrue([json parse:@" 5"].success, @"Something went wrong");
    XCTAssertTrue([json parse:  @"10.5 "].success, @"Something went wrong");
    XCTAssertTrue([json parse:@"null\n "].success, @"Something went wrong");
    XCTAssertTrue([json parse:@" true"].success, @"Something went wrong");
    XCTAssertTrue([json parse:@"false  "].success, @"Something went wrong");
    
    //test string matching
    FXParserResult *result = [json parse:@" \"foo\"   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, @"foo", @"Something went wrong");
    
    //test escaped string matching
    result = [json parse:@" \"foo, \\\"bar\\\"\"   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, @"foo, \"bar\"", @"Something went wrong");
    
    //test array
    result = [json parse:@"[1  ,2 ,  \n3]"];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@[@1,@2,@3]), @"Something went wrong");
    
    //test empty array
    result = [json parse:@"[] "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@[]), @"Something went wrong");
    
    //test array of empty arrays
    result = [json parse:@"[[],[]]"];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@[@[],@[]]), @"Something went wrong");
    
    //test dictionary
    result = [json parse:@"{ \n\"foo\"  :\n1, \"bar\" :2}   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@{@"foo":@1, @"bar":@2}), @"Something went wrong");
    
    //test empty dictionary
    result = [json parse:@"{ }"];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@{}), @"Something went wrong");
    
    //test failure
    XCTAssertFalse([json parse:@"foo"].success, @"Something went wrong");
    XCTAssertFalse([json parse:@"bar"].success, @"Something went wrong");
    XCTAssertFalse([json parse:@"barfoo"].success, @"Something went wrong");
}

- (void)testGrammar
{
    //create parser
    FXParser *grammarParser = [FXParser grammarParserWithTransformer:^FXParser *(NSString *name, FXParser *parser) {
        
        if ([name isEqualToString:@"array"])
        {
            return [parser asArray];
        }
        else if ([name isEqualToString:@"object"])
        {
            return [parser asDictionary];
        }
        else if ([name isEqualToString:@"number"])
        {
            return [parser withValueForKeyPath:@"doubleValue"];
        }
        else if ([name isEqualToString:@"boolean"])
        {
            return [parser withValueForKeyPath:@"boolValue"];
        }
        else if ([name isEqualToString:@"string"])
        {
            return [[parser asString] withTransformer:^id(NSString *value) {
                
                value = [value stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
                value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
                value = [value stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
                value = [value stringByReplacingOccurrencesOfString:@"\\b" withString:@"\b"];
                value = [value stringByReplacingOccurrencesOfString:@"\\f" withString:@"\f"];
                value = [value stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
                value = [value stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
                value = [value stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
                return value; //TODO: unicode literals
            }];
        }
        return parser;
    }];
    
    //parse JSON grammar
    NSString *grammarFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"JSONGrammar" ofType:@"txt"];
    NSString *grammarString = [NSString stringWithContentsOfFile:grammarFile encoding:NSUTF8StringEncoding error:NULL];
    FXParserResult *grammarResult = [grammarParser parse:grammarString];
    XCTAssertTrue(grammarResult.success, @"Something went wrong");
    FXParser *json = grammarResult.value[@"json"];
    
    //test primitive matching
    XCTAssertTrue([json parse:@" 5"].success, @"Something went wrong: %@", [json parse:@" 5"]);
    XCTAssertTrue([json parse:@"10.5 "].success, @"Something went wrong");
    XCTAssertTrue([json parse:@"null\n "].success, @"Something went wrong");
    XCTAssertTrue([json parse:@" true"].success, @"Something went wrong");
    XCTAssertTrue([json parse:@"false  "].success, @"Something went wrong");
    
    //test string matching
    FXParserResult *result = [json parse:@" \"foo\"   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, @"foo", @"Something went wrong");
    
    //test escaped string matching
    result = [json parse:@" \"foo, \\\"bar\\\"\"   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, @"foo, \"bar\"", @"Something went wrong");
    
    //test array
    result = [json parse:@"[1  ,2, \n3]"];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@[@1,@2,@3]), @"Something went wrong");
    
    //test empty array
    result = [json parse:@"[] "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@[]), @"Something went wrong");
    
    //test array of empty arrays
    result = [json parse:@"[[],[]]"];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@[@[],@[]]), @"Something went wrong");
    
    //test dictionary
    result = [json parse:@"{ \n\"foo\"  :\n1, \"bar\" :2}   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@{@"foo":@1, @"bar":@2}), @"Something went wrong");
    
    //test empty dictionary
    result = [json parse:@"{ }"];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, (@{}), @"Something went wrong");
    
    //test failure
    XCTAssertFalse([json parse:@"foo"].success, @"Something went wrong");
    XCTAssertFalse([json parse:@"bar"].success, @"Something went wrong");
    XCTAssertFalse([json parse:@"barfoo"].success, @"Something went wrong");
}

@end
