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
    XCTAssertTrue([json parse:@" 5"].success, @"Something went wrong");
    XCTAssertTrue([json parse:  @"10.5 "].success, @"Something went wrong");
    XCTAssertTrue([json parse:@"null\n "].success, @"Something went wrong");
    XCTAssertTrue([json parse:@" true"].success, @"Something went wrong");
    XCTAssertTrue([json parse:@"false  "].success, @"Something went wrong");
    
    //test string matching
    FXParserResult *result = [json parse:@" \"foo\"   "];
    XCTAssertTrue(result.success, @"Something went wrong");
    XCTAssertEqualObjects(result.value, @"foo", @"Something went wrong");
    
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

@end
