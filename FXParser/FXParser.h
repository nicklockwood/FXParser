//
//  FXParser.h
//
//  Version 1.2.1
//
//  Created by Nick Lockwood on 15/01/2013.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXParser
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import <Foundation/Foundation.h>


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"


@class  FXParserResult;


extern NSString *const FXParserException;


typedef FXParserResult *(^FXParserBlock)(NSString *input, NSRange range);
typedef NSRange (^FXParserStringPredicate)(NSString *input, NSRange range);
typedef id (^FXParserValueTransformer)(id value);


@interface FXParserResult : NSObject

+ (instancetype)successWithValue:(id)value matched:(NSRange)matched remaining:(NSRange)remaining;
+ (instancetype)successWithValueBlock:(id (^)(void))valueBlock matched:(NSRange)matched remaining:(NSRange)remaining;
+ (instancetype)successWithChildren:(NSArray *)children matched:(NSRange)matched remaining:(NSRange)remaining;
+ (instancetype)failureWithChildren:(NSArray *)children matched:(NSRange)matched remaining:(NSRange)remaining expected:(NSString *)description;

@property (nonatomic, readonly) BOOL success;
@property (nonatomic, readonly) id value;
@property (nonatomic, readonly) NSRange matched;
@property (nonatomic, readonly) NSRange remaining;
@property (nonatomic, readonly) NSArray *children;
@property (nonatomic, readonly) NSString *expected;

@end




@interface FXParser : NSObject

+ (instancetype)parserWithBlock:(FXParserBlock)block description:(NSString *)description;
+ (instancetype)stringMatchingPredicate:(FXParserStringPredicate)predicate description:(NSString *)description;
+ (instancetype)regexp:(NSString *)pattern replacement:(NSString *)replacement;
+ (instancetype)regexp:(NSString *)pattern;
+ (instancetype)string:(NSString *)string;

- (instancetype)withDescription:(NSString *)description;
- (instancetype)withName:(NSString *)name;

+ (instancetype)forwardDeclarationWithName:(NSString *)name;
- (void)setImplementation:(FXParser *)implementation;

- (FXParserResult *)parse:(NSString *)input range:(NSRange)range;
- (FXParserResult *)parse:(NSString *)input;

@property (nonatomic, readonly) NSString *name;

@end


@interface FXParser (Combinators)

+ (instancetype)sequence:(NSArray *)parsers;
+ (instancetype)oneOf:(NSArray *)parsers;

- (instancetype)optional;
- (instancetype)zeroOrMoreTimes;
- (instancetype)oneOrMoreTimes;
- (instancetype)twoOrMoreTimes;
- (instancetype)separatedBy:(FXParser *)parser;
- (instancetype)surroundedBy:(FXParser *)parser;

- (instancetype)or:(FXParser *)parser;
- (instancetype)then:(FXParser *)parser;

@end


@interface FXParser (ValueTransformers)

- (instancetype)withTransformer:(FXParserValueTransformer)transformer;
- (instancetype)withComponentsJoinedByString:(NSString *)glue;
- (instancetype)withValueForKeyPath:(NSString *)keyPath;
- (instancetype)withValue:(id)value;
- (instancetype)discard;

- (instancetype)asArray; //if value is not an array, converts it into an array of one or zero objects
- (instancetype)asDictionary; //converts an array of interleaved key/value pairs into a dictionary
- (instancetype)asString; //joins an array of values to make a string, or returns description of any other value

@end


@interface FXParser (Grammar)

+ (instancetype)grammarParserWithTransformer:(FXParser *(^)(NSString *name, FXParser *parser))transformer;

@end


#pragma GCC diagnostic pop

