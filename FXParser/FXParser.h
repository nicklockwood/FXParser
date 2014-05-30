//
//  FXParser.h
//
//  Version 1.0.1
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
typedef id (^FXParserValueTransform)(id value);


@interface FXParserResult : NSObject

+ (instancetype)successWithValue:(id)value remaining:(NSRange)remaining;
+ (instancetype)successWithChildren:(NSArray *)children remaining:(NSRange)remaining;
+ (instancetype)failureWithChildren:(NSArray *)children expected:(NSString *)description remaining:(NSRange)remaining;

@property (nonatomic, readonly) BOOL success;
@property (nonatomic, readonly) id value;
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

- (instancetype)parserWithDescription:(NSString *)description;

+ (instancetype)forwardDeclaration;
- (void)setImplementation:(FXParser *)implementation;

- (FXParserResult *)parse:(NSString *)input range:(NSRange)range;
- (FXParserResult *)parse:(NSString *)input;

@end


@interface FXParser (Combinators)

+ (instancetype)sequence:(NSArray *)parsers;
+ (instancetype)oneOf:(NSArray *)parsers;

- (instancetype)optional;
- (instancetype)oneOrMore;
- (instancetype)separatedBy:(FXParser *)parser;
- (instancetype)surroundedBy:(FXParser *)parser;

- (instancetype)or:(FXParser *)parser;
- (instancetype)then:(FXParser *)parser;

@end


@interface FXParser (ValueTransformers)

- (instancetype)withTransform:(FXParserValueTransform)transform;
- (instancetype)withValueForKeyPath:(NSString *)keyPath;
- (instancetype)withValue:(id)value;
- (instancetype)discard;

- (instancetype)array; //if value is not an array, converts it into an array of one or zero objects
- (instancetype)dictionary; //converts an array of interleaved key/value pairs into a dictionary
- (instancetype)join:(NSString *)glue; //joins an array of values

@end


#pragma GCC diagnostic pop

